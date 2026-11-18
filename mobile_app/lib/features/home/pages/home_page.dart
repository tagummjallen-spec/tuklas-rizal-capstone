import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/event_card.dart';
import '../../../core/widgets/municipality_chip.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/event_item.dart';
import '../../../services/lookup_service.dart';

/// Home / Discovery Hub — live civic broadcast banner, featured events,
/// "Promote Towns and Events", municipality + barangay + category filters.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _selectedMunicipalityId;
  String? _selectedBarangayName;
  String? _selectedCategoryId;
  final Set<String> _dismissedBroadcasts = {};

  final dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final discovery = ref.read(discoveryServiceProvider);
    final labels = ref.watch(lookupsProvider).valueOrNull ?? LookupTables.empty;
    final saved = ref.watch(savedPlacesProvider);

    final barangays = _selectedMunicipalityId != null
        ? RizalBarangays.forMunicipality(_selectedMunicipalityId!)
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lookupsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CivicBroadcastBanner(
                announcements: discovery.promoteTownsAndEvents,
                dismissedIds: _dismissedBroadcasts,
                onDismiss: (id) => setState(() => _dismissedBroadcasts.add(id)),
              ),
              const Text(
                'Discover Rizal',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF033300),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'All 14 municipalities of the Province of Rizal',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
              ),
              const SizedBox(height: 16),

              // Municipality filter
              const Text(
                'Municipality',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: RizalMunicipalities.all.length,
                  itemBuilder: (_, i) {
                    final m = RizalMunicipalities.all[i];
                    final selected = _selectedMunicipalityId == m.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: MunicipalityChip(
                        municipality: m,
                        isSelected: selected,
                        onSelected: () {
                          setState(() {
                            _selectedMunicipalityId = m.id;
                            _selectedBarangayName = null;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Barangay sub-filter (shown when a municipality is selected)
              if (_selectedMunicipalityId != null) ...[
                const Text(
                  'Barangay',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: barangays.length,
                    itemBuilder: (_, i) {
                      final b = barangays[i];
                      final selected = _selectedBarangayName == b;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(b),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _selectedBarangayName = b);
                          },
                          selectedColor: const Color(0xFFFFC800),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: selected
                                ? const Color(0xFF033300)
                                : const Color(0xFF6B6B6B),
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF033300)
                                : const Color(0xFFE5E5E5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SectionHeader(
                title: 'Category',
                subtitle: 'Filter by tourism interest',
              ),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: TourismCategories.all.length,
                  itemBuilder: (_, i) {
                    final c = TourismCategories.all[i];
                    final selected = _selectedCategoryId == c.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CategoryChip(
                        id: c.id,
                        name: c.name,
                        color: c.color,
                        isSelected: selected,
                        onSelected: () =>
                            setState(() => _selectedCategoryId = c.id),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // "Promote Towns and Events" — Form I: never "Recommendations"
              SectionHeader(
                title: AppConstants.promoteTownsAndEventsTitle,
                subtitle: AppConstants.promoteTownsAndEventsSubtitle,
              ),
              SizedBox(
                height: 244,
                child: StreamBuilder<List<EventItem>>(
                  stream: discovery.promoteTownsAndEvents,
                  builder: (context, snap) {
                    final events = snap.data ?? [];
                    final promoted = discovery.scorePromoteTownsAndEvents(
                      events: events,
                      userInterestCategoryIds:
                          _selectedCategoryId != null
                              ? [_selectedCategoryId!]
                              : [],
                      municipalityVisitCounts: {},
                    );
                    if (promoted.isEmpty) {
                      return const _EmptyRail(label: 'Promoted events loading…');
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: promoted.length,
                      itemBuilder: (_, i) {
                        final e = promoted[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 216,
                            child: EventCard(
                              title: e.title,
                              municipality:
                                  labels.municipality(e.municipalityId),
                              date: dateFormat.format(e.startDate),
                              category: labels.category(e.categoryId),
                              categoryKey: labels.category(e.categoryId),
                              municipalityKey:
                                  labels.municipality(e.municipalityId),
                              imageUrl: e.imageUrl,
                              isPromoted: e.promotedRank > 0,
                              isFeatured: e.isFeatured,
                              isSaved: saved.isEventSaved(e.id),
                              onToggleSave: () => _toggleSavedEvent(e),
                              onTap: () =>
                                  Navigator.of(context).pushNamed('/event/${e.id}'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Featured Events
              SectionHeader(
                title: AppConstants.featuredEvents,
                onSeeAll: () => Navigator.of(context).pushNamed('/events'),
              ),
              SizedBox(
                height: 244,
                child: StreamBuilder<List<EventItem>>(
                  stream: discovery.featuredEvents,
                  builder: (context, snap) {
                    final events = snap.data ?? [];
                    if (events.isEmpty) {
                      return const _EmptyRail(label: 'No featured events yet.');
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: events.length,
                      itemBuilder: (_, i) {
                        final e = events[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 216,
                            child: EventCard(
                              title: e.title,
                              municipality:
                                  labels.municipality(e.municipalityId),
                              date: dateFormat.format(e.startDate),
                              category: labels.category(e.categoryId),
                              categoryKey: labels.category(e.categoryId),
                              municipalityKey:
                                  labels.municipality(e.municipalityId),
                              imageUrl: e.imageUrl,
                              isFeatured: true,
                              isSaved: saved.isEventSaved(e.id),
                              onToggleSave: () => _toggleSavedEvent(e),
                              onTap: () => Navigator.of(context)
                                  .pushNamed('/event/${e.id}'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSavedEvent(EventItem event) async {
    final saved = await ref.read(savedPlacesProvider).toggleEvent(event);
    final user = ref.read(authServiceProvider).currentUser;
    if (saved && user != null) {
      // Signed-in saves also register interest in event_participation.
      try {
        await ref
            .read(discoveryServiceProvider)
            .rsvpEvent(event.id, 'interested', user.id);
      } catch (_) {
        // Bookmarking must never fail because the RSVP write failed.
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved ? 'Saved to Saved Places & Events' : 'Removed from saved'),
        backgroundColor: const Color(0xFF033300),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

/// Provincial tourism banner fed by the web admin's Civic Broadcast action.
///
/// Broadcasts are approved, featured civic events whose title starts with
/// "Civic Broadcast:" and whose 24-hour window includes now. Dismissal is local.
class _CivicBroadcastBanner extends StatelessWidget {
  final Stream<List<EventItem>> announcements;
  final Set<String> dismissedIds;
  final ValueChanged<String> onDismiss;

  const _CivicBroadcastBanner({
    required this.announcements,
    required this.dismissedIds,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventItem>>(
      stream: announcements,
      builder: (context, snap) {
        final now = DateTime.now();
        final live = (snap.data ?? []).where((event) {
          final isBroadcast = event.title.startsWith('Civic Broadcast:');
          final inWindow =
              !now.isBefore(event.startDate) && !now.isAfter(event.endDate);
          return isBroadcast && inWindow && !dismissedIds.contains(event.id);
        }).toList();

        if (live.isEmpty) return const SizedBox.shrink();
        final broadcast = live.first;
        final headline = broadcast.title
            .replaceFirst('Civic Broadcast:', '')
            .trim();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4CC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFC800)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.campaign, color: Color(0xFF033300), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Provincial Tourism Advisory',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: Color(0xFF7A5A00),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        headline.isEmpty ? 'Civic broadcast' : headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF033300),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        broadcast.description ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: Color(0xFF4A3B00),
                        ),
                      ),
                      if (broadcast.venueName != null &&
                          broadcast.venueName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            broadcast.venueName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF7A5A00),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss advisory',
                  onPressed: () => onDismiss(broadcast.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyRail extends StatelessWidget {
  final String label;
  const _EmptyRail({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
      ),
    );
  }
}
