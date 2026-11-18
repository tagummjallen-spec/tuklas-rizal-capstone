import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/widgets/event_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/event_item.dart';

/// Events & Calendar — event listing, RSVP/participation, bookmarks.
///
/// Browsing is open to guests; RSVP and bookmarking require a session.
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
                        onTap: () => context.push('/event/${e.id}'),
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

/// Event detail page with RSVP/participation, bookmarks, "How to Get There"
/// route guide, and Tourism Coordinator contact/inquiry button.
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
        final matches = events.where((e) => e.id == eventId).toList();
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Event')),
            body: const Center(child: Text('Event not found.')),
          );
        }
        final event = matches.first;
        return Scaffold(
          appBar: AppBar(
            title: Text(event.title),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                tooltip: 'Bookmark event',
                onPressed: () =>
                    _saveRsvp(context, ref, event, 'interested', 'Bookmarked'),
              ),
            ],
          ),
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
                    child: const Icon(
                      Icons.event,
                      color: Color(0xFF033300),
                      size: 48,
                    ),
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
                  const Icon(Icons.location_city,
                      size: 16, color: Color(0xFF6B6B6B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.venueName ?? event.municipalityId,
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

              // RSVP / participation — requires a signed-in account.
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

              // How to Get There
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
