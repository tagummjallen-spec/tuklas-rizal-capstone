import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/interest_matcher.dart';
import '../../../core/utils/maps_launcher.dart';
import '../../../core/utils/tourism_images.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/poi_card.dart';
import '../../../core/widgets/section_header.dart';
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
  String _query = '';
  String? _municipalityId;
  String? _barangay;
  String? _categoryId;
  bool _promotedOnly = false;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rizal Event Hub — Province of Rizal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF033300),
        foregroundColor: Colors.white,
        elevation: 0,
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
            child: StreamBuilder<List<PoiLogistics>>(
              stream: discovery.pois,
              builder: (context, snap) {
                final pois = _interestFirst(
                  _filter(snap.data ?? [], labels),
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
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No places match your search.',
                          style: TextStyle(color: Color(0xFF6B6B6B)),
                        ),
                        if (filtered)
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text(
                              'Clear filters',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF033300),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pois.length,
                  itemBuilder: (_, i) {
                    final p = pois[i];
                    return StaggeredFadeIn(
                      key: ValueKey('poi-${p.id}'),
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PoiCard(
                          name: p.name,
                          municipality: labels.municipality(p.municipalityId),
                          category: p.poiType ?? labels.category(p.categoryId),
                          categoryKey:
                              p.poiType ?? labels.category(p.categoryId),
                          municipalityKey: labels.municipality(
                            p.municipalityId,
                          ),
                          imageUrl: p.imageUrl,
                          heroTag: 'poi-image-${p.id}',
                          isRecommended: recommended.matches(
                            p.categoryId,
                            labels.category(p.categoryId),
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
        ],
      ),
    );
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
      physics: const NeverScrollableScrollPhysics(),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFFFC800),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? const Color(0xFF033300) : const Color(0xFF6B6B6B),
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
              Hero(
                tag: 'poi-image-${poi.id}',
                child: TourismImage(
                  imageUrl: poi.imageUrl,
                  category: poi.poiType ?? labels.category(poi.categoryId),
                  municipality: labels.municipality(poi.municipalityId),
                  height: 220,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                poi.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF033300),
                ),
              ),
              const SizedBox(height: 8),
              if (poi.address != null)
                Text(
                  poi.address!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              if (poi.operatingHours != null || poi.entranceFee != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (poi.operatingHours != null) poi.operatingHours!,
                    if (poi.entranceFee != null) 'Fee: ${poi.entranceFee}',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                poi.description ?? '',
                style: const TextStyle(fontSize: 16, color: Color(0xFF1B1B1B)),
              ),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'How to Get There',
                subtitle: 'Step-by-step directions to this attraction',
              ),
              const SizedBox(height: 12),
              if (poi.howToGetThere != null && poi.howToGetThere!.isNotEmpty)
                Text(
                  poi.howToGetThere!,
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
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Open in Google Maps'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF033300),
                    side: const BorderSide(color: Color(0xFF033300)),
                  ),
                  onPressed: () => _openDirections(context, poi),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Tourism Coordinator',
                subtitle: 'Contact the municipal Tourism Coordinator — sign in required',
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.business, color: Color(0xFF033300)),
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
