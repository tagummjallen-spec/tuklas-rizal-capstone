import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';

/// User profile — saved interests, bookmarked events, and Geofence Simulator debug panel.
///
/// When no user is signed in (Guest state), shows prominent "Sign In" and
/// "Create Account" buttons instead of "Sign Out".
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
                if (user != null) ...[
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.roleTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                  if (user.municipalityId != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Municipality: ${user.municipalityId}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                  ],
                ] else ...[
                  const Text(
                    'Guest',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to save interests, bookmark events, '
                    'and message Tourism Coordinators.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          if (user != null) ...[
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
          ],
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
            onTap: () => context.push('/geofence-simulator'),
          ),
          const Divider(),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFF033300)),
              title: const Text('Sign Out'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.login, color: Color(0xFF033300)),
              title: const Text('Sign In'),
              subtitle: const Text('Access your TuklasRizal account'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/login'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person_add, color: Color(0xFF033300)),
              title: const Text('Create Account'),
              subtitle: const Text('Join TuklasRizal as a Resident or Tourist'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/signup'),
            ),
          ],
        ],
      ),
    );
  }
}
