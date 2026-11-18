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

/// GoRouter configuration with a BottomNavigationBar shell.
///
/// Routes mirror the mobile app feature flow from CAPSTONE_REQUIREMENTS.md.
///
/// Note: SignupPage, InterestOnboardingPage, PoiDetailPage, DirectionsPage,
/// EventDetailPage, and InquiryPage are defined inside their combined feature
/// files (login_page.dart, explore_page.dart, events_page.dart,
/// coordinators_page.dart) to keep the scaffold compact.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  // Re-evaluate the redirect whenever onboarding completes or is replayed.
  refreshListenable: onboardingController,
  redirect: (context, state) {
    // `main.dart` awaits the persisted flag before the app starts; this guard
    // only matters if the controller is somehow used before that finishes.
    if (onboardingController.isLoading) return null;
    final location = state.matchedLocation;
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
      builder: (context, state, child) => _BottomNavShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/explore',
          name: 'explore',
          builder: (context, state) => const ExplorePage(),
        ),
        GoRoute(
          path: '/events',
          name: 'events',
          builder: (context, state) => const EventsPage(),
        ),
        GoRoute(
          path: '/saved',
          name: 'saved',
          builder: (context, state) => const SavedPage(),
        ),
        GoRoute(
          path: '/coordinators',
          name: 'coordinators',
          builder: (context, state) => const CoordinatorsPage(),
        ),
        GoRoute(
          path: '/assistant',
          name: 'assistant',
          builder: (context, state) => const AssistantPage(),
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfilePage(),
        ),
      ],
    ),
    // Auth routes (outside shell) — all defined in login_page.dart
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/auth-callback',
      name: 'auth_callback',
      builder: (context, state) => const OAuthCallbackPage(),
    ),
    GoRoute(
      path: '/submit/:type',
      name: 'submit_content',
      builder: (context, state) =>
          SubmitContentPage(type: state.pathParameters['type'] ?? 'event'),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingFlow(),
    ),
    GoRoute(
      path: '/onboarding/interests',
      name: 'interest_onboarding',
      builder: (context, state) => const InterestOnboardingPage(),
    ),
    // Detail / action routes — defined in combined feature files
    GoRoute(
      path: '/poi/:id',
      name: 'poi_detail',
      builder: (context, state) =>
          PoiDetailPage(poiId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/directions',
      name: 'directions',
      builder: (context, state) => const DirectionsPage(),
    ),
    GoRoute(
      path: '/event/:id',
      name: 'event_detail',
      builder: (context, state) => EventDetailPage(
        eventId: state.pathParameters['id']!,
        // Optional Hero tag handed over by a card so the photo can fly
        // between the list and this page.
        heroTag: state.uri.queryParameters['hero'],
      ),
    ),
    GoRoute(
      path: '/inquiry/:municipalityId',
      name: 'inquiry',
      builder: (context, state) =>
          InquiryPage(municipalityId: state.pathParameters['municipalityId']!),
    ),
    GoRoute(
      path: '/geofence-simulator',
      name: 'geofence_simulator',
      builder: (context, state) => const GeofenceSimulatorPage(),
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

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    _selectedIndex = _routes.indexWhere(
      (r) => location == r || location.startsWith('$r/'),
    );
    if (_selectedIndex == -1) _selectedIndex = 0;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: List.generate(
          _routes.length,
          (i) => BottomNavigationBarItem(
            icon: Icon(_icons[i]),
            activeIcon: Icon(_activeIcons[i], color: const Color(0xFF033300)),
            label: _labels[i],
          ),
        ),
      ),
    );
  }
}
