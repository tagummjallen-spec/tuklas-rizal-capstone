import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';

/// User profile — saved trips, LGU submissions, interests and developer tools.
///
/// When no user is signed in (Guest state), shows prominent "Sign In" and
/// "Create Account" buttons. Saved Places & Events still work for guests
/// because bookmarks are persisted on the device.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final user = auth.currentUser;
    final saved = ref.watch(savedPlacesProvider);
    final dateFormat = DateFormat('MMM d, yyyy');

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
                  const Text(
                    'Sign in to save interests, bookmark events, '
                    'and message Tourism Coordinators.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),

          // Saved Places & Events ------------------------------------------------
          Row(
            children: [
              const Icon(Icons.bookmark, color: Color(0xFF033300), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Saved Places & Events',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF033300),
                  ),
                ),
              ),
              Text(
                '${saved.totalCount}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B6B6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (saved.totalCount == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No saves yet. Tap the bookmark on any event or place to build your trip.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
              ),
            )
          else ...[
            if (saved.savedEvents.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.event, color: Color(0xFF033300)),
                title: Text('Saved Events (${saved.savedEvents.length})'),
                children: saved.savedEvents.map((event) {
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 16),
                    title: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(dateFormat.format(event.startDate)),
                    trailing: IconButton(
                      icon: const Icon(Icons.bookmark_remove,
                          color: Color(0xFF033300), size: 20),
                      tooltip: 'Remove bookmark',
                      onPressed: () =>
                          ref.read(savedPlacesProvider).toggleEvent(event),
                    ),
                    onTap: () => context.push('/event/${event.id}'),
                  );
                }).toList(),
              ),
            if (saved.savedPois.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.place, color: Color(0xFF033300)),
                title: Text('Saved Places (${saved.savedPois.length})'),
                children: saved.savedPois.map((poi) {
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 16),
                    title: Text(
                      poi.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(poi.poiType ?? 'Place'),
                    trailing: IconButton(
                      icon: const Icon(Icons.bookmark_remove,
                          color: Color(0xFF033300), size: 20),
                      tooltip: 'Remove bookmark',
                      onPressed: () =>
                          ref.read(savedPlacesProvider).togglePoi(poi),
                    ),
                    onTap: () => context.push('/poi/${poi.id}'),
                  );
                }).toList(),
              ),
          ],

          if (user != null) ...[
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
              'Submit to the Tourism Office',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF033300),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate,
                  color: Color(0xFF033300)),
              title: const Text('Submit an Event'),
              subtitle: const Text(
                'Send a photo and details for Tourism Coordinator approval',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/submit/event'),
            ),
            ListTile(
              leading: const Icon(Icons.add_location_alt,
                  color: Color(0xFF033300)),
              title: const Text('Submit a Place or Local Food'),
              subtitle: const Text(
                'Share a heritage site, destination or Rizal delicacy',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/submit/poi'),
            ),
          ],

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
