import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/interest_matcher.dart';
import '../../../core/utils/maps_launcher.dart';
import '../../../core/utils/promotion_reason.dart';
import '../../../core/utils/tourism_images.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/poi_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/tuklas_main_header.dart';
import '../../../models/poi_logistics.dart';
import '../../../services/lookup_service.dart';

/// Explore — Destinations, Cultural/Heritage Sites, Unique Rizal Foods &
/// Local Restaurants with keyword search, Municipality / Category / Promoted
/// filters and "How to Get There" directions.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _municipalityId;
  String? _barangay;
  String? _categoryId;
  bool _promotedOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryServiceProvider);
    final labels = ref.watch(lookupsProvider).valueOrNull ?? LookupTables.empty;
    final saved = ref.watch(savedPlacesProvider);
    final settings = ref.watch(appSettingsProvider);
    // Signed-in interests come from `public.user_interests`, guests from the
    // welcome flow. Matching POIs are listed first and badged.
    final recommended = settings.recommendationsEnabled
        ? resolveRecommendations(
            ref.watch(recommendedInterestCategoriesProvider).valueOrNull ??
                ref.watch(onboardingControllerProvider).interests,
            labels,
          )
        : RecommendationInterests.empty;

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          TuklasMainHeader(
            onSearch: _searchFocus.requestFocus,
            bottomRow: const TuklasHeaderHeading(
              title: 'Explore Rizal',
              subtitle: 'Destinations, heritage sites and local flavors',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search places, foods, towns…',
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
                _Pill(
                  label: 'All 14 towns',
                  selected: _municipalityId == null,
                  onTap: () => setState(() => _municipalityId = null),
                ),
                for (final entry in _sorted(labels.municipalityNames))
                  _Pill(
                    label: entry.value,
                    selected: _municipalityId == entry.key,
                    onTap: () => setState(() {
                      _municipalityId = entry.key;
                      _barangay = null;
                    }),
                  ),
              ],
            ),
          ),
          // Barangay sub-filter, only relevant once a municipality is chosen.
          if (_municipalityId != null)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                children: [
                  _Pill(
                    label: 'All barangays',
                    selected: _barangay == null,
                    onTap: () => setState(() => _barangay = null),
                  ),
                  for (final b in RizalBarangays.forMunicipality(
                    _municipalityId!,
                  ))
                    _Pill(
                      label: b,
                      selected: _barangay == b,
                      onTap: () => setState(() => _barangay = b),
                    ),
                ],
              ),
            ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              children: [
                _Pill(
                  label: 'All categories',
                  selected: _categoryId == null && !_promotedOnly,
                  onTap: () => setState(() {
                    _categoryId = null;
                    _promotedOnly = false;
                  }),
                ),
                for (final entry in _sorted(labels.categoryNames))
                  _Pill(
                    label: entry.value,
                    selected: _categoryId == entry.key,
                    onTap: () => setState(() => _categoryId = entry.key),
                  ),
                _Pill(
                  label: 'Promoted',
                  selected: _promotedOnly,
                  onTap: () => setState(() => _promotedOnly = !_promotedOnly),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => refreshTravelData(ref),
              child: StreamBuilder<List<PoiLogistics>>(
              stream: discovery.pois,
              builder: (context, snap) {
                final all = snap.data ?? const <PoiLogistics>[];
                final pois = _interestFirst(
                  _filter(all, labels),
                  (poi) => recommended.matches(
                    poi.categoryId,
                    labels.category(poi.categoryId),
                  ),
                );
                if (pois.isEmpty) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _PoiListSkeleton();
                  }
                  final filtered =
                      _municipalityId != null ||
                      _barangay != null ||
                      _categoryId != null ||
                      _promotedOnly ||
                      _query.trim().isNotEmpty;
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
                    children: [
                      Column(
                        children: [
                          Icon(
                            Icons.travel_explore,
                            size: 40,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No places match your search.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          if (filtered)
                            TextButton(
                              onPressed: _clearFilters,
                              child: Text(
                                'Clear filters',
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

                // A single, unmissable highlight at the top of the unfiltered
                // feed: the first promoted POI, otherwise the first result.
                final showFeatured =
                    _query.isEmpty &&
                    _municipalityId == null &&
                    _barangay == null &&
                    _categoryId == null &&
                    !_promotedOnly &&
                    all.isNotEmpty;
                final featured = showFeatured ? _pickFeatured(all) : null;
                final leadingItems = featured == null ? 1 : 2;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemCount: leadingItems + pois.length,
                  itemBuilder: (_, i) {
                    if (featured != null && i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _FeaturedPoiBanner(
                          poi: featured,
                          municipality: labels.municipality(
                            featured.municipalityId,
                          ),
                          category:
                              featured.poiType ??
                              labels.category(featured.categoryId),
                          onTap: () => context.push('/poi/${featured.id}'),
                        ),
                      );
                    }
                    if (i == leadingItems - 1) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(0, 2, 0, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Discover Rizal',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            Text(
                              '${pois.length} place${pois.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final index = i - leadingItems;
                    final p = pois[index];
                    return StaggeredFadeIn(
                      key: ValueKey('poi-${p.id}'),
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: PoiCard(
                          name: p.name,
                          municipality: labels.municipality(p.municipalityId),
                          category:
                              p.poiType ?? labels.category(p.categoryId),
                          categoryKey:
                              p.poiType ?? labels.category(p.categoryId),
                          municipalityKey: labels.municipality(
                            p.municipalityId,
                          ),
                          imageUrl: p.imageUrl,
                          commuteBadge:
                              (p.howToGetThere?.trim().isNotEmpty ?? false)
                              ? 'Commute guide'
                              : null,
                          isRecommended: recommended.matches(
                            p.categoryId,
                            labels.category(p.categoryId),
                          ),
                          promotionReason: poiPromotionReason(
                            poi: p,
                            isInterestMatch: recommended.matches(
                              p.categoryId,
                              labels.category(p.categoryId),
                            ),
                          ),
                          isSaved: saved.isPoiSaved(p.id),
                          onToggleSave: () => _toggleSavedPoi(p),
                          onTap: () => context.push('/poi/${p.id}'),
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
    );
  }

  /// The first promoted POI, falling back to the first available result.
  PoiLogistics _pickFeatured(List<PoiLogistics> all) {
    for (final poi in all) {
      if (poi.isPromoted) return poi;
    }
    return all.first;
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _municipalityId = null;
      _barangay = null;
      _categoryId = null;
      _promotedOnly = false;
    });
  }

  /// Interest matches first, preserving discover order within each group.
  List<PoiLogistics> _interestFirst(
    List<PoiLogistics> pois,
    bool Function(PoiLogistics) isMatch,
  ) {
    if (pois.isEmpty) return pois;
    final matches = <PoiLogistics>[];
    final rest = <PoiLogistics>[];
    for (final poi in pois) {
      (isMatch(poi) ? matches : rest).add(poi);
    }
    return [...matches, ...rest];
  }

  List<MapEntry<String, String>> _sorted(Map<String, String> source) {
    final entries = source.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  List<PoiLogistics> _filter(List<PoiLogistics> all, LookupTables labels) {
    final q = _query.trim().toLowerCase();
    return all.where((poi) {
      if (_municipalityId != null && poi.municipalityId != _municipalityId) {
        return false;
      }
      if (_categoryId != null && poi.categoryId != _categoryId) return false;
      if (_promotedOnly && !poi.isPromoted) return false;
      if (_barangay != null) {
        final needle = _barangay!.toLowerCase();
        final place = [
          poi.barangayId ?? '',
          poi.address ?? '',
          poi.howToGetThere ?? '',
        ].join(' ').toLowerCase();
        if (!place.contains(needle)) return false;
      }
      if (q.isNotEmpty) {
        final haystack = [
          poi.name,
          poi.description ?? '',
          poi.address ?? '',
          poi.poiType ?? '',
          labels.municipality(poi.municipalityId),
          labels.category(poi.categoryId),
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _toggleSavedPoi(PoiLogistics poi) async {
    final isSaved = await ref.read(savedPlacesProvider).togglePoi(poi);
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

class _PoiListSkeleton extends StatelessWidget {
  const _PoiListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: EventCardSkeleton(height: 248),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({
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

/// Large highlight card at the top of Explore: full-bleed Rizal photography,
/// a dark gradient scrim and the promoted destination's key facts.
class _FeaturedPoiBanner extends StatelessWidget {
  final PoiLogistics poi;
  final String municipality;
  final String category;
  final VoidCallback onTap;

  const _FeaturedPoiBanner({
    required this.poi,
    required this.municipality,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 196,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TourismImage(
                imageUrl: poi.imageUrl,
                category: poi.poiType ?? category,
                municipality: municipality,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x14000000),
                      Color(0x66000000),
                      Color(0xE6001200),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC800),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: Color(0xFF033300),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'FEATURED THIS WEEK',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF033300),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poi.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.place,
                          size: 13,
                          color: Color(0xFFFFC800),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            municipality,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'View details',
                          style: TextStyle(
                            color: Color(0xFFFFC800),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: Color(0xFFFFC800),
                        ),
                        const Spacer(),
                        if (poi.howToGetThere?.trim().isNotEmpty ?? false)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.directions_bus,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Commute guide',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: onTap),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// POI detail page with "How to Get There", Maps directions and bookmarks.
class PoiDetailPage extends ConsumerWidget {
  final String poiId;
  const PoiDetailPage({super.key, required this.poiId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(lookupsProvider).valueOrNull ?? LookupTables.empty;
    final saved = ref.watch(savedPlacesProvider);

    return StreamBuilder<List<PoiLogistics>>(
      stream: ref.read(discoveryServiceProvider).pois,
      builder: (context, snap) {
        final pois = snap.data ?? [];
        final matches = pois.where((p) => p.id == poiId).toList();
        final savedMatches = saved.savedPois
            .where((p) => p.id == poiId)
            .toList();
        if (matches.isEmpty && savedMatches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Place')),
            body: const Center(child: Text('Place not found.')),
          );
        }
        final poi = matches.isNotEmpty ? matches.first : savedMatches.first;
        final isSaved = saved.isPoiSaved(poi.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(poi.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            centerTitle: true,
            actions: [
              IconButton(
                icon: AnimatedBookmarkIcon(isSaved: isSaved),
                onPressed: () async {
                  final nowSaved = await ref
                      .read(savedPlacesProvider)
                      .togglePoi(poi);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        nowSaved ? 'Saved for later' : 'Removed from saved',
                      ),
                      backgroundColor: const Color(0xFF033300),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TourismImage(
                imageUrl: poi.imageUrl,
                category: poi.poiType ?? labels.category(poi.categoryId),
                municipality: labels.municipality(poi.municipalityId),
                height: 220,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(height: 16),
              Text(
                poi.name,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PoiBadge(
                    icon: Icons.place_outlined,
                    label: labels.municipality(poi.municipalityId),
                  ),
                  if ((poi.poiType ?? labels.category(poi.categoryId))
                      .trim()
                      .isNotEmpty)
                    _PoiBadge(
                      icon: Icons.local_activity_outlined,
                      label: poi.poiType ?? labels.category(poi.categoryId),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (poi.address != null)
                Text(
                  poi.address!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              if (poi.operatingHours != null || poi.entranceFee != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (poi.operatingHours != null) poi.operatingHours!,
                    if (poi.entranceFee != null) 'Fee: ${poi.entranceFee}',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                poi.description ?? '',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'How to Get There',
                subtitle: 'Step-by-step directions to this attraction',
              ),
              const SizedBox(height: 12),
              if (poi.howToGetThere != null && poi.howToGetThere!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    poi.howToGetThere!,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _openDirections(context, poi),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Open in Google Maps',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            poi.address?.trim().isNotEmpty == true
                                ? poi.address!.trim()
                                : poi.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.3,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: const Text(
                    'Ask AI Guide About This',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC800),
                    foregroundColor: const Color(0xFF033300),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _askAiGuide(context, poi, labels),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Tourism Coordinator',
                subtitle: 'Contact the municipal Tourism Coordinator — sign in required',
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  Icons.business,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text(
                  'Send an inquiry',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Routed to this municipality’s Tourism Office',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _openInquiry(context, ref, poi.municipalityId),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.email),
                  label: const Text('Send Inquiry to Tourism Coordinator'),
                  onPressed: () =>
                      _openInquiry(context, ref, poi.municipalityId),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDirections(BuildContext context, PoiLogistics poi) async {
    final opened = await MapLauncher.openDirections(
      latitude: poi.latitude,
      longitude: poi.longitude,
      address: poi.address,
      label: poi.name,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps on this device.'),
        ),
      );
    }
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

  /// Pre-fills the AI Tour Guide with a grounded question about this place.
  void _askAiGuide(
    BuildContext context,
    PoiLogistics poi,
    LookupTables labels,
  ) {
    final municipality = labels.municipality(poi.municipalityId);
    final question =
        'Tell me about ${poi.name} in $municipality, Rizal — '
        'what to expect, best time to visit, and how to get there.';
    context.go('/assistant?q=${Uri.encodeQueryComponent(question)}');
  }
}

/// Small municipality / category badge used on the place detail screen.
class _PoiBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PoiBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy directions placeholder kept so existing named routes still resolve.
class DirectionsPage extends StatelessWidget {
  const DirectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Directions'), centerTitle: true),
      body: const Center(
        child: Text(
          'Open Google Maps from any event or place to get directions.',
        ),
      ),
    );
  }
}
