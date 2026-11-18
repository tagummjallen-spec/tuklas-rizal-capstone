import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/maps_launcher.dart';
import '../../../core/utils/tourism_images.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../models/event_item.dart';
import '../../../services/lookup_service.dart';
import '../../notifications/notification_state.dart';
import '../event_detail_state.dart';

/// Event detail screen: hero banner, metadata rows, RSVP bar, bookmark and
/// Google Calendar actions, community reviews and related events.
class EventDetailPage extends ConsumerWidget {
  final String eventId;

  /// Hero tag supplied by the card that opened this page.
  final String? heroTag;

  const EventDetailPage({super.key, required this.eventId, this.heroTag});

  static const Color forest = Color(0xFF033300);
  static const Color cream = Color(0xFFF7F6F2);
  static const Color sage = Color(0xFFDCE8DC);
  static const Color actionGreen = Color(0xFF2E7D32);
  static const Color navy = Color(0xFF1B2C6B);
  static const Color gold = Color(0xFFFFC800);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(lookupsProvider).valueOrNull ?? LookupTables.empty;
    final saved = ref.watch(savedPlacesProvider);
    final feed = ref.watch(allApprovedEventsProvider);
    final events = feed.valueOrNull ?? const <EventItem>[];

    final matches = events.where((e) => e.id == eventId).toList();
    final savedMatches = saved.savedEvents
        .where((e) => e.id == eventId)
        .toList();

    if (matches.isEmpty && savedMatches.isEmpty) {
      return Scaffold(
        backgroundColor: cream,
        appBar: AppBar(title: const Text('Event')),
        body: feed.isLoading
            ? const Center(child: CircularProgressIndicator(color: forest))
            : const Center(child: Text('Event not found.')),
      );
    }
    final event = matches.isNotEmpty ? matches.first : savedMatches.first;
    return Scaffold(
      backgroundColor: cream,
      body: _buildBody(context, ref, event, labels, events),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    EventItem event,
    LookupTables labels,
    List<EventItem> all,
  ) {
    final municipality = labels.municipality(event.municipalityId);
    final venue = (event.venueName?.trim().isNotEmpty ?? false)
        ? event.venueName!.trim()
        : municipality;
    final category = labels.category(event.categoryId);
    final rsvp = ref.watch(eventRsvpProvider);
    final likes = ref.watch(eventLikesProvider);
    final reviews = ref.watch(eventReviewsProvider);
    final isSaved = ref.watch(savedPlacesProvider).isEventSaved(event.id);
    final status = rsvp.statusFor(event.id);
    final office = RizalMunicipalities.byId(event.municipalityId);
    final contact =
        office?.tourismOfficeContact ?? '$municipality Tourism Office';
    final related = all
        .where(
          (e) =>
              e.id != event.id &&
              (e.municipalityId == event.municipalityId ||
                  (e.categoryId != null && e.categoryId == event.categoryId)),
        )
        .take(6)
        .toList();

    final rating = reviews.averageRating(event.id);
    final reviewCount = reviews.reviewCount(event.id);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ---- Hero banner + back button -------------------------------------
        SizedBox(
          height: 270,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: heroTag ?? 'event-image-${event.id}',
                child: TourismImage(
                  imageUrl: event.imageUrl,
                  category: category,
                  municipality: municipality,
                  height: 270,
                  fit: BoxFit.cover,
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Color(0x00000000)],
                    stops: [0.0, 0.55],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back, color: forest),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/events');
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Status pill + title --------------------------------------
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  event.isOngoing ? 'Ongoing' : 'Upcoming',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                event.title.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),

              // ---- Metadata rows ------------------------------------------
              _DetailRow(
                icon: Icons.place_outlined,
                label: 'Location',
                value: '$municipality, Rizal',
                onTap: () => _openDirections(context, event),
              ),
              _DetailRow(
                icon: Icons.calendar_month_outlined,
                label: 'Date & Time',
                value: _dateLine(event),
              ),
              _DetailRow(
                icon: Icons.apartment_outlined,
                label: 'Venue',
                value: venue,
              ),
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Organizer / Contact',
                value: contact,
              ),
              const SizedBox(height: 16),

              // ---- RSVP bar ------------------------------------------------
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sage,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.groups,
                            color: forest,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedCount(
                                value: rsvp.goingCount(event.id),
                                suffix: ' people going',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: forest,
                                ),
                              ),
                              const SizedBox(height: 1),
                              AnimatedCount(
                                value: rsvp.interestedCount(event.id),
                                suffix: ' people interested',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4F6B4D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _RsvpChip(
                            label: "I'm Interested",
                            selected: status == 'interested',
                            onTap: () =>
                                _toggleRsvp(context, ref, event, 'interested'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RsvpChip(
                            label: "I'm Going",
                            selected: status == 'going',
                            onTap: () =>
                                _toggleRsvp(context, ref, event, 'going'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ---- Bookmark + Add to Calendar ------------------------------
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleBookmark(context, ref, event),
                        icon: AnimatedBookmarkIcon(isSaved: isSaved, size: 19),
                        label: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            isSaved ? 'Bookmarked' : 'Bookmark',
                            key: ValueKey<bool>(isSaved),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: forest,
                          side: const BorderSide(color: forest, width: 1.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _addToCalendar(context, event, municipality),
                        icon: const Icon(Icons.calendar_month, size: 19),
                        label: const Text('Add to Calendar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: actionGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---- Rating / hearts / reviews -------------------------------
              Wrap(
                spacing: 14,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _Stars(value: rating, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        '($reviewCount)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _toggleLike(context, ref, event),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            likes.isLiked(event.id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 17,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${likes.hearts(event.id)} Hearts',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openReviews(context, event.id, ref),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 16,
                            color: forest,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$reviewCount Reviews',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),

              // ---- Description ---------------------------------------------
              const Text(
                'EVENT DESCRIPTION',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                  color: forest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _description(event, municipality, venue),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Color(0xFF2A2A2A),
                ),
              ),
              const SizedBox(height: 20),

              // ---- Community reviews (inline) ------------------------------
              _ReviewsSection(
                eventId: event.id,
                onOpenAll: () => _openReviews(context, event.id, ref),
                onWriteReview: () => _startReview(context, ref, event.id),
              ),
              const Divider(height: 28),

              // ---- How to get there ----------------------------------------
              const Text(
                'HOW TO GET THERE',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                  color: forest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (event.howToGetThere?.trim().isNotEmpty ?? false)
                    ? event.howToGetThere!.trim()
                    : 'Ride a jeepney or UV Express bound for $municipality '
                          'from Shaw Blvd or Cubao, then take a tricycle to $venue.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF2A2A2A),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.directions, size: 19),
                  label: Text('Directions to $venue'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: forest,
                    side: const BorderSide(color: Color(0xFFCFE0CB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _openDirections(context, event),
                ),
              ),
              const SizedBox(height: 20),

              // ---- Tourism coordinator -------------------------------------
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3E8E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.support_agent, color: forest, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tourism Coordinator',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            contact,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B6B6B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          _openInquiry(context, ref, event, contact),
                      child: const Text('Inquire'),
                    ),
                  ],
                ),
              ),

              // ---- Related events ------------------------------------------
              if (related.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Text(
                  'You may also be interested in',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        if (related.isNotEmpty)
          SizedBox(
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: related.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _RelatedCard(
                event: related[i],
                municipality: labels.municipality(related[i].municipalityId),
                onTap: () => context.push('/event/${related[i].id}'),
              ),
            ),
          ),
        const SizedBox(height: 28),
      ],
    );
  }

  String _dateLine(EventItem event) {
    final start = DateFormat('MMM d, yyyy · h:mm a').format(event.startDate);
    final sameDay =
        event.startDate.year == event.endDate.year &&
        event.startDate.month == event.endDate.month &&
        event.startDate.day == event.endDate.day;
    final end = sameDay
        ? DateFormat('h:mm a').format(event.endDate)
        : DateFormat('MMM d, yyyy · h:mm a').format(event.endDate);
    return '$start – $end';
  }

  String _description(EventItem event, String municipality, String venue) {
    final provided = event.description?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    return 'Join the community of $municipality for ${event.title}. '
        'This event is hosted at $venue and celebrates the culture, arts and '
        'local life of the Province of Rizal.';
  }

  Future<void> _toggleRsvp(
    BuildContext context,
    WidgetRef ref,
    EventItem event,
    String status,
  ) async {
    final active = await ref.read(eventRsvpProvider).toggle(event.id, status);
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null) {
      try {
        if (active) {
          await ref
              .read(discoveryServiceProvider)
              .rsvpEvent(event.id, status, user.id);
        } else {
          // Cleared chip removes the live participation row too.
          await ref
              .read(discoveryServiceProvider)
              .removeRsvp(event.id, user.id);
        }
      } catch (_) {
        // The optimistic local RSVP still counted, so the UI stays correct.
      }
    }
    if (!context.mounted) return;
    _toast(
      context,
      active
          ? status == 'going'
                ? "You're going — we saved your RSVP."
                : "Marked as interested."
          : 'RSVP cleared.',
      action: user == null ? 'Sign in to sync' : null,
      onAction: () => context.push('/login'),
    );
  }

  Future<void> _toggleLike(
    BuildContext context,
    WidgetRef ref,
    EventItem event,
  ) async {
    final likes = ref.read(eventLikesProvider);
    final liked = await likes.toggle(event.id);
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null) {
      // Best-effort Supabase mirror; the local heart is already saved.
      await likes.mirrorToSupabase(event.id, user.id, liked);
    }
    if (!context.mounted) return;
    _toast(
      context,
      liked ? 'Added to your hearts.' : 'Heart removed.',
      action: user == null ? 'Sign in to sync' : null,
      onAction: () => context.push('/login'),
    );
  }

  Future<void> _toggleBookmark(
    BuildContext context,
    WidgetRef ref,
    EventItem event,
  ) async {
    final isSaved = await ref.read(savedPlacesProvider).toggleEvent(event);

    // Signed-in users also mirror the bookmark to `event_participation` so it
    // survives a reinstall. Guests keep the device-local bookmark silently.
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
        // Bookmarking must never fail because the sync write failed.
      }
    }
    if (!context.mounted) return;
    _toast(
      context,
      isSaved ? 'Saved for later' : 'Removed from saved',
      action: isSaved && user == null ? 'Sign in to sync' : null,
      onAction: () => context.push('/login'),
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
      _toast(context, 'Could not open Google Maps on this device.');
    }
  }

  Future<void> _openInquiry(
    BuildContext context,
    WidgetRef ref,
    EventItem event,
    String contact,
  ) async {
    final signedIn = await requireSignIn(
      context,
      ref,
      action: 'message $contact',
    );
    if (!signedIn || !context.mounted) return;
    context.push('/inquiry/${event.municipalityId}');
  }

  Future<void> _addToCalendar(
    BuildContext context,
    EventItem event,
    String municipality,
  ) async {
    final start = event.startDate;
    final end = event.endDate.isAfter(start)
        ? event.endDate
        : start.add(const Duration(hours: 2));
    final venue = event.venueName?.trim();
    final location = [
      if (venue != null && venue.isNotEmpty) venue,
      municipality,
      'Rizal, Philippines',
    ].join(', ');
    final details = [
      (event.description?.trim().isNotEmpty ?? false)
          ? event.description!.trim()
          : 'Join us at ${event.title} in $municipality, Rizal.',
      if (event.howToGetThere?.trim().isNotEmpty ?? false)
        'How to get there: ${event.howToGetThere!.trim()}',
      'Organized by the $municipality Tourism Office.',
    ].join('\n\n');

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': event.title,
      'dates': '${_gcalStamp(start)}/${_gcalStamp(end)}',
      'details': details,
      'location': location,
    });

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Calendar launch rejected');
    } catch (_) {
      if (!context.mounted) return;
      _toast(context, 'Could not open Google Calendar on this device.');
    }
  }

  static String _gcalStamp(DateTime value) =>
      DateFormat("yyyyMMdd'T'HHmmss'Z'").format(value.toUtc());

  void _toast(
    BuildContext context,
    String message, {
    String? action,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: forest,
          duration: Duration(seconds: action == null ? 2 : 4),
          action: action == null
              ? null
              : SnackBarAction(
                  label: action,
                  textColor: gold,
                  onPressed: onAction ?? () {},
                ),
        ),
      );
  }
}

// ---------------------------------------------------------------------------
// Metadata row
// ---------------------------------------------------------------------------
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F0E4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: EventDetailPage.forest, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7A7A7A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFF9A9A9A),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RSVP chip
// ---------------------------------------------------------------------------
class _RsvpChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RsvpChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: 36,
      decoration: BoxDecoration(
        color: selected ? EventDetailPage.actionGreen : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? EventDetailPage.actionGreen
              : const Color(0xFFB9CDB6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : EventDetailPage.forest,
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: selected
                      ? const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stars
// ---------------------------------------------------------------------------
class _Stars extends StatelessWidget {
  final double value;
  final double size;

  const _Stars({required this.value, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final icon = value >= i + 1
            ? Icons.star_rounded
            : value >= i + 0.5
            ? Icons.star_half_rounded
            : Icons.star_border_rounded;
        return Icon(
          icon,
          size: size,
          color: icon == Icons.star_border_rounded
              ? const Color(0xFFC9C9C9)
              : EventDetailPage.gold,
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Community reviews (inline section)
// ---------------------------------------------------------------------------
class _ReviewsSection extends ConsumerWidget {
  final String eventId;
  final VoidCallback onOpenAll;
  final VoidCallback onWriteReview;

  const _ReviewsSection({
    required this.eventId,
    required this.onOpenAll,
    required this.onWriteReview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(eventReviewsProvider);
    final all = reviews.reviewsFor(eventId);
    final preview = all.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Community Reviews',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                ),
              ),
            ),
            TextButton(onPressed: onOpenAll, child: const Text('See all')),
          ],
        ),
        _RatingSummary(
          rating: reviews.averageRating(eventId),
          count: reviews.reviewCount(eventId),
        ),
        const Divider(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onOpenAll,
            icon: const Icon(Icons.chevron_left, size: 16),
            label: const Text('Community Reviews'),
            style: TextButton.styleFrom(
              foregroundColor: EventDetailPage.forest,
              padding: const EdgeInsets.symmetric(horizontal: 2),
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final review in preview) ...[
          _ReviewCard(review: review),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 2),
        _WriteReviewBar(onTap: onWriteReview),
      ],
    );
  }
}

class _RatingSummary extends StatelessWidget {
  final double rating;
  final int count;

  const _RatingSummary({required this.rating, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Stars(value: rating, size: 17),
            const SizedBox(height: 2),
            Text(
              '$count reviews',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF7A7A7A)),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final EventReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFC8C8C8),
            child: Text(
              review.author.isEmpty ? '?' : review.author[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.author.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: EventDetailPage.gold,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${review.rating}/5',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '“${review.text}”',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFF3A3A3A),
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

class _WriteReviewBar extends StatelessWidget {
  final VoidCallback onTap;

  const _WriteReviewBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDADFDA)),
          ),
          child: const Row(
            children: [
              Icon(Icons.edit_note, size: 20, color: Color(0xFF7A7A7A)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Write a review...',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8A8A8A)),
                ),
              ),
              Icon(Icons.send_rounded, size: 18, color: EventDetailPage.forest),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Related event card
// ---------------------------------------------------------------------------
class _RelatedCard extends StatelessWidget {
  final EventItem event;
  final String municipality;
  final VoidCallback onTap;

  const _RelatedCard({
    required this.event,
    required this.municipality,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rating = 4.0 + (seedOf(event.id) % 10) / 10;
    return SizedBox(
      width: 208,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Stack(
                  children: [
                    TourismImage(
                      imageUrl: event.imageUrl,
                      municipality: municipality,
                      height: 108,
                      width: 208,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: EventDetailPage.navy,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          event.isOngoing ? 'Ongoing' : 'Upcoming',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: Color(0xFF7A7A7A),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '$municipality · Rizal',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF7A7A7A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: EventDetailPage.gold,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reviews full view (bottom sheet)
// ---------------------------------------------------------------------------
/// Prompts for a session before opening the review editor.
Future<void> _startReview(
  BuildContext context,
  WidgetRef ref,
  String eventId,
) async {
  final signedIn = await requireSignIn(
    context,
    ref,
    action: 'write a community review',
  );
  if (!signedIn || !context.mounted) return;
  await _openWriteReview(context, eventId);
}

Future<void> _openReviews(BuildContext context, String eventId, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _ReviewsSheet(
        eventId: eventId,
        onWriteReview: () {
          Navigator.of(sheetContext).pop();
          _startReview(context, ref, eventId);
        },
      ),
    ),
  );
}

class _ReviewsSheet extends ConsumerWidget {
  final String eventId;
  final VoidCallback onWriteReview;

  const _ReviewsSheet({required this.eventId, required this.onWriteReview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(eventReviewsProvider);
    final all = reviews.reviewsFor(eventId);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F6F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCFCFCF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Community Reviews'),
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor: EventDetailPage.forest,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _RatingSummary(
                  rating: reviews.averageRating(eventId),
                  count: reviews.reviewCount(eventId),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onWriteReview,
                  child: const Text('Write review'),
                ),
              ],
            ),
          ),
          const Divider(height: 16, indent: 16, endIndent: 16),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              itemCount: all.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ReviewCard(review: all[i]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: _WriteReviewBar(onTap: onWriteReview),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Write review sheet
// ---------------------------------------------------------------------------
Future<void> _openWriteReview(BuildContext context, String eventId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WriteReviewSheet(eventId: eventId),
  );
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  final String eventId;

  const _WriteReviewSheet({required this.eventId});

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  final _controller = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final user = ref.read(authServiceProvider).currentUser;
    await ref
        .read(eventReviewsProvider)
        .addReview(
          eventId: widget.eventId,
          author: user?.fullName ?? 'Guest Explorer',
          rating: _rating,
          text: text,
          userId: user?.id,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Review posted. Thank you!'),
        backgroundColor: EventDetailPage.forest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F6F2),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCFCFCF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Write a review',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: EventDetailPage.forest,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Your rating',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF6B6B6B)),
                ),
                const SizedBox(width: 8),
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(
                      i <= _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: EventDetailPage.gold,
                      size: 26,
                    ),
                  ),
                const Spacer(),
                Text(
                  '$_rating/5',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Share your experience at this event...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDADFDA)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDADFDA)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EventDetailPage.actionGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(_submitting ? 'Posting...' : 'Post review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
