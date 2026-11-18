import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/poi_card.dart';
import '../../../models/poi_logistics.dart';

/// Explore — Destinations, Cultural/Heritage Sites, Unique Rizal Foods &
/// Local Restaurants with directions ("How to Get There").
///
/// Browsing is open to guests; inquiries require a session.
class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.uniqueFoodsRestaurants),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: const [
                _Pill(label: 'All Destinations', selected: true),
                _Pill(label: 'Cultural & Heritage'),
                _Pill(label: 'Unique Foods'),
                _Pill(label: 'Restaurants'),
                _Pill(label: 'Tourist Spots'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<PoiLogistics>>(
              stream: ref.read(discoveryServiceProvider).pois,
              builder: (context, snap) {
                final pois = snap.data ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pois.length,
                  itemBuilder: (_, i) {
                    final p = pois[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: PoiCard(
                        name: p.name,
                        municipality: p.municipalityId,
                        category: p.poiType ?? 'General',
                        imageUrl: p.imageUrl ??
                            'https://via.placeholder.com/600x400',
                        onTap: () => context.push('/poi/${p.id}'),
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
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  const _Pill({required this.label, this.selected = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {},
        selectedColor: const Color(0xFFFFC800),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? const Color(0xFF033300) : const Color(0xFF6B6B6B),
        ),
      ),
    );
  }
}

/// POI detail page with "How to Get There" directions.
class PoiDetailPage extends ConsumerWidget {
  final String poiId;
  const PoiDetailPage({super.key, required this.poiId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<PoiLogistics>>(
      stream: ref.read(discoveryServiceProvider).pois,
      builder: (context, snap) {
        final pois = snap.data ?? [];
        final matches = pois.where((p) => p.id == poiId).toList();
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Place')),
            body: const Center(child: Text('Place not found.')),
          );
        }
        final poi = matches.first;
        return Scaffold(
          appBar: AppBar(title: Text(poi.name), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  poi.imageUrl ?? 'https://via.placeholder.com/600x400',
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const _PlaceholderImage(),
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
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                ),
              if (poi.operatingHours != null || poi.entranceFee != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (poi.operatingHours != null) poi.operatingHours!,
                    if (poi.entranceFee != null) 'Fee: ${poi.entranceFee}',
                  ].join(' · '),
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                poi.description ?? '',
                style:
                    const TextStyle(fontSize: 16, color: Color(0xFF1B1B1B)),
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
                  style:
                      const TextStyle(fontSize: 15, color: Color(0xFF1B1B1B)),
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
                subtitle:
                    const Text('Routed to this municipality’s Tourism Office'),
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

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      color: const Color(0xFFF7F6F2),
      child: const Icon(Icons.place, color: Color(0xFF033300), size: 48),
    );
  }
}

/// Directions helper page.
class DirectionsPage extends StatelessWidget {
  const DirectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Directions'), centerTitle: true),
      body: const Center(
        child: Text('Open external maps for step-by-step directions.'),
      ),
    );
  }
}
