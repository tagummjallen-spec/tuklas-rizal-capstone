import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';

/// Contact Us & LGU Coordinator Inquiry.
///
/// A dedicated root-level page (opened with `context.push('/contact')`) rather
/// than a push of a shell tab, so the tab shell's navigator page key is never
/// reserved twice — the cause of GoRouter's
/// `!keyReservation.contains(key)` assertion.
class ContactUsPage extends ConsumerWidget {
  const ContactUsPage({super.key});

  static const Color _forest = Color(0xFF033300);
  static const Color _forestDeep = Color(0xFF022400);
  static const Color _cream = Color(0xFFF7F6F2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _forest,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Contact Us',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const _ContactHeader(),
          const SizedBox(height: 16),

          // Provincial Tourism Office -------------------------------------
          _SectionCard(
            icon: Icons.account_balance,
            title: 'Provincial Tourism Office',
            subtitle: AppConstants.tourismOfficeName,
            children: [
              const _InfoRow(
                icon: Icons.place_outlined,
                label: 'Office address',
                value: AppConstants.tourismOfficeAddress,
              ),
              const _InfoRow(
                icon: Icons.mail_outline,
                label: 'Email support',
                value: AppConstants.tourismOfficeEmail,
              ),
              const _InfoRow(
                icon: Icons.call_outlined,
                label: 'Phone support',
                value:
                    '${AppConstants.tourismOfficeTrunkline} '
                    '(${AppConstants.tourismOfficeLocal})',
              ),
              const _InfoRow(
                icon: Icons.schedule,
                label: 'Office hours',
                value: AppConstants.tourismOfficeHours,
              ),
              const SizedBox(height: 6),
              _ActionRow(
                children: [
                  _ActionButton(
                    icon: Icons.mail,
                    label: 'Email us',
                    filled: true,
                    onTap: () => _openUri(
                      context,
                      Uri(
                        scheme: 'mailto',
                        path: AppConstants.tourismOfficeEmail,
                        query: 'subject=TuklasRizal%20Inquiry',
                      ),
                      fallback: 'No email app available on this device.',
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.call,
                    label: 'Call office',
                    onTap: () => _openUri(
                      context,
                      Uri(
                        scheme: 'tel',
                        path: AppConstants.tourismOfficeTrunkline.replaceAll(
                          RegExp(r'[^0-9+]'),
                          '',
                        ),
                      ),
                      fallback: 'Calling is not available on this device.',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Municipal coordinators ----------------------------------------
          _SectionCard(
            icon: Icons.business,
            title: 'Municipal Tourism Coordinators',
            subtitle:
                'Ask a town office about schedules, directions or local '
                'delicacies.',
            children: [
              const Text(
                'Every municipality in Rizal has its own Tourism Coordinator. '
                'Browse the directory to see each office and send a direct '
                'inquiry — replies appear in the app.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  // `/coordinators` is a shell tab: switch to it with `go` so
                  // a second shell page is never pushed on top of the current
                  // one.
                  onPressed: () => context.go('/coordinators'),
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: const Text('Open Coordinator Directory'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _forest,
                    side: const BorderSide(color: Color(0xFFCFE0CB)),
                    minimumSize: const Size.fromHeight(46),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // LGU coordinator application -----------------------------------
          _SectionCard(
            icon: Icons.verified_user,
            title: 'Apply as an LGU Coordinator',
            subtitle: 'Level 2–4 municipal and provincial access',
            children: [
              const Text(
                'Tourism Coordinators, municipal IT admins and provincial '
                'super admins manage events and place listings in the TuklasRizal '
                'web admin portal.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 10),
              const _Bullet(
                text: 'Level 2 — Tourism Coordinator (municipal review)',
              ),
              const _Bullet(
                text: 'Level 3 — Mayor / Municipal IT Admin (full municipal)',
              ),
              const _Bullet(
                text: 'Level 4 — Provincial Super Admin (province-wide)',
              ),
              const SizedBox(height: 10),
              const Text(
                'LGU accounts start pending and are approved by the Provincial '
                'Super Admin in the admin portal.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 12),
              _ActionRow(
                children: [
                  _ActionButton(
                    icon: Icons.outgoing_mail,
                    label: 'Request LGU access',
                    filled: true,
                    // Structured request form: full legal name, requested
                    // tier, municipality, office details and document upload.
                    onTap: () => context.push('/lgu-access-request'),
                  ),
                  _ActionButton(
                    icon: Icons.mail_outline,
                    label: 'Email office',
                    onTap: () => _openUri(
                      context,
                      Uri(
                        scheme: 'mailto',
                        path: AppConstants.tourismOfficeEmail,
                        query:
                            'subject=LGU%20Coordinator%20Access%20Request',
                      ),
                      fallback: 'No email app available on this device.',
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.person_add_alt,
                    label: signedIn ? 'Manage account' : 'Create account',
                    // `/profile` is a shell tab: switch tabs with `go`.
                    onTap: () => signedIn
                        ? context.go('/profile')
                        : context.push('/signup'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'TuklasRizal · Rizal Provincial Tourism Office',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF8A8A8A)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUri(
    BuildContext context,
    Uri uri, {
    required String fallback,
  }) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(fallback),
            backgroundColor: _forestDeep,
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }
}

/// Forest-green hero band above the contact cards.
class _ContactHeader extends StatelessWidget {
  const _ContactHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF033300),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFFFC800),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent,
              color: Color(0xFF033300),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We are here to help',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Reach the Provincial Tourism Office for visitor support, '
                  'content corrections and LGU coordinator inquiries.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF033300)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF033300),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF6B6B6B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrapping action row keeps buttons from overflowing on narrow phones.
class _ActionRow extends StatelessWidget {
  final List<Widget> children;
  const _ActionRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
    );

    if (filled) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF033300),
          foregroundColor: Colors.white,
          elevation: 0,
        ).merge(style),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF033300),
        side: const BorderSide(color: Color(0xFFCFE0CB)),
      ).merge(style),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 8),
            child: Icon(
              Icons.circle,
              size: 6,
              color: Color(0xFFFFC800),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1B1B1B)),
            ),
          ),
        ],
      ),
    );
  }
}
