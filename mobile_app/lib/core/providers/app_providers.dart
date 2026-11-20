import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../services/discovery_service.dart';
import '../../services/geofence_service.dart';
import '../../services/rag_chat_service.dart';
import '../../services/coordinator_service.dart';
import '../../services/storage_service.dart';
import '../../services/saved_places_service.dart';
import '../../services/lookup_service.dart';
import '../../models/user_profile.dart';
import '../../models/coordinator_inquiry.dart';
import '../../models/municipality.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../features/onboarding/onboarding_provider.dart';
import '../../features/settings/settings_provider.dart';

/// Central provider declarations.
///
/// Automatically selects Supabase-backed implementations when
/// `AppConstants.isSupabaseConfigured` is true; otherwise falls back to
/// mock/demo implementations so the app launches immediately without
/// requiring real Supabase credentials.

final authServiceProvider = Provider<AuthService>((ref) {
  if (AppConstants.isSupabaseConfigured) {
    return SupabaseAuthService();
  }
  return MockAuthService();
});

/// One-time onboarding state (SharedPreferences-backed): whether the
/// four-step welcome flow has completed and the guest's selected interests.
final onboardingControllerProvider =
    ChangeNotifierProvider<OnboardingController>((ref) => onboardingController);

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  if (AppConstants.isSupabaseConfigured) {
    return SupabaseDiscoveryService();
  }
  return MockDiscoveryService();
});

/// Live municipalities from `public.municipalities` (falls back to the static
/// 14-town seed when the table is empty). Their `id` values are the same UUIDs
/// stored on events, so filtering Home by municipality stays accurate.
final municipalitiesProvider = StreamProvider<List<Municipality>>((ref) {
  return ref.watch(discoveryServiceProvider).municipalities;
});

/// Live GPS geofencing: coordinates are checked on-device against the 14
/// Rizal municipality centres and registered POIs from Supabase.
final geofenceServiceProvider = Provider<GeofenceService>(
  (ref) => GeolocatorGeofenceService(),
);

/// Live RAG chat: every answer comes from the deployed `rizal-ai-chat`
/// Supabase Edge Function (Groq primary, Gemini fallback).
final ragChatServiceProvider = Provider<RagChatService>(
  (ref) => SupabaseRagChatService(),
);

final coordinatorServiceProvider = Provider<CoordinatorService>((ref) {
  if (AppConstants.isSupabaseConfigured) {
    return SupabaseCoordinatorService();
  }
  return MockCoordinatorService();
});

/// Gallery uploads to the public `tourism-media` Supabase Storage bucket.
final storageServiceProvider = Provider<StorageService>((ref) {
  if (AppConstants.isSupabaseConfigured) {
    return SupabaseStorageService();
  }
  return MockStorageService();
});

/// Accessibility + notification settings, persisted on device.
final appSettingsProvider = ChangeNotifierProvider<AppSettingsController>((
  ref,
) {
  final controller = AppSettingsController();
  controller.load();
  return controller;
});

/// Light / Dark appearance, persisted on device and defaulted to Light.
final themeModeProvider = ChangeNotifierProvider<ThemeModeController>((ref) {
  return themeModeController;
});

/// Auth state stream used by the app-level onboarding bootstrap.
///
/// Defense in depth: even if a session event slips past the service-level
/// check, an unconfirmed email/password session is signed out here and never
/// emitted as a usable profile.
final authStateProvider = StreamProvider<UserProfile?>((ref) {
  final auth = ref.read(authServiceProvider);
  return auth.authStateChanges.asyncMap((profile) async {
    final verification = await auth.signOutUnconfirmedEmailSession();
    if (verification != null) return null;
    return profile;
  });
});

/// The current user only when their session is fully verified.
///
/// Guests, unconfirmed email accounts and accounts whose profile has not
/// loaded map to null, so every write action that watches this provider is
/// blocked until email verification is complete.
final verifiedAuthUserProvider = Provider<UserProfile?>((ref) {
  final auth = ref.read(authServiceProvider);
  if (auth.unverifiedEmailMessage != null) return null;
  return ref.watch(authStateProvider).valueOrNull ?? auth.currentUser;
});

/// Interests that drive the "Recommended for You" boost in Home / Explore.
///
/// Signed-in users read their live `public.user_interests` rows; guests use the
/// interests persisted by the four-step welcome flow. Raw tokens are resolved to
/// live category ids/names by `resolveRecommendations`.
final recommendedInterestCategoriesProvider = FutureProvider<List<String>>((
  ref,
) async {
  final profile = ref.watch(authStateProvider).valueOrNull;
  if (profile != null) {
    try {
      final remote = await ref
          .read(authServiceProvider)
          .loadUserInterestCategories(profile.id);
      if (remote.isNotEmpty) return remote;
    } catch (_) {
      // Fall back to the device's saved interests.
    }
  }
  return ref.watch(onboardingControllerProvider).interests;
});

/// Municipality/category UUID → display name, loaded once per session.
final lookupServiceProvider = Provider<LookupService>((ref) {
  if (AppConstants.isSupabaseConfigured) {
    return SupabaseLookupService();
  }
  return MockLookupService();
});

final lookupsProvider = FutureProvider<LookupTables>((ref) {
  return ref.read(lookupServiceProvider).load();
});

/// Saved Trips / Bookmarks — persisted on device, works for guests.
///
/// Storage is namespaced per account (`saved_events_<userId>` /
/// `saved_events_guest`). A first-time guest starts empty, and signing out
/// resets the guest namespace so the next guest session is clean.
final savedPlacesProvider = ChangeNotifierProvider<SavedPlacesController>((
  ref,
) {
  final controller = SavedPlacesController();
  final initial =
      ref.read(authStateProvider).valueOrNull ??
      ref.read(authServiceProvider).currentUser;
  unawaited(controller.loadForUser(initial?.id));

  ref.listen(authStateProvider, (previous, next) {
    final previousId = previous?.valueOrNull?.id;
    final nextId = next.valueOrNull?.id;
    if (previousId == nextId) return;
    if (nextId == null) {
      unawaited(controller.clearGuestState());
    } else {
      unawaited(controller.loadForUser(nextId));
    }
  });
  return controller;
});

/// Inquiries the signed-in user has sent to Tourism Coordinators.
///
/// Used by the Profile activity stats ("Inquiries Sent") and the coordinator
/// directory. Guests get an empty stream.
final myInquiriesProvider = StreamProvider<List<CoordinatorInquiry>>((ref) {
  final initial =
      ref.watch(authStateProvider).valueOrNull ??
      ref.read(authServiceProvider).currentUser;
  if (initial == null) return Stream.value(const <CoordinatorInquiry>[]);
  return ref.watch(coordinatorServiceProvider).getMyInquiries(initial.id);
});

/// Pull-to-refresh hook shared by Home, Explore, Events and the Coordinator
/// Directory. Re-subscribes to the live Supabase streams and reloads the
/// lookup labels, awaiting the network briefly so the spinner feels honest.
Future<void> refreshTravelData(WidgetRef ref) async {
  ref.invalidate(discoveryServiceProvider);
  ref.invalidate(lookupsProvider);
  try {
    await Future.wait<void>([
      ref.read(lookupsProvider.future),
      ref.read(municipalitiesProvider.future),
    ]).timeout(const Duration(seconds: 8));
  } catch (_) {
    // Keep the existing UI; the streams continue to retry in the background.
  }
}
