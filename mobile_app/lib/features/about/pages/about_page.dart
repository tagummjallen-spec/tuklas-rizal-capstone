import 'package:flutter/material.dart';

/// About Rizal Events Hub.
///
/// A root-level page opened from Settings so no shell tab is pushed twice.
/// Colours follow the TuklasRizal identity: forest green `#033300` and gold
/// `#FFC800`.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const Color forest = Color(0xFF033300);
  static const Color forestDeep = Color(0xFF022400);
  static const Color gold = Color(0xFFFFC800);
  static const Color cream = Color(0xFFF7F6F2);

  static const List<({IconData icon, String title, String body})> _features = [
    (
      icon: Icons.calendar_month,
      title: '14-municipality event calendar',
      body:
          'Every festival, fiesta, exhibit and community programme across all '
          '14 towns and cities of Rizal, with dates, venues and directions.',
    ),
    (
      icon: Icons.account_balance,
      title: 'Heritage & POI directory',
      body:
          'Churches, art galleries, heritage houses, nature trails, local food '
          'spots and transport logistics, curated with municipal offices.',
    ),
    (
      icon: Icons.auto_awesome,
      title: 'Promote Towns and Events',
      body:
          'Pick the culture, food, nature or sports you love during onboarding '
          'and matching events and places are surfaced first. Lesser-visited '
          'towns are boosted fairly, and every boost shows a clear reason pill.',
    ),
    (
      icon: Icons.event_available,
      title: 'Google Calendar integration',
      body:
          'Save an event straight to your device calendar and RSVP as '
          'Interested or Going so you never miss a town fiesta.',
    ),
    (
      icon: Icons.verified_user,
      title: 'Verified LGU advisories',
      body:
          'Tourism Coordinators and municipal admins publish and update '
          'official schedules, advisories and community notices through the '
          'secure LGU Web Admin portal.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: forest,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'About Rizal Events Hub',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // ---- Hero -------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [forest, forestDeep],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: forest,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Rizal Events Hub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'TuklasRizal · Culture, Arts and Tourism for the Province '
                  'of Rizal',
                  style: TextStyle(
                    color: gold,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The official cultural, festival and tourism hub that '
                  'connects residents and visitors with the towns, heritage '
                  'and livelihoods of all 14 municipalities of Rizal — '
                  'Angono to Tanay, Rodriguez to Jala-Jala.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Mission ----------------------------------------------------
          const _AboutCard(
            icon: Icons.flag_outlined,
            title: 'Our mission',
            body:
                'Make Rizal\'s culture, arts and tourism easy to discover and '
                'easy to trust. TuklasRizal gives every municipality one '
                'shared calendar, an honest heritage directory and a direct '
                'line to the tourism offices that keep the information '
                'accurate.',
          ),
          const SizedBox(height: 14),

          // ---- Features ---------------------------------------------------
          _AboutCard(
            icon: Icons.stars_outlined,
            title: 'Core features',
            body: '',
            children: [
              for (final feature in _features) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0E5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(feature.icon, size: 18, color: forest),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feature.title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B1B1B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              feature.body,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.42,
                                color: Color(0xFF5F5F5F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // ---- Project & governance --------------------------------------
          const _AboutCard(
            icon: Icons.school_outlined,
            title: 'Project & governance',
            body:
                'TuklasRizal · Prototype v1.0 Capstone Project.\n\n'
                'Built in collaboration with the Rizal Provincial Tourism '
                'Office and the municipal tourism offices of the 14 '
                'municipalities. Event and place data is reviewed by the '
                'assigned Tourism Coordinator or Municipal IT Admin before it '
                'is published.',
          ),
          const SizedBox(height: 14),

          // ---- Data privacy & community guidelines ------------------------
          const _AboutCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Data privacy & community guidelines',
            body:
                'We collect only the account details needed to save your '
                'interests, RSVPs and reviews, in line with the Philippine '
                'Data Privacy Act of 2012 (RA 10173). Your email is never '
                'shown publicly.\n\n'
                'Reviews are limited to verified attendees — one review per '
                'event — and may be removed if they contain spam, hate speech '
                'or misinformation. LGU staff accounts are verified against '
                'official IDs and endorsements before they can publish.',
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'TuklasRizal · Rizal Provincial Tourism Office\n'
              'Prototype v1.0 Capstone Project',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Color(0xFF8A8A8A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final List<Widget> children;

  const _AboutCard({
    required this.icon,
    required this.title,
    required this.body,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              Icon(icon, size: 19, color: AboutPage.forest),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AboutPage.forest,
                  ),
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF4A4A4A),
              ),
            ),
          ],
          if (children.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...children,
          ],
        ],
      ),
    );
  }
}
