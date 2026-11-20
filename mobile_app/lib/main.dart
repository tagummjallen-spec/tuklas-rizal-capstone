import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/router/app_router.dart';
import 'features/onboarding/onboarding_provider.dart';
import 'features/geofence/geofence_alert_host.dart';
import 'features/settings/location_consent.dart';
import 'services/oauth_deep_link.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safe offline/mock fallback: only initialize Supabase when real credentials
  // are configured. Otherwise the app launches immediately in mock/demo mode.
  if (AppConstants.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      publishableKey: AppConstants.supabaseAnonKey,
      // Explicit PKCE flow: the authorization code is exchanged using the
      // verifier stored on device after the web-origin / mobile deep-link
      // redirect returns from Google.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    // Google sign-in on Android/iOS returns through
    // io.supabase.tuklasrizal://login-callback. Exchange that code for a
    // session before the first frame so the app opens signed in instead of
    // falling back to a browser/Web Admin page.
    await listenForOAuthDeepLinks();
  }

  // Resolve the persisted `has_completed_onboarding` flag before GoRouter
  // evaluates its initial redirect, so first-time launches land directly on
  // the four-step welcome flow instead of briefly showing Home.
  await onboardingController.load();

  // RA 10173 consent is restored before the geofence host mounts, so GPS is
  // never requested implicitly on startup.
  await locationConsentController.load();

  // Resolve the persisted Light/Dark choice before the first frame so the app
  // never flashes the wrong theme on launch. Defaults to Light.
  await themeModeController.load();

  runApp(const ProviderScope(child: TuklasRizalApp()));
}

class TuklasRizalApp extends ConsumerWidget {
  const TuklasRizalApp({super.key});

  /// Users already checked by the onboarding bootstrap this session, so token
  /// refreshes never re-route someone who is mid-navigation.
  static final Set<String> _bootstrappedUsers = {};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Google OAuth (web origin redirect and the mobile deep link) lands with a
    // live session but no explicit callback navigation. Send first-time users
    // to interest onboarding once their profile exists.
    ref.listen(authStateProvider, (previous, next) async {
      final profile = next.valueOrNull;
      // Keep the router's auth guard in sync so an authenticated user is never
      // left sitting on /login or /signup. Post-frame: notifying the router
      // mid-build would schedule a navigation during layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        authRedirectNotifier.update(profile?.id);
      });
      if (profile == null || _bootstrappedUsers.contains(profile.id)) return;
      _bootstrappedUsers.add(profile.id);
      try {
        // A guest who completed the welcome flow has their interests saved
        // locally; sync them to Supabase so recommendations persist across
        // devices after the user signs in or registers.
        final onboard = ref.read(onboardingControllerProvider);
        if (onboard.hasInterests) {
          await ref
              .read(authServiceProvider)
              .setUserInterests(profile.id, onboard.interests);
        }
        final onboarded =
            await ref.read(authServiceProvider).hasSavedInterests(profile.id);
        if (!onboarded) {
          appRouter.go('/onboarding/interests');
        }
      } catch (_) {
        // Never block app start on the interest lookup.
      }
    });

    // An existing session restored at launch never fires a change event, so
    // sync the router's auth guard once after the first frame.
    if (authRedirectNotifier.userId == null &&
        ref.read(authStateProvider).valueOrNull != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        authRedirectNotifier.update(
          ref.read(authStateProvider).valueOrNull?.id,
        );
      });
    }

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(highContrast: settings.highContrast),
      darkTheme: AppTheme.darkTheme(highContrast: settings.highContrast),
      themeMode: themeMode.themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(settings.textScale),
          ),
          child: GeofenceAlertHost(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
