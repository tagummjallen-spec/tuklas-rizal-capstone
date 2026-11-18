import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/onboarding/onboarding_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safe offline/mock fallback: only initialize Supabase when real credentials
  // are configured. Otherwise the app launches immediately in mock/demo mode.
  if (AppConstants.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      publishableKey: AppConstants.supabaseAnonKey,
    );
  }

  // Resolve the persisted `has_completed_onboarding` flag before GoRouter
  // evaluates its initial redirect, so first-time launches land directly on
  // the four-step welcome flow instead of briefly showing Home.
  await onboardingController.load();

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

    // Google OAuth (web origin redirect and the mobile deep link) lands with a
    // live session but no explicit callback navigation. Send first-time users
    // to interest onboarding once their profile exists.
    ref.listen(authStateProvider, (previous, next) async {
      final profile = next.valueOrNull;
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

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(highContrast: settings.highContrast),
      routerConfig: appRouter,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(settings.textScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
