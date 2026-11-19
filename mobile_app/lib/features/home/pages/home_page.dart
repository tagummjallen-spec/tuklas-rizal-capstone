import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/interest_matcher.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/event_card.dart';
import '../../../core/widgets/hero_carousel.dart';
import '../../../core/widgets/municipality_chip.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/event_item.dart';
import '../../../services/lookup_service.dart';
import '../../notifications/notification_state.dart';

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
    final settings = ref.watch(appSettingsProvider);
    final onboarding = ref.watch(onboardingControllerProvider);

    // Guest interests (welcome flow) or the signed-in user's live
    // `public.user_interests` rows feed the "Recommended for You" boost while
    // Rizal Events Hub Recommendations stay enabled in Settings.
    final recommended = settings.recommendationsEnabled
        ? resolveRecommendations(
            ref.watch(recommendedInterestCategoriesProvider).valueOrNull ??
                onboarding.interests,
            labels,
          )
        : RecommendationInterests.empty;
    bool isRecommendedEvent(EventItem event) => recommended.matches(
          event.categoryId,
          labels.category(event.categoryId),
        );

    final barangays = _selectedMunicipalityId != null
        ? RizalBarangays.forMunicipality(_selectedMunicipalityId!)
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rizal Event Hub — Province of Rizal',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF033300),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const _NotificationBell(),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert, color: Colors.white),
            // Tab routes already live inside the shell; `go` switches tab
            // instead of pushing a second shell page (which would duplicate
            // the shell navigator page key). Root-level pages are pushed.
            onSelected: (value) => _openFromMenu(context, value),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: '/assistant',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.chat_bubble_outline,
                    color: Color(0xFF033300),
                  ),
                  title: Text('AI Assistant'),
                ),
              ),
              PopupMenuItem(
                value: '/coordinators',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.business, color: Color(0xFF033300)),
                  title: Text('Tourism Coordinators'),
                ),
              ),
              PopupMenuItem(
                value: '/settings',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF033300),
                  ),
                  title: Text('App Settings'),
                ),
              ),
            ],
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
              const HeroCarousel(),
              const SizedBox(height: 18),
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
                            final alreadySelected =
                                _selectedMunicipalityId == m.id;
                            _selectedMunicipalityId = alreadySelected
                                ? null
                                : m.id;
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
                        onSelected: () => setState(
                          () => _selectedCategoryId = selected ? null : c.id,
                        ),
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
                    final events = _applyFilters(snap.data ?? []);
                    final promoted = discovery.scorePromoteTownsAndEvents(
                      events: events,
                      userInterestCategoryIds: _selectedCategoryId != null
                          ? [_selectedCategoryId!]
                          : recommended.categoryIds,
                      municipalityVisitCounts: {},
                    );
                    if (promoted.isEmpty) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const EventRailSkeleton();
                      }
                      return _EmptyRail(
                        label: _hasFilters
                            ? 'No promoted events match these filters.'
                            : 'No promoted events yet.',
                        onClear: _hasFilters ? _clearFilters : null,
                      );
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: promoted.length,
                      itemBuilder: (_, i) {
                        final e = promoted[i];
                        return StaggeredFadeIn(
                          key: ValueKey('promoted-${e.id}'),
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 216,
                              child: EventCard(
                                title: e.title,
                                municipality: labels.municipality(
                                  e.municipalityId,
                                ),
                                date: dateFormat.format(e.startDate),
                                category: labels.category(e.categoryId),
                                categoryKey: labels.category(e.categoryId),
                                municipalityKey: labels.municipality(
                                  e.municipalityId,
                                ),
                                imageUrl: e.imageUrl,
                                heroTag: 'home-promoted-${e.id}',
                                isPromoted: e.promotedRank > 0,
                                isFeatured: e.isFeatured,
                                isRecommended: isRecommendedEvent(e),
                                isSaved: saved.isEventSaved(e.id),
                                onToggleSave: () => _toggleSavedEvent(e),
                                onTap: () => context.push(
                                  '/event/${e.id}?hero=home-promoted-${e.id}',
                                ),
                              ),
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
                onSeeAll: () => context.go('/events'),
              ),
              SizedBox(
                height: 244,
                child: StreamBuilder<List<EventItem>>(
                  stream: discovery.featuredEvents,
                  builder: (context, snap) {
                    final events = _interestFirst(
                      _applyFilters(snap.data ?? []),
                      isRecommendedEvent,
                    );
                    if (events.isEmpty) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const EventRailSkeleton();
                      }
                      return _EmptyRail(
                        label: _hasFilters
                            ? 'No featured events match these filters.'
                            : 'No featured events yet.',
                        onClear: _hasFilters ? _clearFilters : null,
                      );
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: events.length,
                      itemBuilder: (_, i) {
                        final e = events[i];
                        return StaggeredFadeIn(
                          key: ValueKey('featured-${e.id}'),
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 216,
                              child: EventCard(
                                title: e.title,
                                municipality: labels.municipality(
                                  e.municipalityId,
                                ),
                                date: dateFormat.format(e.startDate),
                                category: labels.category(e.categoryId),
                                categoryKey: labels.category(e.categoryId),
                                municipalityKey: labels.municipality(
                                  e.municipalityId,
                                ),
                                imageUrl: e.imageUrl,
                                heroTag: 'home-featured-${e.id}',
                                isFeatured: true,
                                isRecommended: isRecommendedEvent(e),
                                isSaved: saved.isEventSaved(e.id),
                                onToggleSave: () => _toggleSavedEvent(e),
                                onTap: () => context.push(
                                  '/event/${e.id}?hero=home-featured-${e.id}',
                                ),
                              ),
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

  bool get _hasFilters =>
      _selectedMunicipalityId != null ||
      _selectedBarangayName != null ||
      _selectedCategoryId != null;

  /// Applies the live municipality / barangay / category chips to the event
  /// rails. Barangay matching uses the record's barangay id plus its venue and
  /// directions text, because `events.barangay_id` is a UUID that is not always
  /// populated.
  List<EventItem> _applyFilters(List<EventItem> events) {
    if (!_hasFilters) return events;
    final barangay = _selectedBarangayName?.toLowerCase();
    return events.where((event) {
      if (_selectedMunicipalityId != null &&
          event.municipalityId != _selectedMunicipalityId) {
        return false;
      }
      if (_selectedCategoryId != null &&
          event.categoryId != _selectedCategoryId) {
        return false;
      }
      if (barangay != null) {
        final haystack = [
          event.barangayId ?? '',
          event.venueName ?? '',
          event.howToGetThere ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(barangay)) return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedMunicipalityId = null;
      _selectedBarangayName = null;
      _selectedCategoryId = null;
    });
  }

  /// Interest matches rise to the top while the discover order of the rest is
  /// preserved (the Dart sort is not stable, so no comparator is used).
  List<EventItem> _interestFirst(
    List<EventItem> events,
    bool Function(EventItem) isMatch,
  ) {
    if (events.isEmpty) return events;
    final matches = <EventItem>[];
    final rest = <EventItem>[];
    for (final event in events) {
      (isMatch(event) ? matches : rest).add(event);
    }
    return [...matches, ...rest];
  }

  /// Root-level pages are pushed, shell tabs are switched with `go`.
  void _openFromMenu(BuildContext context, String location) {
    const shellTabs = {'/assistant', '/coordinators'};
    if (shellTabs.contains(location)) {
      context.go(location);
    } else {
      context.push(location);
    }
  }

  Future<void> _toggleSavedEvent(EventItem event) async {
    final saved = await ref.read(savedPlacesProvider).toggleEvent(event);
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null) {
      // Signed-in saves also register interest in event_participation; removing
      // the bookmark clears that row again.
      try {
        final discovery = ref.read(discoveryServiceProvider);
        if (saved) {
          await discovery.rsvpEvent(event.id, 'interested', user.id);
        } else {
          await discovery.removeRsvp(event.id, user.id);
        }
      } catch (_) {
        // Bookmarking must never fail because the RSVP write failed.
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Saved to Saved Places & Events' : 'Removed from saved',
        ),
        backgroundColor: const Color(0xFF033300),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

/// Bell icon with a live unread badge for the Notification Inbox.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(appNotificationsProvider);
    final controller = ref.watch(notificationsControllerProvider);
    final unread = controller.unreadCount(notifications);

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        backgroundColor: const Color(0xFFFFC800),
        textColor: const Color(0xFF033300),
        child: const Icon(
          Icons.notifications_outlined,
          color: Color(0xFFFFC800),
        ),
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
  final VoidCallback? onClear;

  const _EmptyRail({required this.label, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
          ),
          if (onClear != null)
            TextButton(
              onPressed: onClear,
              child: const Text(
                'Clear filters',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF033300),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
