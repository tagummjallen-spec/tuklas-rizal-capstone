import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/municipalities.dart';
import '../models/event_item.dart';
import '../models/municipality.dart';
import '../models/poi_logistics.dart';

/// Interface for discovery data — events, POIs, municipalities.
abstract class DiscoveryService {
  Stream<List<EventItem>> get featuredEvents;
  Stream<List<EventItem>> get promoteTownsAndEvents; // Rule-Based AI
  Stream<List<PoiLogistics>> get pois;
  Stream<List<Municipality>> get municipalities;
  Future<List<EventItem>> getEventsByMunicipality(String municipalityId);
  Future<List<PoiLogistics>> getPoisByMunicipality(String municipalityId);
  Future<List<EventItem>> searchEvents(String query);

  /// Rule-Based AI "Promote Towns and Events" scoring.
  List<EventItem> scorePromoteTownsAndEvents({
    required List<EventItem> events,
    required List<String> userInterestCategoryIds,
    required Map<String, int> municipalityVisitCounts,
  });

  /// RSVP / participation tracking.
  Future<void> rsvpEvent(String eventId, String rsvpStatus, String userId);
  Stream<List<Map<String, dynamic>>> getMyParticipations(String userId);
}

/// ---------------------------------------------------------------------------
/// Production implementation backed by Supabase (wired to 001_initial_schema.sql).
/// Falls back to sample seed records when live tables are empty.
/// ---------------------------------------------------------------------------
class SupabaseDiscoveryService implements DiscoveryService {
  final SupabaseClient _client = Supabase.instance.client;

  // ---- Mock seed data (fallback when live tables are empty) ----
  static final List<EventItem> _mockEvents = [
    EventItem(
      id: 'evt-1',
      title: "Higantes Festival",
      description: "Angono's iconic giant-puppet cultural festival.",
      categoryId: 'festival',
      municipalityId: 'angono',
      organizerId: 'org-angono',
      status: 'approved',
      startDate: DateTime(2026, 11, 22),
      endDate: DateTime(2026, 11, 23),
      location: 'Angono Town Proper',
      imageUrl:
          'https://via.placeholder.com/600x400?text=Higantes+Festival',
      contactPerson: 'Angono Tourism Coordinator',
      contactEmail: 'tourism@angono.gov.ph',
      isFeatured: true,
      promotedRank: 0,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    ),
    EventItem(
      id: 'evt-2',
      title: 'Petroglyphs Heritage Walk',
      description: 'Guided tour of the Binangonan Petroglyphs.',
      categoryId: 'cultural',
      municipalityId: 'binangonan',
      organizerId: 'org-binangonan',
      status: 'approved',
      startDate: DateTime(2026, 11, 28),
      endDate: DateTime(2026, 11, 28),
      location: 'Binangonan Petroglyphs Site',
      imageUrl:
          'https://via.placeholder.com/600x400?text=Petroglyphs',
      contactPerson: 'Binangonan Tourism Coordinator',
      contactEmail: 'tourism@binangonan.gov.ph',
      promotedRank: 0,
      createdAt: DateTime(2026, 10, 5),
      updatedAt: DateTime(2026, 10, 5),
    ),
    EventItem(
      id: 'evt-3',
      title: 'Taytay Tiangge Fair',
      description: 'Weekend tiangge featuring local garments and delicacies.',
      categoryId: 'food_heritage',
      municipalityId: 'taytay',
      organizerId: 'org-taytay',
      status: 'approved',
      startDate: DateTime(2026, 12, 6),
      endDate: DateTime(2026, 12, 7),
      location: 'Taytay Municipal Grounds',
      imageUrl:
          'https://via.placeholder.com/600x400?text=Taytay+Tiangge',
      contactPerson: 'Taytay Tourism Coordinator',
      contactEmail: 'tourism@taytay.gov.ph',
      isFeatured: true,
      promotedRank: 0,
      createdAt: DateTime(2026, 10, 10),
      updatedAt: DateTime(2026, 10, 10),
    ),
  ];

  static final List<PoiLogistics> _mockPois = [
    PoiLogistics(
      id: 'poi-1',
      name: 'Angono Petroglyphs',
      description: 'Prehistoric rock engravings in Angono.',
      categoryId: 'cultural',
      municipalityId: 'angono',
      address: 'Angono, Rizal',
      contactPerson: 'Angono Tourism Coordinator',
      imageUrl:
          'https://via.placeholder.com/600x400?text=Angono+Petroglyphs',
    ),
    PoiLogistics(
      id: 'poi-2',
      name: 'Binangonan Petroglyphs',
      description: 'Ancient petroglyphs on the lakeshore of Binangonan.',
      categoryId: 'cultural',
      municipalityId: 'binangonan',
      address: 'Binangonan, Rizal',
      contactPerson: 'Binangonan Tourism Coordinator',
      imageUrl:
          'https://via.placeholder.com/600x400?text=Binangonan+Petroglyphs',
    ),
    PoiLogistics(
      id: 'poi-3',
      name: 'Santa Ana de Sapa Parish',
      description: 'Historic church in Taytay.',
      categoryId: 'cultural',
      municipalityId: 'taytay',
      address: 'Taytay, Rizal',
      contactPerson: 'Taytay Tourism Coordinator',
      imageUrl:
          'https://via.placeholder.com/600x400?text=Santa+Ana+Church',
    ),
    PoiLogistics(
      id: 'poi-4',
      name: 'Balaw-Balaw Restaurant',
      description: 'Famous Angono delicacy restaurant.',
      categoryId: 'food_heritage',
      municipalityId: 'angono',
      address: 'Angono, Rizal',
      contactPerson: 'Angono Tourism Coordinator',
      imageUrl:
          'https://via.placeholder.com/600x400?text=Balaw-Balaw',
    ),
  ];

  // ---- Streams (Supabase with mock fallback) ----

  @override
  Stream<List<EventItem>> get featuredEvents =>
      _client
          .from('events')
          .stream(primaryKey: ['id'])
          .eq('is_featured', true)
          .eq('status', 'approved')
          .map((rows) {
        final events = rows
            .map((r) => EventItem.fromJson(r))
            .toList();
        return events.isNotEmpty
            ? events
            : _mockEvents.where((e) => e.isFeatured).toList();
      });

  @override
  Stream<List<EventItem>> get promoteTownsAndEvents =>
      _client
          .from('events')
          .stream(primaryKey: ['id'])
          .eq('status', 'approved')
          .map((rows) {
        final events = rows
            .map((r) => EventItem.fromJson(r))
            .toList();
        return events.isNotEmpty
            ? events
            : _mockEvents; // scoring applied by consumers
      });

  @override
  Stream<List<PoiLogistics>> get pois =>
      _client
          .from('pois_logistics')
          .stream(primaryKey: ['id'])
          .eq('is_active', true)
          .map((rows) {
        final pois = rows
            .map((r) => PoiLogistics.fromJson(r))
            .toList();
        return pois.isNotEmpty ? pois : _mockPois;
      });

  @override
  Stream<List<Municipality>> get municipalities =>
      _client
          .from('municipalities')
          .stream(primaryKey: ['id'])
          .eq('is_active', true)
          .map((rows) {
        final munis = rows
            .map((r) => Municipality.fromJson(r))
            .toList();
        return munis.isNotEmpty
            ? munis
            : RizalMunicipalities.all
                .map((m) => Municipality(
                      id: m.id,
                      name: m.name,
                      description: m.description,
                      geofenceLat: m.geofenceLat,
                      geofenceLng: m.geofenceLng,
                      geofenceRadiusMeters: m.geofenceRadiusMeters,
                      tourismOfficeContact: m.tourismOfficeContact,
                      imageUrl: m.imageAsset,
                    ))
                .toList();
      });

  // ---- Futures (Supabase with mock fallback) ----

  @override
  Future<List<EventItem>> getEventsByMunicipality(
    String municipalityId,
  ) async {
    final response = await _client
        .from('events')
        .select()
        .eq('municipality_id', municipalityId)
        .eq('status', 'approved')
        .order('start_date', ascending: true);
    final events = response
        .map((r) => EventItem.fromJson(r))
        .toList();
    if (events.isNotEmpty) return events;
    return _mockEvents.where((e) => e.municipalityId == municipalityId).toList();
  }

  @override
  Future<List<PoiLogistics>> getPoisByMunicipality(
    String municipalityId,
  ) async {
    final response = await _client
        .from('pois_logistics')
        .select()
        .eq('municipality_id', municipalityId)
        .eq('is_active', true);
    final pois = response
        .map((r) => PoiLogistics.fromJson(r))
        .toList();
    if (pois.isNotEmpty) return pois;
    return _mockPois.where((p) => p.municipalityId == municipalityId).toList();
  }

  @override
  Future<List<EventItem>> searchEvents(String query) async {
    final q = query.toLowerCase();
    final response = await _client
        .from('events')
        .select()
        .eq('status', 'approved')
        .ilike('title', '%$q%');
    final events = response
        .map((r) => EventItem.fromJson(r))
        .toList();
    if (events.isNotEmpty) return events;
    return _mockEvents.where((e) =>
        e.title.toLowerCase().contains(q) ||
        (e.description ?? '').toLowerCase().contains(q)).toList();
  }

  // ---- Rule-Based AI "Promote Towns and Events" scoring ----
  ///
  /// Boosts under-visited municipalities (visitor_priority_boost) while
  /// matching user interests.
  @override
  List<EventItem> scorePromoteTownsAndEvents({
    required List<EventItem> events,
    required List<String> userInterestCategoryIds,
    required Map<String, int> municipalityVisitCounts,
  }) {
    return events.map((event) {
      int score = 0;

      // Interest match boost
      if (event.categoryId != null &&
          userInterestCategoryIds.contains(event.categoryId)) {
        score += 40;
      }

      // Under-visited municipality boost (visitor_priority_boost core rule)
      final visits = municipalityVisitCounts[event.municipalityId] ?? 0;
      if (visits == 0) {
        score += 30; // never visited — highest boost
      } else if (visits < 3) {
        score += 15; // lightly visited
      }

      // Featured boost
      if (event.isFeatured) score += 20;

      return event.copyWith(promotedRank: score);
    }).toList()
      ..sort((a, b) => b.promotedRank.compareTo(a.promotedRank));
  }

  // ---- RSVP / participation (event_participation) ----

  @override
  Future<void> rsvpEvent(
    String eventId,
    String rsvpStatus,
    String userId,
  ) async {
    await _client.from('event_participation').upsert({
      'event_id': eventId,
      'user_id': userId,
      'rsvp_status': rsvpStatus,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> getMyParticipations(
    String userId,
  ) {
    return _client
        .from('event_participation')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId);
  }
}

/// ---------------------------------------------------------------------------
/// Mock implementation — automatic fallback when Supabase is NOT configured.
/// ---------------------------------------------------------------------------
class MockDiscoveryService implements DiscoveryService {
  final SupabaseDiscoveryService _inner = SupabaseDiscoveryService();

  @override
  Stream<List<EventItem>> get featuredEvents => _inner.featuredEvents;

  @override
  Stream<List<EventItem>> get promoteTownsAndEvents =>
      _inner.promoteTownsAndEvents;

  @override
  Stream<List<PoiLogistics>> get pois => _inner.pois;

  @override
  Stream<List<Municipality>> get municipalities => _inner.municipalities;

  @override
  Future<List<EventItem>> getEventsByMunicipality(String municipalityId) =>
      _inner.getEventsByMunicipality(municipalityId);

  @override
  Future<List<PoiLogistics>> getPoisByMunicipality(String municipalityId) =>
      _inner.getPoisByMunicipality(municipalityId);

  @override
  Future<List<EventItem>> searchEvents(String query) =>
      _inner.searchEvents(query);

  @override
  List<EventItem> scorePromoteTownsAndEvents({
    required List<EventItem> events,
    required List<String> userInterestCategoryIds,
    required Map<String, int> municipalityVisitCounts,
  }) {
    return _inner.scorePromoteTownsAndEvents(
      events: events,
      userInterestCategoryIds: userInterestCategoryIds,
      municipalityVisitCounts: municipalityVisitCounts,
    );
  }

  @override
  Future<void> rsvpEvent(
    String eventId,
    String rsvpStatus,
    String userId,
  ) async {
    // No-op in mock mode.
  }

  @override
  Stream<List<Map<String, dynamic>>> getMyParticipations(String userId) =>
      Stream.value([]);
}

/// Extension to allow copyWith on EventItem for scoring.
extension EventItemCopy on EventItem {
  EventItem copyWith({int? promotedRank}) {
    return EventItem(
      id: id,
      title: title,
      description: description,
      shortSummary: shortSummary,
      categoryId: categoryId,
      municipalityId: municipalityId,
      barangayId: barangayId,
      organizerId: organizerId,
      status: status,
      startDate: startDate,
      endDate: endDate,
      location: location,
      address: address,
      lat: lat,
      lng: lng,
      imageUrl: imageUrl,
      contactPerson: contactPerson,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      isFeatured: isFeatured,
      promotedRank: promotedRank ?? this.promotedRank,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
