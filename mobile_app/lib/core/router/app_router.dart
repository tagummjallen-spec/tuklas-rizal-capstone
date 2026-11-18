import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/pages/login_page.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/explore/pages/explore_page.dart';
import '../../features/events/pages/events_page.dart';
import '../../features/coordinators/pages/coordinators_page.dart'
    show CoordinatorsPage, InquiryPage;
import '../../features/assistant/pages/assistant_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/profile/pages/geofence_simulator_page.dart';
import '../../features/submissions/pages/submit_content_page.dart';

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
      path: '/onboarding/interests',
      name: 'interest_onboarding',
      builder: (context, state) => const InterestOnboardingPage(),
    ),
    // Detail / action routes — defined in combined feature files
    GoRoute(
      path: '/poi/:id',
      name: 'poi_detail',
      builder: (context, state) => PoiDetailPage(poiId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/directions',
      name: 'directions',
      builder: (context, state) => const DirectionsPage(),
    ),
    GoRoute(
      path: '/event/:id',
      name: 'event_detail',
      builder: (context, state) => EventDetailPage(eventId: state.pathParameters['id']!),
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

  static const List<String> _routes = [
    '/',
    '/explore',
    '/events',
    '/coordinators',
    '/assistant',
    '/profile',
  ];

  static const List<String> _labels = [
    'Home',
    'Explore',
    'Events',
    'Coordinators',
    'Assistant',
    'Profile',
  ];

  static const List<IconData> _icons = [
    Icons.home,
    Icons.explore,
    Icons.event,
    Icons.business,
    Icons.chat,
    Icons.person,
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    _selectedIndex = _routes.indexWhere((r) => location == r || location.startsWith('$r/'));
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
            activeIcon: Icon(_icons[i], color: const Color(0xFF033300)),
            label: _labels[i],
          ),
        ),
      ),
    );
  }
}
