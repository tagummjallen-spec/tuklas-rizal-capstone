import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/maps_launcher.dart';
import '../../../core/utils/tourism_images.dart';
import '../../../core/widgets/event_card.dart';
import '../../../core/widgets/section_header.dart';
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
        title: const Text(AppConstants.eventsCalendar),
        centerTitle: true,
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
                for (final entry in _sortedMunicipalities(labels))
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
                      for (final entry in _sortedCategories(labels))
                        DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _categoryId = value),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Promoted'),
                  selected: _promotedOnly,
                  onSelected: (value) =>
                      setState(() => _promotedOnly = value),
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        height: 236,
                        child: EventCard(
                          title: e.title,
                          municipality: labels.municipality(e.municipalityId),
                          date: dateFormat.format(e.startDate),
                          category: labels.category(e.categoryId),
                          categoryKey: labels.category(e.categoryId),
                          municipalityKey:
                              labels.municipality(e.municipalityId),
                          imageUrl: e.imageUrl,
                          isPromoted: e.promotionWeight > 1.0,
                          isFeatured: e.isFeatured,
                          isSaved: saved.isEventSaved(e.id),
                          onToggleSave: () => _toggleSavedEvent(e),
                          onTap: () => context.push('/event/${e.id}'),
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

  List<MapEntry<String, String>> _sortedMunicipalities(LookupTables labels) {
    final entries = labels.municipalityNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  List<MapEntry<String, String>> _sortedCategories(LookupTables labels) {
    final entries = labels.categoryNames.entries.toList()
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
      if (_promotedOnly &&
          !(event.isFeatured || event.promotionWeight > 1.0)) {
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
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return filtered;
  }

  Future<void> _toggleSavedEvent(EventItem event) async {
    final isSaved = await ref.read(savedPlacesProvider).toggleEvent(event);
    final user = ref.read(authServiceProvider).currentUser;
    if (isSaved && user != null) {
      try {
        await ref
            .read(discoveryServiceProvider)
            .rsvpEvent(event.id, 'interested', user.id);
      } catch (_) {
        // Local bookmark still succeeded.
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isSaved ? 'Saved to Saved Places & Events' : 'Removed from saved'),
        backgroundColor: const Color(0xFF033300),
        duration: const Duration(seconds: 1),
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

/// Event detail page with RSVP/participation, bookmarks, "How to Get There"
/// route guide, Google Maps directions, and Tourism Coordinator inquiry.
class EventDetailPage extends ConsumerWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.read(discoveryServiceProvider);
    final dateFormat = DateFormat('MMM d, yyyy');
    final labels = ref.watch(lookupsProvider).valueOrNull ?? LookupTables.empty;
    final saved = ref.watch(savedPlacesProvider);

    return StreamBuilder<List<EventItem>>(
      stream: discovery.promoteTownsAndEvents,
      builder: (context, snap) {
        final events = snap.data ?? [];
        final matches = events.where((e) => e.id == eventId).toList();
        final savedMatches =
            saved.savedEvents.where((e) => e.id == eventId).toList();
        if (matches.isEmpty && savedMatches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Event')),
            body: const Center(child: Text('Event not found.')),
          );
        }
        final event = matches.isNotEmpty ? matches.first : savedMatches.first;
        final isSaved = saved.isEventSaved(event.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                tooltip: isSaved ? 'Remove bookmark' : 'Bookmark event',
                onPressed: () => _toggleBookmark(context, ref, event),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TourismImage(
                imageUrl: event.imageUrl,
                category: labels.category(event.categoryId),
                municipality: labels.municipality(event.municipalityId),
                height: 220,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(height: 16),
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF033300),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_city,
                      size: 16, color: Color(0xFF6B6B6B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.venueName ??
                          labels.municipality(event.municipalityId),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Color(0xFF6B6B6B)),
                  const SizedBox(width: 6),
                  Text(
                    '${dateFormat.format(event.startDate)} – ${dateFormat.format(event.endDate)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (event.description != null) ...[
                Text(
                  event.description!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SectionHeader(
                title: 'RSVP',
                subtitle: 'Going, interested, or save for later',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Going'),
                      onPressed: () =>
                          _saveRsvp(context, ref, event, 'going', 'RSVP saved'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.star_border),
                      label: const Text('Interested'),
                      onPressed: () => _saveRsvp(
                        context,
                        ref,
                        event,
                        'interested',
                        'Marked interested',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const SectionHeader(
                title: 'How to Get There',
                subtitle: 'Step-by-step directions to this event',
              ),
              const SizedBox(height: 12),
              if (event.howToGetThere != null &&
                  event.howToGetThere!.isNotEmpty)
                Text(
                  event.howToGetThere!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text('Get Directions'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF033300),
                    side: const BorderSide(color: Color(0xFF033300)),
                  ),
                  onPressed: () => _openDirections(context, event),
                ),
              ),
              const SizedBox(height: 24),

              const SectionHeader(
                title: 'Tourism Coordinator',
                subtitle:
                    'Contact the municipal Tourism Coordinator — sign in required',
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.business, color: Color(0xFF033300)),
                title: const Text(
                  'Send an inquiry',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Routed to this municipality’s Tourism Office'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _openInquiry(context, ref, event.municipalityId),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.email),
                  label: const Text('Send Inquiry to Tourism Coordinator'),
                  onPressed: () =>
                      _openInquiry(context, ref, event.municipalityId),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDirections(BuildContext context, EventItem event) async {
    final opened = await MapLauncher.openDirections(
      latitude: event.latitude,
      longitude: event.longitude,
      address: event.venueName,
      label: event.title,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps on this device.')),
      );
    }
  }

  Future<void> _toggleBookmark(
    BuildContext context,
    WidgetRef ref,
    EventItem event,
  ) async {
    final isSaved = await ref.read(savedPlacesProvider).toggleEvent(event);
    final user = ref.read(authServiceProvider).currentUser;
    if (isSaved && user != null) {
      try {
        await ref
            .read(discoveryServiceProvider)
            .rsvpEvent(event.id, 'interested', user.id);
      } catch (_) {
        // Local bookmark remains valid.
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isSaved ? 'Saved for later' : 'Removed from saved'),
        backgroundColor: const Color(0xFF033300),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openInquiry(
    BuildContext context,
    WidgetRef ref,
    String municipalityId,
  ) async {
    final signedIn = await requireSignIn(
      context,
      ref,
      action: 'message the Tourism Coordinator',
    );
    if (!signedIn || !context.mounted) return;
    context.push('/inquiry/$municipalityId');
  }

  Future<void> _saveRsvp(
    BuildContext context,
    WidgetRef ref,
    EventItem event,
    String status,
    String successMessage,
  ) async {
    final signedIn = await requireSignIn(
      context,
      ref,
      action: 'RSVP to ${event.title}',
    );
    if (!signedIn) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null || !context.mounted) return;

    try {
      await ref
          .read(discoveryServiceProvider)
          .rsvpEvent(event.id, status, user.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: const Color(0xFF033300),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save your RSVP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
