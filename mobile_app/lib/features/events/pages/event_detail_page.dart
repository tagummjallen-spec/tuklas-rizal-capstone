import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/maps_launcher.dart';
import '../../../core/utils/review_guardrails.dart';
import '../../../core/utils/tourism_images.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/review_status_banner.dart';
import '../../../models/event_item.dart';
import '../../../services/lookup_service.dart';
import '../../notifications/notification_state.dart';
import '../event_detail_state.dart';

/// Event detail screen: hero banner, metadata rows, RSVP bar, bookmark and
/// Google Calendar actions, community reviews and related events.
class EventDetailPage extends ConsumerWidget {
  final String eventId;

  const EventDetailPage({super.key, required this.eventId});

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
              TourismImage(
                imageUrl: event.imageUrl,
                category: category,
                municipality: municipality,
                height: 270,
                fit: BoxFit.cover,
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoBadge(
                    icon: Icons.place_outlined,
                    label: '$municipality, Rizal',
                  ),
                  if (category.trim().isNotEmpty)
                    _InfoBadge(
                      icon: Icons.local_activity_outlined,
                      label: category,
                    ),
                ],
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

              // ---- Engagement card ----------------------------------------
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sage,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.groups,
                            color: forest,
                            size: 22,
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
                              const SizedBox(height: 2),
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _toggleBookmark(context, ref, event),
                              icon: AnimatedBookmarkIcon(
                                isSaved: isSaved,
                                size: 18,
                              ),
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  isSaved ? 'Bookmarked' : 'Bookmark',
                                  key: ValueKey<bool>(isSaved),
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: forest,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                side: BorderSide(
                                  color: isSaved
                                      ? forest
                                      : const Color(0xFFB9CDB6),
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _addToCalendar(context, event, municipality),
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: const Text(
                                'Add to Calendar',
                                style: TextStyle(fontSize: 12.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: actionGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1, color: const Color(0xFFC9DCC6)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _HeartButton(
                          liked: likes.isLiked(event.id),
                          count: likes.hearts(event.id),
                          onTap: () => _toggleLike(context, ref, event),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.star_rounded, size: 18, color: gold),
                        const SizedBox(width: 3),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: forest,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '($reviewCount reviews)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF4F6B4D),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openReviews(context, ref, event),
                          style: TextButton.styleFrom(
                            foregroundColor: forest,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 34),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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
                event: event,
                reviewGate: _reviewGateFor(ref, event),
                onOpenAll: () => _openReviews(context, ref, event),
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
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  (event.howToGetThere?.trim().isNotEmpty ?? false)
                      ? event.howToGetThere!.trim()
                      : 'Ride a jeepney or UV Express bound for $municipality '
                            'from Shaw Blvd or Cubao, then take a tricycle to '
                            '$venue.',
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF2A2A2A),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _openDirections(context, event),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  foregroundColor: forest,
                  side: const BorderSide(color: Color(0xFFCFE0CB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions, size: 20, color: forest),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Directions',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: forest,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Directions to $venue',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.3,
                              color: Color(0xFF6B6B6B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.open_in_new,
                      size: 15,
                      color: Color(0xFF9A9A9A),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _askAiGuide(context, event, municipality),
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: const Text(
                    'Ask AI Guide About This',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: forest,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
    // RSVPs are user-owned rows: guests and unconfirmed email accounts must
    // sign in (and verify) before one can be submitted.
    final signedIn = await requireSignIn(
      context,
      ref,
      action: 'RSVP to this event',
    );
    if (!signedIn || !context.mounted) return;

    final active = await ref.read(eventRsvpProvider).toggle(event.id, status);
    final user = ref.read(verifiedAuthUserProvider);
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
    );
  }

  Future<void> _toggleLike(
    BuildContext context,
    WidgetRef ref,
    EventItem event,
  ) async {
    final likes = ref.read(eventLikesProvider);
    final liked = await likes.toggle(event.id);
    final user = ref.read(verifiedAuthUserProvider);
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

    // Verified users also mirror the bookmark to `event_participation` so it
    // survives a reinstall. Guests and unconfirmed accounts keep the
    // device-local bookmark only — never an RSVP row.
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

  /// Pre-fills the AI Tour Guide with a grounded question about this event.
  void _askAiGuide(
    BuildContext context,
    EventItem event,
    String municipality,
  ) {
    final question =
        'Tell me about ${event.title} in $municipality, Rizal — '
        'the schedule, highlights, and how to get there.';
    context.go('/assistant?q=${Uri.encodeQueryComponent(question)}');
  }

  Future<void> _openInquiry(
    BuildContext context,
    WidgetRef ref,
    EventItem event,
    String contact,
  ) async {    final signedIn = await requireSignIn(
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
// Info badge (municipality / category)
// ---------------------------------------------------------------------------
class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0E4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCFE0CB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: EventDetailPage.forest),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: EventDetailPage.forest,
            ),
          ),
        ],
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
// Heart / like button
// ---------------------------------------------------------------------------
class _HeartButton extends StatefulWidget {
  final bool liked;
  final int count;
  final VoidCallback onTap;

  const _HeartButton({
    required this.liked,
    required this.count,
    required this.onTap,
  });

  @override
  State<_HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<_HeartButton> {
  double _scale = 1;

  void _pop() {
    setState(() => _scale = 1.28);
    Future<void>.delayed(const Duration(milliseconds: 130), () {
      if (mounted) setState(() => _scale = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final liked = widget.liked;
    return Material(
      color: liked ? const Color(0xFFFFEBEE) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          _pop();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: liked
                  ? const Color(0xFFE59A9A)
                  : const Color(0xFFB9CDB6),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _scale,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                child: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: liked
                      ? Colors.redAccent
                      : const Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedCount(
                value: widget.count,
                suffix: widget.count == 1 ? ' Heart' : ' Hearts',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: liked
                      ? Colors.redAccent
                      : const Color(0xFF4F6B4D),
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
  final EventItem event;
  final ReviewGate reviewGate;
  final VoidCallback onOpenAll;

  const _ReviewsSection({
    required this.event,
    required this.reviewGate,
    required this.onOpenAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(eventReviewsProvider);
    final all = reviews.reviewsFor(event.id);
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
          rating: reviews.averageRating(event.id),
          count: reviews.reviewCount(event.id),
        ),
        const SizedBox(height: 12),
        ReviewStatusBanner(
          message: reviewGate.message,
          positive: reviewGate.allowed,
        ),
        // Guests only get the banner above — no review box they cannot use.
        if (reviewGate.allowed) ...[
          const SizedBox(height: 12),
          _InlineReviewComposer(
            event: event,
            isEdit: reviewGate.isEdit,
            existing: reviews.reviewByUser(
              event.id,
              ref.watch(verifiedAuthUserProvider)?.id,
            ),
          ),
        ],
        const SizedBox(height: 14),
        for (final review in preview) ...[
          _ReviewCard(review: review),
          const SizedBox(height: 10),
        ],
        if (all.length > preview.length)
          TextButton(
            onPressed: onOpenAll,
            style: TextButton.styleFrom(
              foregroundColor: EventDetailPage.forest,
              padding: EdgeInsets.zero,
            ),
            child: Text('Read all ${all.length} reviews'),
          ),
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

  static const List<Color> _avatarColors = [
    Color(0xFF2E7D32),
    Color(0xFF1B2C6B),
    Color(0xFF8A5A00),
    Color(0xFF00695C),
    Color(0xFF6A1B4D),
  ];

  Color get _avatarColor {
    if (review.author.isEmpty) return _avatarColors.first;
    final seed = review.author.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return _avatarColors[seed % _avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8E1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _avatarColor,
            child: Text(
              review.author.isEmpty ? '?' : review.author[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6DA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Color(0xFFE0A800),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${review.rating}.0',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8A6A00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  review.text,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
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

/// Inline review composer for signed-in, eligible attendees: a 1–5 star picker
/// sits directly above the text box, so no extra sheet is needed.
class _InlineReviewComposer extends ConsumerStatefulWidget {
  final EventItem event;
  final bool isEdit;
  final EventReview? existing;

  const _InlineReviewComposer({
    required this.event,
    required this.isEdit,
    this.existing,
  });

  @override
  ConsumerState<_InlineReviewComposer> createState() =>
      _InlineReviewComposerState();
}

class _InlineReviewComposerState extends ConsumerState<_InlineReviewComposer> {
  final _controller = TextEditingController();
  int _rating = 5;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _rating = existing.rating.clamp(1, 5);
      _controller.text = existing.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!isValidRating(_rating)) {
      setState(() => _error = 'Choose a rating from 1 to 5 stars.');
      return;
    }
    final validation = validateReviewText(_controller.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    final user = ref.read(verifiedAuthUserProvider);
    if (user == null) {
      setState(() => _error = 'Sign in with a verified email to review.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final posted = await ref
          .read(eventReviewsProvider)
          .addReview(
            eventId: widget.event.id,
            author: user.fullName,
            rating: _rating,
            text: sanitizeReviewText(_controller.text),
            userId: user.id,
          );
      if (!mounted) return;
      if (!posted) {
        setState(() {
          _submitting = false;
          _error = 'Your review could not be saved. Please try again.';
        });
        return;
      }
      _controller.clear();
      setState(() => _submitting = false);
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? 'Review updated. Thank you!'
                : 'Review posted. Thank you!',
          ),
          backgroundColor: EventDetailPage.forest,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Something went wrong while posting. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.isEdit ? 'Update your rating' : 'Rate this event',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: EventDetailPage.forest,
                ),
              ),
              const Spacer(),
              Text(
                '$_rating/5',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B6B6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 38,
                  ),
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: EventDetailPage.gold,
                    size: 28,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 5,
            maxLength: reviewMaxChars,
            textInputAction: TextInputAction.newline,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              hintText: 'Write a review...',
              hintStyle: const TextStyle(fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF7F6F2),
              contentPadding: const EdgeInsets.all(12),
              counterStyle: const TextStyle(fontSize: 10),
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
          if (_error != null) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 15,
                  color: Color(0xFFB3261E),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: Color(0xFFB3261E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: EventDetailPage.actionGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.isEdit ? 'Save changes' : 'Post review',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
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
/// Current user's review eligibility for [event].
ReviewGate _reviewGateFor(WidgetRef ref, EventItem event) {
  final verification = ref.read(authServiceProvider).unverifiedEmailMessage;
  if (verification != null) {
    return ReviewGate(allowed: false, message: verification);
  }
  final user = ref.read(verifiedAuthUserProvider);
  final existing = ref
      .read(eventReviewsProvider)
      .reviewByUser(event.id, user?.id);
  return evaluateReviewGate(
    event: event,
    user: user,
    rsvpStatus: ref.read(eventRsvpProvider).statusFor(event.id),
    hasExistingReview: existing != null,
  );
}

/// Prompts for a session, then opens the review editor when every guardrail
/// (signed in, not the organizer, event started, "I'm Going" RSVP) passes.
Future<void> _startReview(
  BuildContext context,
  WidgetRef ref,
  EventItem event,
) async {
  final verification = ref.read(authServiceProvider).unverifiedEmailMessage;
  if (verification != null) {
    await ref.read(authServiceProvider).signOutUnconfirmedEmailSession();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(verification),
          backgroundColor: EventDetailPage.forest,
          duration: const Duration(seconds: 5),
        ),
      );
    return;
  }
  var user = ref.read(verifiedAuthUserProvider);
  if (user == null) {
    final signedIn = await requireSignIn(
      context,
      ref,
      action: 'write a community review',
    );
    if (!signedIn || !context.mounted) return;
    user = ref.read(verifiedAuthUserProvider);
  }
  if (user == null || !context.mounted) return;

  final existing = ref
      .read(eventReviewsProvider)
      .reviewByUser(event.id, user.id);
  final gate = evaluateReviewGate(
    event: event,
    user: user,
    rsvpStatus: ref.read(eventRsvpProvider).statusFor(event.id),
    hasExistingReview: existing != null,
  );
  if (!gate.allowed) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(gate.message),
          backgroundColor: EventDetailPage.forest,
          duration: const Duration(seconds: 4),
        ),
      );
    return;
  }

  await _openWriteReview(context, event, existingReview: existing);
}

Future<void> _openReviews(
  BuildContext context,
  WidgetRef ref,
  EventItem event,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _ReviewsSheet(
        event: event,
        reviewGate: _reviewGateFor(ref, event),
        onWriteReview: () {
          Navigator.of(sheetContext).pop();
          _startReview(context, ref, event);
        },
      ),
    ),
  );
}

class _ReviewsSheet extends ConsumerWidget {
  final EventItem event;
  final ReviewGate reviewGate;
  final VoidCallback onWriteReview;

  const _ReviewsSheet({
    required this.event,
    required this.reviewGate,
    required this.onWriteReview,
  });

  String get eventId => event.id;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ReviewStatusBanner(
              message: reviewGate.message,
              positive: reviewGate.allowed,
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
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: onWriteReview,
                  icon: const Icon(Icons.edit_note, size: 19),
                  label: const Text('Write a review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EventDetailPage.actionGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                ),
              ),
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
Future<void> _openWriteReview(
  BuildContext context,
  EventItem event, {
  EventReview? existingReview,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _WriteReviewSheet(event: event, existingReview: existingReview),
  );
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  final EventItem event;
  final EventReview? existingReview;

  const _WriteReviewSheet({required this.event, this.existingReview});

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  final _controller = TextEditingController();
  int _rating = 5;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingReview;
    if (existing != null) {
      _rating = existing.rating;
      _controller.text = existing.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ReviewGate get _gate {
    final verification = ref.read(authServiceProvider).unverifiedEmailMessage;
    if (verification != null) {
      return ReviewGate(allowed: false, message: verification);
    }
    final user = ref.read(verifiedAuthUserProvider);
    return evaluateReviewGate(
      event: widget.event,
      user: user,
      rsvpStatus: ref.read(eventRsvpProvider).statusFor(widget.event.id),
      hasExistingReview: widget.existingReview != null,
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final gate = _gate;
    if (!gate.allowed) {
      setState(() => _error = gate.message);
      return;
    }
    if (!isValidRating(_rating)) {
      setState(() => _error = 'Choose a rating from 1 to 5 stars.');
      return;
    }
    final validation = validateReviewText(_controller.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    // Re-check at submit time: a session could have lost verification while
    // the sheet was open.
    final verification = ref.read(authServiceProvider).unverifiedEmailMessage;
    if (verification != null) {
      await ref.read(authServiceProvider).signOutUnconfirmedEmailSession();
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = verification;
        });
      }
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final user = ref.read(verifiedAuthUserProvider);
      if (user == null) {
        throw Exception('Sign in with a verified email to post a review.');
      }
      final posted = await ref
          .read(eventReviewsProvider)
          .addReview(
            eventId: widget.event.id,
            author: user.fullName,
            rating: _rating,
            text: sanitizeReviewText(_controller.text),
            userId: user.id,
          );
      if (!mounted) return;
      if (!posted) {
        setState(() {
          _submitting = false;
          _error = 'Your review could not be saved. Please try again.';
        });
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gate.isEdit
                ? 'Review updated. Thank you!'
                : 'Review posted. Thank you!',
          ),
          backgroundColor: EventDetailPage.forest,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Something went wrong while posting. Please try again.';
      });
    }
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
            Text(
              widget.existingReview != null
                  ? 'Edit Your Review'
                  : 'Write a review',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: EventDetailPage.forest,
              ),
            ),
            const SizedBox(height: 10),
            ReviewStatusBanner(message: _gate.message, positive: _gate.allowed),
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
              maxLength: reviewMaxChars,
              textInputAction: TextInputAction.newline,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText:
                    'Share your experience (10–$reviewMaxChars characters)…',
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
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Color(0xFFB3261E),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFFB3261E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.existingReview != null
                            ? 'Save changes'
                            : 'Post review',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
