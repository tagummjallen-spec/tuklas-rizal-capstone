import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/event_card.dart';
import '../../../core/widgets/municipality_chip.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/event_item.dart';

/// Home / Discovery Hub — featured events, "Promote Towns and Events",
/// municipality + barangay + category filters.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _selectedMunicipalityId;
  String? _selectedBarangayName;
  String? _selectedCategoryId;

  final dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final discovery = ref.read(discoveryServiceProvider);

    // Barangay sub-filter: only show barangays for the selected municipality.
    final barangays = _selectedMunicipalityId != null
        ? RizalBarangays.forMunicipality(_selectedMunicipalityId!)
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Discover Rizal',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF033300),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'All 14 municipalities of the Province of Rizal',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
              ),
              const SizedBox(height: 16),

              // Municipality filter
              const Text(
                'Municipality',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: RizalMunicipalities.all.length,
                  itemBuilder: (_, i) {
                    final m = RizalMunicipalities.all[i];
                    final selected = _selectedMunicipalityId == m.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: MunicipalityChip(
                        municipality: m,
                        isSelected: selected,
                        onSelected: () {
                          setState(() {
                            _selectedMunicipalityId = m.id;
                            _selectedBarangayName = null;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Barangay sub-filter (shown when a municipality is selected)
              if (_selectedMunicipalityId != null) ...[
                Text(
                  'Barangay',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: barangays.length,
                    itemBuilder: (_, i) {
                      final b = barangays[i];
                      final selected = _selectedBarangayName == b;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(b),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _selectedBarangayName = b);
                          },
                          selectedColor: const Color(0xFFFFC800),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: selected
                                ? const Color(0xFF033300)
                                : const Color(0xFF6B6B6B),
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF033300)
                                : const Color(0xFFE5E5E5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SectionHeader(
                title: 'Category',
                subtitle: 'Filter by tourism interest',
              ),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: TourismCategories.all.length,
                  itemBuilder: (_, i) {
                    final c = TourismCategories.all[i];
                    final selected = _selectedCategoryId == c.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CategoryChip(
                        id: c.id,
                        name: c.name,
                        color: c.color,
                        isSelected: selected,
                        onSelected: () =>
                            setState(() => _selectedCategoryId = c.id),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // "Promote Towns and Events" — Form I: never "Recommendations"
              SectionHeader(
                title: AppConstants.promoteTownsAndEventsTitle,
                subtitle: AppConstants.promoteTownsAndEventsSubtitle,
              ),
              SizedBox(
                height: 230,
                child: StreamBuilder<List<EventItem>>(
                  stream: discovery.promoteTownsAndEvents,
                  builder: (context, snap) {
                    final events = snap.data ?? [];
                    final promoted = discovery.scorePromoteTownsAndEvents(
                      events: events,
                      userInterestCategoryIds:
                          _selectedCategoryId != null
                              ? [_selectedCategoryId!]
                              : [],
                      municipalityVisitCounts: {},
                    );
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: promoted.length,
                      itemBuilder: (_, i) {
                        final e = promoted[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 220,
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
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Featured Events
              SectionHeader(
                title: AppConstants.featuredEvents,
                onSeeAll: () => Navigator.of(context).pushNamed('/events'),
              ),
              SizedBox(
                height: 230,
                child: StreamBuilder<List<EventItem>>(
                  stream: discovery.featuredEvents,
                  builder: (context, snap) {
                    final events = snap.data ?? [];
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: events.length,
                      itemBuilder: (_, i) {
                        final e = events[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 220,
                            child: EventCard(
                              title: e.title,
                              municipality: e.municipalityId,
                              date: dateFormat.format(e.startDate),
                              category: e.categoryId ?? 'General',
                              imageUrl: e.imageUrl ??
                                  'https://via.placeholder.com/600x400',
                              isFeatured: true,
                              onTap: () =>
                                  Navigator.of(context).pushNamed('/event/${e.id}'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
