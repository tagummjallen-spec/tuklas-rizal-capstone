import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/promotion_reason.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/event_card.dart';
import '../../../models/event_item.dart';
import '../../../services/lookup_service.dart';

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

  final dateFormat = DateFormat('MMM d, yyyy');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.read(discoveryServiceProvider);
    final labels = ref.watch(lookupsProvider).valueOrNull ?? LookupTables.empty;
    final saved = ref.watch(savedPlacesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.eventsCalendar,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF033300),
        foregroundColor: Colors.white,
        elevation: 0,
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
      body: Column(
        children: [
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<List<EventItem>>(
              stream: discovery.promoteTownsAndEvents,
              builder: (context, snap) {
                final all = snap.data ?? [];
                final events = _filter(all, labels);
                if (events.isEmpty) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _EventListSkeleton();
                  }
                  return const Center(
                    child: Text(
                      'No events match your search.',
                      style: TextStyle(color: Color(0xFF6B6B6B)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (_, i) {
                    final e = events[i];
                    return StaggeredFadeIn(
                      key: ValueKey('event-${e.id}'),
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SizedBox(
                          height: 236,
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
                            heroTag: 'event-image-${e.id}',
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/submit/event'),
        icon: const Icon(Icons.add),
        label: const Text('Add Event'),
        backgroundColor: const Color(0xFF033300),
      ),
    );
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
    final user = ref.read(authServiceProvider).currentUser;
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
      physics: const NeverScrollableScrollPhysics(),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF033300),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : const Color(0xFF6B6B6B),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(
          color: selected ? const Color(0xFF033300) : const Color(0xFFE5E5E5),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
