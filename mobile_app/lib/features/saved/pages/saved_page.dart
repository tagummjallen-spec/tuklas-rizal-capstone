import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/tourism_images.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../models/event_item.dart';
import '../../../models/poi_logistics.dart';
import '../../../services/lookup_service.dart';

/// Saved — the user's bookmarked events and places.
///
/// Bookmarks are persisted by [SavedPlacesController] (SharedPreferences), so
/// guests keep their saves. Removing a bookmark here immediately updates Home,
/// Explore, Events and Profile because they all watch the same controller.
class SavedPage extends ConsumerStatefulWidget {
  const SavedPage({super.key});

  @override
  ConsumerState<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends ConsumerState<SavedPage> {
  static const Color forest = Color(0xFF033300);
  static const Color gold = Color(0xFFFFC800);

  int _tab = 0;
  final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedPlacesProvider);
    final labels = ref.watch(lookupsProvider).valueOrNull ?? LookupTables.empty;
    final events = saved.savedEvents;
    final pois = saved.savedPois;

    final list = _tab == 0 ? events : pois;
    final isEmpty = list.isEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ---- Green header -------------------------------------------------
          Container(
            color: forest,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bookmark,
                        color: forest,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saved',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${events.length} event'
                            '${events.length == 1 ? '' : 's'} · '
                            '${pois.length} place'
                            '${pois.length == 1 ? '' : 's'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---- Events / Places switch --------------------------------------
          Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: _SavedTab(
                    label: 'Events',
                    count: events.length,
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SavedTab(
                    label: 'Places',
                    count: pois.length,
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              child: isEmpty
                  ? _EmptySaved(
                      key: ValueKey('empty-$_tab'),
                      isPlaces: _tab == 1,
                      onBrowse: () =>
                          context.go(_tab == 0 ? '/events' : '/explore'),
                    )
                  : ListView.builder(
                      key: ValueKey('list-$_tab'),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        if (_tab == 0) {
                          final event = events[i];
                          return StaggeredFadeIn(
                            key: ValueKey('saved-event-${event.id}'),
                            index: i,
                            child: _SavedEventCard(
                              event: event,
                              municipality: labels.municipality(
                                event.municipalityId,
                              ),
                              category: labels.category(event.categoryId),
                              date: _dateFormat.format(event.startDate),
                              onOpen: () => context.push('/event/${event.id}'),
                              onRemove: () => _removeEvent(event),
                            ),
                          );
                        }
                        final poi = pois[i];
                        return StaggeredFadeIn(
                          key: ValueKey('saved-poi-${poi.id}'),
                          index: i,
                          child: _SavedPoiCard(
                            poi: poi,
                            municipality: labels.municipality(
                              poi.municipalityId,
                            ),
                            category:
                                poi.poiType ?? labels.category(poi.categoryId),
                            onOpen: () => context.push('/poi/${poi.id}'),
                            onRemove: () => _removePoi(poi),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeEvent(EventItem event) async {
    await ref.read(savedPlacesProvider).toggleEvent(event);
    // Keep the signed-in participation row in sync with the bookmark.
    final user = ref.read(verifiedAuthUserProvider);
    if (user != null) {
      try {
        await ref.read(discoveryServiceProvider).removeRsvp(event.id, user.id);
      } catch (_) {
        // Local bookmark removal already succeeded.
      }
    }
    if (!mounted) return;
    _toast('Removed from saved');
  }

  Future<void> _removePoi(PoiLogistics poi) async {
    await ref.read(savedPlacesProvider).togglePoi(poi);
    if (!mounted) return;
    _toast('Removed from saved');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: forest,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class _SavedTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SavedTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? scheme.primary : _SavedPageState.forest;
    final selectedFg = isDark ? const Color(0xFF06210F) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? selectedBg
              : (isDark ? const Color(0xFF24352C) : const Color(0xFFF3F3EF)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? selectedFg : scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedCount(
              value: count,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected
                    ? _SavedPageState.gold
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedEventCard extends StatelessWidget {
  final EventItem event;
  final String municipality;
  final String category;
  final String date;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _SavedEventCard({
    required this.event,
    required this.municipality,
    required this.category,
    required this.date,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: scheme.outline.withValues(alpha: 0.45))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: TourismImage(
                  imageUrl: event.imageUrl,
                  category: category,
                  municipality: municipality,
                  height: 74,
                  width: 74,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _SavedMeta(
                      icon: Icons.location_on_outlined,
                      text: '$municipality · Rizal',
                    ),
                    const SizedBox(height: 2),
                    _SavedMeta(icon: Icons.event_outlined, text: date),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove bookmark',
                onPressed: onRemove,
                icon: Icon(Icons.bookmark_remove, color: scheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedPoiCard extends StatelessWidget {
  final PoiLogistics poi;
  final String municipality;
  final String category;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _SavedPoiCard({
    required this.poi,
    required this.municipality,
    required this.category,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: scheme.outline.withValues(alpha: 0.45))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: TourismImage(
                  imageUrl: poi.imageUrl,
                  category: category,
                  municipality: municipality,
                  height: 74,
                  width: 74,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poi.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _SavedMeta(
                      icon: Icons.location_city_outlined,
                      text: municipality,
                    ),
                    const SizedBox(height: 2),
                    _SavedMeta(
                      icon: Icons.local_offer_outlined,
                      text: category,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove bookmark',
                onPressed: onRemove,
                icon: Icon(Icons.bookmark_remove, color: scheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SavedMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 12, color: muted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
        ),
      ],
    );
  }
}

class _EmptySaved extends StatelessWidget {
  final bool isPlaces;
  final VoidCallback onBrowse;

  const _EmptySaved({
    super.key,
    required this.isPlaces,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF24352C)
                    : const Color(0xFFE7F0E4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaces ? Icons.bookmark_border : Icons.event_note_outlined,
                size: 38,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPlaces ? 'No saved places yet' : 'No saved events yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isPlaces
                  ? 'Tap the bookmark on any destination or restaurant in '
                        'Explore to keep it here for your next Rizal trip.'
                  : 'Tap the bookmark on any event to build your Rizal '
                        'itinerary. Saved events stay on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Explore Rizal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? scheme.primary : _SavedPageState.forest,
                foregroundColor: isDark
                    ? const Color(0xFF06210F)
                    : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
