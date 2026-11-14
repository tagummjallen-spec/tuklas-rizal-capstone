import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';

/// User profile — saved interests, bookmarked events, and Geofence Simulator debug panel.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFFFFC800),
                  child: Icon(Icons.person, size: 40, color: Color(0xFF033300)),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? 'Guest',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.roleTitle ?? 'Tourism Coordinator',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
                if (user?.municipalityId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Municipality: ${user!.municipalityId}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.favorite, color: Color(0xFF033300)),
            title: Text('Saved Interests (USER_INTERESTS)'),
            subtitle: Text('Tourism categories you selected at onboarding'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.bookmark_border, color: Color(0xFF033300)),
            title: Text('Bookmarked Events'),
            subtitle: Text('Events you saved for later'),
            trailing: Icon(Icons.chevron_right),
          ),
          const Divider(),
          const Text(
            'Developer Tools',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF033300),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.device_unknown, color: Color(0xFFFFC800)),
            title: const Text('Geofence Simulator'),
            subtitle: const Text(
              'Simulate municipal entry alerts (debug toggle)',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/geofence-simulator'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF033300)),
            title: const Text('Sign Out'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login', (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
