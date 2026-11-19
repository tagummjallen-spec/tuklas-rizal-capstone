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
import '../../core/constants/app_constants.dart';
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
    ChangeNotifierProvider<OnboardingController>(
  (ref) => onboardingController,
);

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  if (AppConstants.isSupabaseConfigured) {
    return SupabaseDiscoveryService();
  }
  return MockDiscoveryService();
});

final geofenceServiceProvider = Provider<GeofenceService>((ref) =>
    MockGeofenceService());

final ragChatServiceProvider = Provider<RagChatService>((ref) {
  if (AppConstants.isSupabaseConfigured) {
    // Live retrieval from municipalities / approved events / pois_logistics.
    // Flip `useRemoteLlm` to true once the Llama endpoint is wired up.
    return SupabaseRagChatService(useRemoteLlm: false);
  }
  return MockRagChatService();
});

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
final appSettingsProvider =
    ChangeNotifierProvider<AppSettingsController>((ref) {
  final controller = AppSettingsController();
  controller.load();
  return controller;
});

/// Auth state stream used by the app-level onboarding bootstrap.
final authStateProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Interests that drive the "Recommended for You" boost in Home / Explore.
///
/// Signed-in users read their live `public.user_interests` rows; guests use the
/// interests persisted by the four-step welcome flow. Raw tokens are resolved to
/// live category ids/names by `resolveRecommendations`.
final recommendedInterestCategoriesProvider =
    FutureProvider<List<String>>((ref) async {
  final profile = ref.watch(authStateProvider).valueOrNull;
  if (profile != null) {
    try {
      final remote =
          await ref.read(authServiceProvider).loadUserInterestCategories(
                profile.id,
              );
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
final savedPlacesProvider =
    ChangeNotifierProvider<SavedPlacesController>((ref) {
  final controller = SavedPlacesController();
  controller.load();
  return controller;
});
