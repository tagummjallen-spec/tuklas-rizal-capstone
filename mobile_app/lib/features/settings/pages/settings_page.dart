import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/logout_confirmation.dart';
import '../../../core/widgets/tuklas_page_header.dart';
import '../location_consent.dart';

/// TuklasRizal — App Settings.
///
/// Appearance (Light / Dark), accessibility (text size, high contrast),
/// notifications, location privacy and account actions are all wired and
/// persisted on the device.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  static const Color _forest = Color(0xFF033300);

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const Color _forest = SettingsPage._forest;

  bool _locationBusy = false;
  bool _replayBusy = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final locationConsent = ref.watch(locationConsentProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          TuklasPageHeader(
            title: 'App Settings',
            subtitle:
                'Appearance, accessibility, notifications and app info',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: 'Back',
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'),
            ),
            actions: [
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
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
                          style: _pillStyle(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: scheme.onSurfaceVariant,
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
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/login'),
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text('Sign In / Create Account'),
                          style: _pillStyle(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: scheme.onSurfaceVariant,
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

                // APPEARANCE / ACCESSIBILITY ------------------------------------
                _SettingsCard(
                  title: 'APPEARANCE / ACCESSIBILITY',
                  children: [
                    const Text(
                      'Appearance Theme',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose Light or Dark. Light is the default.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _ThemeSelector(),
                    const Divider(height: 22),
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
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
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
                        color: isDark
                            ? scheme.surfaceContainerHighest.withValues(
                                alpha: 0.45,
                              )
                            : const Color(0xFFF7F6F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'Preview: Explore festivals, heritage sites and local food across Rizal.',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const Divider(height: 22),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: settings.highContrast,
                      activeThumbColor: scheme.primary,
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
                      activeThumbColor: scheme.primary,
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
                      activeThumbColor: scheme.primary,
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
                      activeThumbColor: scheme.primary,
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
                      onChanged: _locationBusy
                          ? null
                          : (enabled) async {
                        if (_locationBusy) return;
                        setState(() => _locationBusy = true);
                        final geofence = ref.read(geofenceServiceProvider);
                        try {
                          if (!enabled) {
                            await locationConsent.setEnabled(false);
                            geofence.stopMonitoring();
                            return;
                          }
                          final agreed =
                              await showLocationPrivacyDialog(context);
                          if (!agreed) return;
                          await locationConsent.acceptNotice();
                          final granted =
                              await geofence.requestLocationPermission();
                          if (!context.mounted) return;
                          if (!granted) {
                            final message =
                                await geofence.availabilityMessage();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  message ??
                                      'Location permission is required for '
                                          'nearby event alerts.',
                                ),
                                backgroundColor: _forest,
                              ),
                            );
                            return;
                          }
                          await locationConsent.setEnabled(true);
                          await geofence.startMonitoring();
                          if (!context.mounted) return;
                          final error = geofence.lastError;
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(error),
                                backgroundColor: _forest,
                              ),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Municipal Cultural Alerts are now on.',
                              ),
                              backgroundColor: _forest,
                            ),
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not update location alerts. Please '
                                'try again.',
                              ),
                              backgroundColor: _forest,
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _locationBusy = false);
                          }
                        }
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
                      activeThumbColor: scheme.primary,
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
                      leading: Icon(Icons.support_agent, color: scheme.primary),
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
                      leading: Icon(Icons.replay, color: scheme.primary),
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
                      trailing: _replayBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: _replayBusy
                          ? null
                          : () async {
                              if (_replayBusy) return;
                              setState(() => _replayBusy = true);
                              try {
                                await ref
                                    .read(onboardingControllerProvider)
                                    .resetOnboarding();
                                if (!context.mounted) return;
                                context.go('/onboarding');
                              } catch (_) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not restart the welcome guide. '
                                      'Please try again.',
                                    ),
                                    backgroundColor: _forest,
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _replayBusy = false);
                                }
                              }
                            },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.info_outline, color: scheme.primary),
                      title: const Text(
                        'About TuklasRizal',
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
                Center(
                  child: Text(
                    'TuklasRizal · Prototype v1.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
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

  static ButtonStyle _pillStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ElevatedButton.styleFrom(
      backgroundColor: isDark ? scheme.primary : _forest,
      foregroundColor: isDark ? const Color(0xFF06210F) : Colors.white,
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: scheme.outline.withValues(alpha: 0.45))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
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
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// Light / Dark segmented selector used by the Appearance card.
///
/// Calls `themeModeProvider`, so tapping an option repaints the whole app
/// immediately and persists the choice for the next launch.
class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = controller.themeMode == ThemeMode.dark;

    Widget option({
      required IconData icon,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      final selectedBg = isDark ? scheme.primary : const Color(0xFF033300);
      final selectedFg = isDark ? const Color(0xFF06210F) : Colors.white;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: '$label theme',
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? selectedFg : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? selectedFg : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24352C) : const Color(0xFFF1F3EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.6 : 0.4),
        ),
      ),
      child: Row(
        children: [
          option(
            icon: Icons.light_mode_outlined,
            label: 'Light',
            selected: !isDark,
            onTap: () => controller.setThemeMode(ThemeMode.light),
          ),
          const SizedBox(width: 4),
          option(
            icon: Icons.dark_mode_outlined,
            label: 'Dark',
            selected: isDark,
            onTap: () => controller.setThemeMode(ThemeMode.dark),
          ),
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
  bool _busy = false;

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
          Text(
            'Pick any of the 14 towns to trigger the cultural welcome banner '
            'indoors.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.5),
                    ),
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
                onPressed: _busy
                    ? null
                    : () async {
                        if (_busy) return;
                        setState(() => _busy = true);
                        try {
                          final didSimulate = await ref
                              .read(geofenceServiceProvider)
                              .simulateEntry(_selectedTownId);
                          if (!context.mounted) return;
                          if (!didSimulate) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not simulate that town. Please pick '
                                  'another.',
                                ),
                                backgroundColor: Color(0xFF033300),
                              ),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Simulated entry to ${selected?.name ?? 'town'}',
                              ),
                              backgroundColor: const Color(0xFF033300),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not simulate town entry. Please try '
                                'again.',
                              ),
                              backgroundColor: Color(0xFF033300),
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Trigger',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
