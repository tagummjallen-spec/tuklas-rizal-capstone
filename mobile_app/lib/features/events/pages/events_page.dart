import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/event_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/event_item.dart';

/// Events & Calendar — event listing, RSVP/participation, bookmarks.
class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.read(discoveryServiceProvider);
    final dateFormat = DateFormat('MMM d, yyyy');

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
                        date: dateFormat.format(e.startDate),
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

/// Event detail page with RSVP/participation, "How to Get There" route guide,
/// and Tourism Coordinator contact/inquiry button.
class EventDetailPage extends ConsumerWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.read(discoveryServiceProvider);
    final dateFormat = DateFormat('MMM d, yyyy');

    return StreamBuilder<List<EventItem>>(
      stream: discovery.promoteTownsAndEvents,
      builder: (context, snap) {
        final events = snap.data ?? [];
        final event = events.firstWhere(
          (e) => e.id == eventId,
          orElse: () => throw Exception('Event not found'),
        );
        return Scaffold(
          appBar: AppBar(title: Text(event.title), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  event.imageUrl ?? 'https://via.placeholder.com/600x400',
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 220,
                    color: const Color(0xFFF7F6F2),
                    child: const Icon(Icons.event, color: Color(0xFF033300), size: 48),
                  ),
                ),
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
                  const Icon(Icons.location_city, size: 16, color: Color(0xFF6B6B6B)),
                  const SizedBox(width: 6),
                  Text(
                    event.municipalityId,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
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
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (event.description != null) ...[
                Text(
                  event.description!,
                  style: const TextStyle(fontSize: 16, color: Color(0xFF1B1B1B)),
                ),
                const SizedBox(height: 16),
              ],
              // How to Get There
              const SectionHeader(
                title: 'How to Get There',
                subtitle: 'Step-by-step directions to this event',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text('Open Directions in Maps'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF033300),
                    side: const BorderSide(color: Color(0xFF033300)),
                  ),
                  onPressed: () {
                    // url_launcher to open Google/Apple Maps
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Tourism Coordinator contact & inquiry
              const SectionHeader(
                title: 'Tourism Coordinator',
                subtitle: "Contact the municipal ${AppConstants.tourismCoordinatorTitle}",
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.business, color: Color(0xFF033300)),
                title: Text(
                  '${event.municipalityId} ${AppConstants.tourismCoordinatorTitle}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(event.contactPerson ?? 'Contact via inquiry'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.of(context)
                    .pushNamed('/inquiry/${event.municipalityId}'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.email),
                  label: const Text('Send Inquiry to Tourism Coordinator'),
                  onPressed: () => Navigator.of(context)
                      .pushNamed('/inquiry/${event.municipalityId}'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}


