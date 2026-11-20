import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/pages/login_page.dart'
    show SignupPage, OAuthCallbackPage, InterestOnboardingPage;
import '../../features/onboarding/onboarding_flow.dart';
import '../../features/onboarding/onboarding_provider.dart';
import '../../features/auth/pages/login_screen.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/explore/pages/explore_page.dart';
import '../../features/events/pages/events_page.dart' show EventsPage;
import '../../features/events/pages/event_detail_page.dart';
import '../../features/saved/pages/saved_page.dart';
import '../../features/notifications/pages/notifications_page.dart';
import '../../features/coordinators/pages/coordinators_page.dart'
    show CoordinatorsPage, InquiryPage;
import '../../features/assistant/pages/assistant_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/profile/pages/geofence_simulator_page.dart';
import '../../features/submissions/pages/submit_content_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/contact/pages/contact_us_page.dart';
import '../../features/contact/pages/lgu_access_request_page.dart';
import '../../features/about/pages/about_page.dart';

/// One shared, minimalist transition for every route: a fast fade with a
/// slight upward slide. No shared-element/Hero flight, so list thumbnails never
/// leave a trailing image behind during navigation.
CustomTransitionPage<T> fadeSlidePage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.03),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

/// Mirrors the signed-in user id so GoRouter can redirect away from the auth
/// screens. `main.dart` updates it whenever `authStateProvider` changes.
class AuthRedirectNotifier extends ChangeNotifier {
  String? _userId;

  String? get userId => _userId;

  void update(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    notifyListeners();
  }
}

final AuthRedirectNotifier authRedirectNotifier = AuthRedirectNotifier();

/// Root navigator, used for the auth and onboarding flows that must cover the
/// whole screen. Authenticated content lives inside the shell route below so
/// the five-tab bar stays visible everywhere.
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// GoRouter configuration with a BottomNavigationBar shell.
///
/// Routes mirror the mobile app feature flow from CAPSTONE_REQUIREMENTS.md.
///
/// Note: SignupPage, InterestOnboardingPage, PoiDetailPage, DirectionsPage,
/// EventDetailPage, and InquiryPage are defined inside their combined feature
/// files (login_page.dart, explore_page.dart, events_page.dart,
/// coordinators_page.dart) to keep the scaffold compact.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  debugLogDiagnostics: false,
  // Re-evaluate the redirect whenever onboarding completes or is replayed, and
  // whenever the auth session appears or disappears.
  refreshListenable: Listenable.merge([
    onboardingController,
    authRedirectNotifier,
  ]),
  redirect: (context, state) {
    // `main.dart` awaits the persisted flag before the app starts; this guard
    // only matters if the controller is somehow used before that finishes.
    if (onboardingController.isLoading) return null;
    final location = state.matchedLocation;
    // Already signed in: never sit on the sign-in / sign-up screens.
    if (authRedirectNotifier.userId != null &&
        (location == '/login' || location == '/signup')) {
      return '/';
    }
    final inOnboarding =
        location == '/onboarding' || location.startsWith('/onboarding/');
    if (!onboardingController.hasCompleted) {
      return inOnboarding ? null : '/onboarding';
    }
    // Finished (or replayed and then completed) — leave the welcome flow.
    if (location == '/onboarding') return '/';
    return null;
  },
  routes: [
    ShellRoute(
      pageBuilder: (context, state, child) => fadeSlidePage(
        context: context,
        state: state,
        child: _BottomNavShell(child: child),
      ),
      // Every child route relies on GoRouter's own `state.pageKey`; no manual
      // LocalKey is ever reused, so each match reserves a distinct page key.
      // Callers must `go` (not `push`) to switch between these shell tabs.
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (context, state) => fadeSlidePage(
            context: context,
            state: state,
            child: const HomePage(),
          ),
        ),
        GoRoute(
          path: '/explore',
          name: 'explore',
          pageBuilder: (context, state) => fadeSlidePage(
            context: context,
            state: state,
            child: const ExplorePage(),
          ),
        ),
        GoRoute(
          path: '/events',
          name: 'events',
          pageBuilder: (context, state) => fadeSlidePage(
            context: context,
            state: state,
            child: const EventsPage(),
          ),
        ),
        GoRoute(
          path: '/saved',
          name: 'saved',
          pageBuilder: (context, state) => fadeSlidePage(
            context: context,
            state: state,
            child: const SavedPage(),
          ),
        ),
        GoRoute(
          path: '/coordinators',
          name: 'coordinators',
          pageBuilder: (context, state) => fadeSlidePage(
            context: context,
            state: state,
            child: const CoordinatorsPage(),
          ),
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          pageBuilder: (context, state) => fadeSlidePage(
            context: context,
            state: state,
            child: const ProfilePage(),
          ),
        ),
        // Secondary screens live inside the shell so the 5-tab bottom bar
        // stays visible while browsing details, settings and notifications.
        GoRoute(
          path: '/poi/:id',
          name: 'poi_detail',
          pageBuilder: (context, state) => fadeSlidePage(
            context: context,
            state: state,
            child: PoiDetailPage(poiId: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/event/:id',
          name: 'event_detail',
          pageBuilder: (context, state) => fadeSlidePage(
            context: context,
            state: state,
            child: EventDetailPage(eventId: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) => fadeSlidePage(
            context: context,
            state: state,
            child: const SettingsPage(),
          ),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          pageBuilder: (context, state) => fadeSlidePage(
            context: context,
            state: state,
            child: const NotificationsPage(),
          ),
        ),
        // AI Tour Guide — inside the shell so the Home / Explore / Events /
        // Saved / Profile tabs stay visible under the conversation.
        GoRoute(
          path: '/assistant',
          name: 'assistant',
          pageBuilder: (context, state) {
            final question = state.uri.queryParameters['q'];
            return fadeSlidePage(
              context: context,
              state: state,
              child: AssistantPage(initialQuestion: question),
            );
          },
        ),
      ],
    ),
    // Auth routes (outside shell) — all defined in login_page.dart
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (context, state) => fadeSlidePage(
        context: context,
        state: state,
        child: const LoginPage(),
      ),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      pageBuilder: (context, state) => fadeSlidePage(
        context: context,
        state: state,
        child: const SignupPage(),
      ),
    ),
    // Contact Us & LGU Coordinator Inquiry. A dedicated root-level page keeps
    // the shell navigator's page key unique, so opening it from Settings can
    // never trip GoRouter's `!keyReservation.contains(key)` assertion.
    GoRoute(
      path: '/contact',
      name: 'contact',
      pageBuilder: (context, state) => fadeSlidePage(
        context: context,
        state: state,
        child: const ContactUsPage(),
      ),
    ),
    // About Rizal Events Hub — also a root-level page (same rule as Contact).
    GoRoute(
      path: '/about',
      name: 'about',
      pageBuilder: (context, state) => fadeSlidePage(
        context: context,
        state: state,
        child: const AboutPage(),
      ),
    ),
    // LGU / Admin access request with verification document upload.
    GoRoute(
      path: '/lgu-access-request',
      name: 'lgu_access_request',
      pageBuilder: (context, state) => fadeSlidePage(
        context: context,
        state: state,
        child: const LguAccessRequestPage(),
      ),
    ),
    GoRoute(
      path: '/auth-callback',
      name: 'auth_callback',
      pageBuilder: (context, state) => fadeSlidePage(
        context: context,
        state: state,
        child: const OAuthCallbackPage(),
      ),
    ),
    GoRoute(
      path: '/submit/:type',
      name: 'submit_content',
      pageBuilder: (context, state) => fadeSlidePage(
        context: context,
        state: state,
        child: SubmitContentPage(type: state.pathParameters['type'] ?? 'event'),
      ),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      pageBuilder: (context, state) => fadeSlidePage(
        context: context,
        state: state,
        child: const OnboardingFlow(),
      ),
    ),
    GoRoute(
      path: '/onboarding/interests',
      name: 'interest_onboarding',
      pageBuilder: (context, state) => fadeSlidePage(
        context: context,
        state: state,
        child: const InterestOnboardingPage(),
      ),
    ),
    // Detail / action routes that still need the full screen (keyboard or
    // focused flow). Detail pages themselves live inside the shell above.
    GoRoute(
      path: '/directions',
      name: 'directions',
      pageBuilder: (context, state) => fadeSlidePage(
        context: context,
        state: state,
        child: const DirectionsPage(),
      ),
    ),
    GoRoute(
      path: '/inquiry/:municipalityId',
      name: 'inquiry',
      pageBuilder: (context, state) => fadeSlidePage(
        context: context,
        state: state,
        child: InquiryPage(
          municipalityId: state.pathParameters['municipalityId']!,
        ),
      ),
    ),
    GoRoute(
      path: '/geofence-simulator',
      name: 'geofence_simulator',
      pageBuilder: (context, state) => fadeSlidePage(
        context: context,
        state: state,
        child: const GeofenceSimulatorPage(),
      ),
    ),
  ],
);

class _BottomNavShell extends StatefulWidget {
  final Widget child;
  const _BottomNavShell({required this.child});

  @override
  State<_BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<_BottomNavShell> {
  int _selectedIndex = 0;

  // Five primary tabs keep labels readable on narrow phones; the Tourism
  // Coordinator directory and the AI Assistant stay reachable from the Home
  // overflow menu, so their routes are unchanged.
  static const List<String> _routes = [
    '/',
    '/explore',
    '/events',
    '/saved',
    '/profile',
  ];

  static const List<String> _labels = [
    'Home',
    'Explore',
    'Events',
    'Saved',
    'Profile',
  ];

  static const List<IconData> _icons = [
    Icons.home_outlined,
    Icons.explore_outlined,
    Icons.event_outlined,
    Icons.bookmark_border,
    Icons.person_outline,
  ];

  static const List<IconData> _activeIcons = [
    Icons.home,
    Icons.explore,
    Icons.event,
    Icons.bookmark,
    Icons.person,
  ];

  /// Detail and secondary routes keep their parent tab highlighted.
  static const Map<String, int> _sectionTabs = {
    '/event/': 2,
    '/poi/': 1,
    '/settings': 4,
    '/notifications': 4,
    '/coordinators': 4,
    '/inquiry/': 4,
  };

  int _indexFor(String location) {
    final direct = _routes.indexWhere(
      (r) => location == r || location.startsWith('$r/'),
    );
    if (direct != -1) return direct;
    for (final entry in _sectionTabs.entries) {
      if (location.startsWith(entry.key)) return entry.value;
    }
    return 0;
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    _selectedIndex = _indexFor(location);

    final navTheme = Theme.of(context).bottomNavigationBarTheme;
    final activeColor =
        navTheme.selectedItemColor ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: List.generate(
          _routes.length,
          (i) => BottomNavigationBarItem(
            icon: Icon(_icons[i]),
            // Let the active icon follow the theme so it stays readable on the
            // dark navigation bar (gold on dark, forest on light).
            activeIcon: Icon(_activeIcons[i], color: activeColor),
            label: _labels[i],
          ),
        ),
      ),
    );
  }
}
