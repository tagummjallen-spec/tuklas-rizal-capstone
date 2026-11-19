import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/logout_confirmation.dart';
import '../location_consent.dart';

/// Rizal Events Hub — App Settings.
///
/// Accessibility (text size, high contrast) is persisted through
/// [AppSettingsController] and applied app-wide in `main.dart`. Notification,
/// recommendation, account and support actions are all wired.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const Color _forest = Color(0xFF033300);
  static const Color _forestDeep = Color(0xFF022400);
  static const Color _gold = Color(0xFFFFC800);
  static const Color _cream = Color(0xFFF7F6F2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final locationConsent = ref.watch(locationConsentProvider);

    return Scaffold(
      backgroundColor: _cream,
      body: Column(
        children: [
          // Green header banner ------------------------------------------------
          Container(
            color: _forest,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: _gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: _forest,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rizal Event Hub',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Province of Rizal · Community Calendar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Notifications',
                      icon: const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                      ),
                      onPressed: () => context.push('/notifications'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Dark green sub-banner ----------------------------------------------
          Container(
            width: double.infinity,
            color: _forestDeep,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: const Row(
              children: [
                Icon(Icons.tune, color: _gold, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Accessibility, notifications, and app info',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ACCOUNT ------------------------------------------------------
                _SettingsCard(
                  title: 'ACCOUNT',
                  children: [
                    if (user != null) ...[
                      Row(
                        children: [
                          _Avatar(url: user.avatarUrl, radius: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  user.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B6B6B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.verified,
                            color: Color(0xFF2E7D32),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => confirmAndSignOut(context, ref),
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Log Out'),
                          style: _pillStyle(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Color(0xFF6B6B6B),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () => context.go('/profile'),
                            child: const Text('Account / Profile'),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'You are browsing as a guest. Sign in to sync your '
                        'interests and saved events.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/login'),
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text('Sign In / Create Account'),
                          style: _pillStyle(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Color(0xFF6B6B6B),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () => context.go('/profile'),
                            child: const Text('Account / Profile'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),

                // ACCESSIBILITY -------------------------------------------------
                _SettingsCard(
                  title: 'ACCESSIBILITY',
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Text Size',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _StepButton(
                          label: 'A-',
                          enabled: settings.canDecreaseText,
                          onTap: settings.decreaseTextScale,
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${settings.textScalePercent}%',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _forest,
                            ),
                          ),
                        ),
                        _StepButton(
                          label: 'A+',
                          enabled: settings.canIncreaseText,
                          onTap: settings.increaseTextScale,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _cream,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Preview: Explore festivals, heritage sites and local food across Rizal.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    const Divider(height: 22),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: settings.highContrast,
                      activeThumbColor: _forest,
                      title: const Text(
                        'High Contrast',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Stronger text and border contrast across the app',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: settings.setHighContrast,
                    ),
                  ],
                ),

                // NOTIFICATIONS -------------------------------------------------
                _SettingsCard(
                  title: 'NOTIFICATIONS',
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: settings.eventReminders,
                      activeThumbColor: _forest,
                      title: const Text(
                        'Event Reminders',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Reminders for events you RSVP to',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: settings.setEventReminders,
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: settings.newEventsInMyArea,
                      activeThumbColor: _forest,
                      title: const Text(
                        'New Events in My Area',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Highlights newly approved events near you',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: settings.setNewEventsInMyArea,
                    ),
                  ],
                ),

                // LOCATION & PRIVACY ------------------------------------------
                _SettingsCard(
                  title: 'LOCATION & PRIVACY',
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: locationConsent.alertsEnabled,
                      activeThumbColor: _forest,
                      title: const Text(
                        'Municipal Cultural Alerts',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'GPS coordinates are checked on-device for town & '
                        'heritage banners · RA 10173',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (enabled) async {
                        final geofence = ref.read(geofenceServiceProvider);
                        if (!enabled) {
                          await locationConsent.setEnabled(false);
                          geofence.stopMonitoring();
                          return;
                        }
                        final agreed = await showLocationPrivacyDialog(context);
                        if (!agreed) return;
                        await locationConsent.acceptNotice();
                        final granted = await geofence.requestLocationPermission();
                        if (!context.mounted) return;
                        if (!granted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Location permission was not granted. Enable '
                                'it in your device settings to receive '
                                'cultural alerts.',
                              ),
                              backgroundColor: _forest,
                            ),
                          );
                          return;
                        }
                        await locationConsent.setEnabled(true);
                        await geofence.startMonitoring();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Municipal Cultural Alerts are now on.',
                            ),
                            backgroundColor: _forest,
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    const _DemoTownEntryPicker(),
                  ],
                ),

                // PROMOTE TOWNS AND EVENTS ------------------------------------
                _SettingsCard(
                  title: 'PROMOTE TOWNS AND EVENTS',
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: settings.recommendationsEnabled,
                      activeThumbColor: _forest,
                      title: const Text(
                        AppConstants.promoteTownsAndEventsTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Prioritize events matching your saved interests on Home',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: settings.setRecommendations,
                    ),
                  ],
                ),

                // ABOUT --------------------------------------------------------
                _SettingsCard(
                  title: 'ABOUT',
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.support_agent, color: _forest),
                      title: const Text(
                        'Contact Us',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Prototype v1.0 Capstone Project',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      // Dedicated root-level Contact page: pushing a shell
                      // tab from this root route would reserve the shell page
                      // key twice and crash the navigator.
                      onTap: () => context.push('/contact'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.replay, color: _forest),
                      title: const Text(
                        'Replay Welcome Guide',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Show the four-step welcome flow again',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await ref
                            .read(onboardingControllerProvider)
                            .resetOnboarding();
                        if (context.mounted) context.go('/onboarding');
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.info_outline, color: _forest),
                      title: const Text(
                        'About Rizal Events Hub',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'TuklasRizal · Culture, Arts and Tourism for the '
                        'Province of Rizal',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/about'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Rizal Events Hub · Prototype v1.0',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8A8A8A)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static ButtonStyle _pillStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _forest,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size.fromHeight(48),
      shape: const StadiumBorder(),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF033300),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final Future<void> Function() onTap;
  const _StepButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 38,
      child: OutlinedButton(
        onPressed: enabled ? () => onTap() : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: const Color(0xFF033300),
          side: const BorderSide(color: Color(0xFFCFE0CB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double radius;
  const _Avatar({required this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url!));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFC800),
      child: Icon(Icons.person, size: radius, color: const Color(0xFF033300)),
    );
  }
}

/// Indoor demo of municipal geofence entry — works without a GPS fix so the
/// welcome banner can be shown reliably during the capstone defense.
class _DemoTownEntryPicker extends ConsumerStatefulWidget {
  const _DemoTownEntryPicker();

  @override
  ConsumerState<_DemoTownEntryPicker> createState() =>
      _DemoTownEntryPickerState();
}

class _DemoTownEntryPickerState extends ConsumerState<_DemoTownEntryPicker> {
  late String _selectedTownId;

  @override
  void initState() {
    super.initState();
    _selectedTownId = RizalMunicipalities.all.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final towns = RizalMunicipalities.all;
    final selected = RizalMunicipalities.byId(_selectedTownId);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demo: Simulate Town Entry',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick any of the 14 towns to trigger the cultural welcome banner '
            'indoors.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F6F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCFE0CB)),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedTownId,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final town in towns)
                        DropdownMenuItem<String>(
                          value: town.id,
                          child: Text(
                            town.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedTownId = value);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC800),
                  foregroundColor: const Color(0xFF033300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  await ref
                      .read(geofenceServiceProvider)
                      .simulateEntry(_selectedTownId);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Simulated entry to ${selected?.name ?? 'town'}',
                      ),
                      backgroundColor: const Color(0xFF033300),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text(
                  'Trigger',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
