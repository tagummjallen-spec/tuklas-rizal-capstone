import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/event_card.dart';
import '../../../models/event_item.dart';

/// Events & Calendar — event listing, RSVP/participation, bookmarks.
class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.read(discoveryServiceProvider);
    final _dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.eventsCalendar),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Upcoming Events',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF033300),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: () {
                    // Device calendar integration via add_2_calendar
                  },
                  tooltip: 'Save to device calendar',
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EventItem>>(
              stream: discovery.promoteTownsAndEvents,
              builder: (context, snap) {
                final events = snap.data ?? [];
                if (events.isEmpty) {
                  return const Center(child: Text('No events found.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: events.length,
                  itemBuilder: (_, i) {
                    final e = events[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: EventCard(
                        title: e.title,
                        municipality: e.municipalityId,
                        date: _dateFormat.format(e.startDate),
                        category: e.categoryId ?? 'General',
                        imageUrl: e.imageUrl ??
                            'https://via.placeholder.com/600x400',
                        isPromoted: e.promotedRank > 0,
                        isFeatured: e.isFeatured,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/event/${e.id}'),
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
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Add Event'),
        backgroundColor: const Color(0xFF033300),
      ),
    );
  }
}

/// Event detail page with RSVP/participation tracking.
class EventDetailPage extends ConsumerWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Details'), centerTitle: true),
      body: const Center(
        child: Text('Event detail view — RSVP, bookmark, and calendar integration.'),
      ),
    );
  }
}
