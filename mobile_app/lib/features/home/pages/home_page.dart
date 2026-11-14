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
import '../../../services/discovery_service.dart';

/// Home / Discovery Hub — featured events, "Promote Towns and Events",
/// municipality + barangay + category filters.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.read(discoveryServiceProvider);
    final _dateFormat = DateFormat('MMM d, yyyy');

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
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: RizalMunicipalities.all.length,
                  itemBuilder: (_, i) {
                    final m = RizalMunicipalities.all[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: MunicipalityChip(
                        municipality: m,
                        isSelected: false,
                        onSelected: () {},
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

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
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CategoryChip(
                        id: c.id,
                        name: c.name,
                        color: c.color,
                        isSelected: false,
                        onSelected: () {},
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
                    final promoted = discovery is MockDiscoveryService
                        ? (discovery as MockDiscoveryService)
                            .scorePromoteTownsAndEvents(
                              events: events,
                              userInterestCategoryIds: [],
                              municipalityVisitCounts: {},
                            )
                        : events;
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
                              date: _dateFormat.format(e.startDate),
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
                              date: _dateFormat.format(e.startDate),
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
