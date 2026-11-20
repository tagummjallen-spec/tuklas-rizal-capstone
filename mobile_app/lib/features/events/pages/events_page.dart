import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/promotion_reason.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/event_card.dart';
import '../../../core/widgets/tuklas_page_header.dart';
import '../../../models/event_item.dart';
import '../../../services/lookup_service.dart';
import '../../../services/saved_places_service.dart';

/// Which slice of the calendar the Events page is showing.
enum _EventsView { upcoming, thisMonth, calendar }

/// Events & Calendar — instant keyword search combined with Municipality,
/// Category and Promoted filters, plus bookmarks and Maps directions.
class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _municipalityId;
  String? _categoryId;
  bool _promotedOnly = false;
  _EventsView _view = _EventsView.upcoming;

  final dateFormat = DateFormat('MMM d, yyyy');
  final _badgeFormat = DateFormat('MMM d');
  final _monthFormat = DateFormat('MMMM yyyy');
  final _weekdayFormat = DateFormat('EEEE');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryServiceProvider);
    final labels = ref.watch(lookupsProvider).valueOrNull ?? LookupTables.empty;
    final saved = ref.watch(savedPlacesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          TuklasPageHeader(
            title: 'Events & Calendar',
            subtitle: 'Festivals, fiestas and community gatherings',
            actions: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFFFFC800),
                ),
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildViewStrip(scheme),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search events, venues, towns…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              children: [
                _FilterPill(
                  label: 'All 14 towns',
                  selected: _municipalityId == null,
                  onTap: () => setState(() => _municipalityId = null),
                ),
                for (final entry in _sorted(labels.municipalityNames))
                  _FilterPill(
                    label: entry.value,
                    selected: _municipalityId == entry.key,
                    onTap: () => setState(() => _municipalityId = entry.key),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      for (final entry in _sorted(labels.categoryNames))
                        DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Promoted'),
                  selected: _promotedOnly,
                  onSelected: (value) => setState(() => _promotedOnly = value),
                  selectedColor: const Color(0xFFFFC800),
                  checkmarkColor: const Color(0xFF033300),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _promotedOnly
                        ? const Color(0xFF033300)
                        : scheme.onSurface,
                  ),
                  side: BorderSide(
                    color: _promotedOnly
                        ? const Color(0xFFFFC800)
                        : scheme.outline.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => refreshTravelData(ref),
              child: StreamBuilder<List<EventItem>>(
              stream: discovery.promoteTownsAndEvents,
              builder: (context, snap) {
                final all = snap.data ?? const <EventItem>[];
                final filtered = _filter(all, labels);
                final events = _applyView(filtered);
                if (events.isEmpty) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _EventListSkeleton();
                  }
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 72, 24, 96),
                    children: [
                      Column(
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 40,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _view == _EventsView.thisMonth
                                ? 'No events left this month.'
                                : 'No events match your search.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          if (_view == _EventsView.thisMonth)
                            TextButton(
                              onPressed: () => setState(
                                () => _view = _EventsView.upcoming,
                              ),
                              child: Text(
                                'See all upcoming events',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                }
                if (_view == _EventsView.calendar) {
                  return _buildCalendarAgenda(events, labels, saved);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: events.length,
                  itemBuilder: (_, i) {
                    final e = events[i];
                    return StaggeredFadeIn(
                      key: ValueKey('event-${e.id}'),
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SizedBox(
                          height: 244,
                          child: EventCard(
                            title: e.title,
                            municipality: labels.municipality(e.municipalityId),
                            date: dateFormat.format(e.startDate),
                            category: labels.category(e.categoryId),
                            categoryKey: labels.category(e.categoryId),
                            municipalityKey: labels.municipality(
                              e.municipalityId,
                            ),
                            imageUrl: e.imageUrl,
                            dateBadge: _badgeFormat
                                .format(e.startDate)
                                .toUpperCase(),
                            showMunicipalityTag: true,
                            isPromoted: e.promotionWeight > 1.0,
                            isFeatured: e.isFeatured,
                            promotionReason: eventPromotionReason(
                              event: e,
                              isInterestMatch: false,
                              visitCount: 0,
                            ),
                            isSaved: saved.isEventSaved(e.id),
                            onToggleSave: () => _toggleSavedEvent(e),
                            onTap: () => context.push('/event/${e.id}'),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/submit/event'),
        icon: const Icon(Icons.add),
        label: const Text('Add Event'),
        backgroundColor: const Color(0xFFFFC800),
        foregroundColor: const Color(0xFF033300),
      ),
    );
  }

  /// Upcoming / This Month / Calendar View segmented filter strip.
  Widget _buildViewStrip(ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget option({
      required _EventsView view,
      required String label,
      required IconData icon,
    }) {
      final selected = _view == view;
      final selectedBg = isDark ? scheme.primary : const Color(0xFF033300);
      final selectedFg = isDark ? const Color(0xFF06210F) : Colors.white;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _view = view),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: selected ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: selected ? selectedFg : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? selectedFg : scheme.onSurface,
                      ),
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
        color: isDark ? const Color(0xFF1A2420) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          option(
            view: _EventsView.upcoming,
            label: 'Upcoming',
            icon: Icons.event_available,
          ),
          const SizedBox(width: 4),
          option(
            view: _EventsView.thisMonth,
            label: 'This Month',
            icon: Icons.calendar_month,
          ),
          const SizedBox(width: 4),
          option(
            view: _EventsView.calendar,
            label: 'Calendar',
            icon: Icons.grid_view_rounded,
          ),
        ],
      ),
    );
  }

  /// Grouped calendar agenda: a month summary followed by date headers with the
  /// events that fall on each day.
  Widget _buildCalendarAgenda(
    List<EventItem> events,
    LookupTables labels,
    SavedPlacesController saved,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = <DateTime, List<EventItem>>{};
    for (final event in events) {
      final key = DateTime(
        event.startDate.year,
        event.startDate.month,
        event.startDate.day,
      );
      groups.putIfAbsent(key, () => []).add(event);
    }
    final days = groups.keys.toList()..sort();

    final children = <Widget>[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2420) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC800),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_month,
                color: Color(0xFF033300),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _monthFormat.format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${events.length} upcoming '
                    '${events.length == 1 ? 'event' : 'events'} · '
                    '${days.length} ${days.length == 1 ? 'day' : 'days'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];

    for (final day in days) {
      final dayEvents = groups[day]!;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF24352C)
                      : const Color(0xFFE8F0E5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('MMM').format(day).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _weekdayFormat.format(day),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dayEvents.length} '
                      '${dayEvents.length == 1 ? 'event' : 'events'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      for (final e in dayEvents) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 244,
              child: EventCard(
                title: e.title,
                municipality: labels.municipality(e.municipalityId),
                date: dateFormat.format(e.startDate),
                category: labels.category(e.categoryId),
                categoryKey: labels.category(e.categoryId),
                municipalityKey: labels.municipality(e.municipalityId),
                imageUrl: e.imageUrl,
                dateBadge: _badgeFormat.format(e.startDate).toUpperCase(),
                showMunicipalityTag: true,
                isPromoted: e.promotionWeight > 1.0,
                isFeatured: e.isFeatured,
                promotionReason: eventPromotionReason(
                  event: e,
                  isInterestMatch: false,
                  visitCount: 0,
                ),
                isSaved: saved.isEventSaved(e.id),
                onToggleSave: () => _toggleSavedEvent(e),
                onTap: () => context.push('/event/${e.id}'),
              ),
            ),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
      children: children,
    );
  }

  /// Applies the Upcoming / This Month / Calendar scope on top of filters.
  List<EventItem> _applyView(List<EventItem> events) {
    if (_view != _EventsView.thisMonth) return events;
    final now = DateTime.now();
    return events
        .where(
          (e) =>
              e.startDate.year == now.year && e.startDate.month == now.month,
        )
        .toList();
  }


  List<MapEntry<String, String>> _sorted(Map<String, String> source) {
    final entries = source.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  List<EventItem> _filter(List<EventItem> all, LookupTables labels) {
    final q = _query.trim().toLowerCase();
    final filtered = all.where((event) {
      if (_municipalityId != null && event.municipalityId != _municipalityId) {
        return false;
      }
      if (_categoryId != null && event.categoryId != _categoryId) {
        return false;
      }
      if (_promotedOnly && !(event.isFeatured || event.promotionWeight > 1.0)) {
        return false;
      }
      if (q.isNotEmpty) {
        final haystack = [
          event.title,
          event.description ?? '',
          event.venueName ?? '',
          labels.municipality(event.municipalityId),
          labels.category(event.categoryId),
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
    return filtered;
  }

  Future<void> _toggleSavedEvent(EventItem event) async {
    final isSaved = await ref.read(savedPlacesProvider).toggleEvent(event);
    final user = ref.read(verifiedAuthUserProvider);
    if (user != null) {
      try {
        final discovery = ref.read(discoveryServiceProvider);
        if (isSaved) {
          await discovery.rsvpEvent(event.id, 'interested', user.id);
        } else {
          await discovery.removeRsvp(event.id, user.id);
        }
      } catch (_) {
        // Local bookmark still succeeded.
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSaved ? 'Saved to Saved Places & Events' : 'Removed from saved',
        ),
        backgroundColor: const Color(0xFF033300),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class _EventListSkeleton extends StatelessWidget {
  const _EventListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: EventCardSkeleton(),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFFFC800),
        backgroundColor: isDark ? const Color(0xFF1A2420) : Colors.white,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? const Color(0xFF033300) : scheme.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
        side: BorderSide(
          color: selected
              ? const Color(0xFFFFC800)
              : scheme.outline.withValues(alpha: 0.6),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
