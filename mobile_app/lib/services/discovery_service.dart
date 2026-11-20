import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/municipalities.dart';
import '../models/event_item.dart';
import '../models/municipality.dart';
import '../models/poi_logistics.dart';

/// Interface for discovery data — events, POIs, municipalities.
///
/// All reads are public: guests (no session) can browse events, POIs and
/// municipalities without signing in.
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

  /// RSVP / participation tracking. [rsvpStatus] is one of the values the live
  /// `event_participation.status` column accepts: 'going', 'interested',
  /// 'attended'.
  Future<void> rsvpEvent(String eventId, String rsvpStatus, String userId);

  /// Removes the user's participation row when an RSVP/bookmark is cleared.
  Future<void> removeRsvp(String eventId, String userId);
  Stream<List<Map<String, dynamic>>> getMyParticipations(String userId);
}

/// ---------------------------------------------------------------------------
/// Production implementation backed by Supabase, strictly aligned with the live
/// schema:
///   events:            status ('approved'), is_featured, start_date, ...
///   pois_logistics:    poi_type, how_to_get_there, is_promoted, ... (NO is_active)
///   municipalities:    latitude/longitude, tourism_office_name, ... (NO is_active)
///   event_participation: id, user_id, event_id, status, created_at
///                        (NO rsvp_status / updated_at)
/// Falls back to sample seed records when live tables are empty.
/// ---------------------------------------------------------------------------
class SupabaseDiscoveryService implements DiscoveryService {
  final SupabaseClient _client = Supabase.instance.client;

  // ---- Mock seed data (fallback when live tables are empty) ----
  static final List<EventItem> _mockEvents = [
    EventItem(
      id: 'evt-1',
      title: 'Higantes Festival',
      description: "Angono's iconic giant-puppet cultural festival.",
      categoryId: 'festival',
      municipalityId: 'angono',
      status: 'approved',
      startDate: DateTime(2026, 11, 22),
      endDate: DateTime(2026, 11, 23),
      venueName: 'Angono Town Proper',
      howToGetThere:
          'Ride a jeepney or UV Express bound for Angono from Shaw Blvd or Cubao; '
          'alight at Angono Town Plaza.',
      imageUrl: null,
      isFeatured: true,
      promotionWeight: 1.3,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    ),
    EventItem(
      id: 'evt-2',
      title: 'Petroglyphs Heritage Walk',
      description: 'Guided tour of the Binangonan Petroglyphs.',
      categoryId: 'cultural-arts',
      municipalityId: 'binangonan',
      status: 'approved',
      startDate: DateTime(2026, 11, 28),
      endDate: DateTime(2026, 11, 28),
      venueName: 'Binangonan Petroglyphs Site',
      howToGetThere:
          'Take a Binangonan-bound jeepney via Manila East Road and alight at '
          'Binangonan Municipal Hall.',
      imageUrl: null,
      promotionWeight: 1.1,
      createdAt: DateTime(2026, 10, 5),
      updatedAt: DateTime(2026, 10, 5),
    ),
    EventItem(
      id: 'evt-3',
      title: 'Taytay Tiangge Fair',
      description: 'Weekend tiangge featuring local garments and delicacies.',
      categoryId: 'food-heritage',
      municipalityId: 'taytay',
      status: 'approved',
      startDate: DateTime(2026, 12, 6),
      endDate: DateTime(2026, 12, 7),
      venueName: 'Taytay Municipal Grounds',
      howToGetThere:
          'Take a Taytay/Angono jeepney along Ortigas Avenue Extension and alight '
          'at Taytay Tiangge.',
      imageUrl: null,
      isFeatured: true,
      promotionWeight: 1.2,
      createdAt: DateTime(2026, 10, 10),
      updatedAt: DateTime(2026, 10, 10),
    ),
  ];

  static final List<PoiLogistics> _mockPois = [
    PoiLogistics(
      id: 'poi-1',
      name: 'Angono Petroglyphs',
      description: 'Prehistoric rock engravings in Angono.',
      categoryId: 'cultural-arts',
      municipalityId: 'angono',
      poiType: 'heritage_site',
      address: 'Angono, Rizal',
      howToGetThere: 'Charter a tricycle from Angono Poblacion.',
      operatingHours: '8:00 AM - 4:00 PM (Tue-Sun)',
      entranceFee: 'Free',
      imageUrl: null,
      isPromoted: true,
    ),
    PoiLogistics(
      id: 'poi-2',
      name: 'Binangonan Petroglyphs',
      description: 'Ancient petroglyphs on the lakeshore of Binangonan.',
      categoryId: 'cultural-arts',
      municipalityId: 'binangonan',
      poiType: 'heritage_site',
      address: 'Binangonan, Rizal',
      howToGetThere: 'Short tricycle ride from Binangonan Poblacion.',
      imageUrl: null,
    ),
    PoiLogistics(
      id: 'poi-3',
      name: 'Santa Ana de Sapa Parish',
      description: 'Historic church in Taytay.',
      categoryId: 'cultural-arts',
      municipalityId: 'taytay',
      poiType: 'heritage_site',
      address: 'Taytay, Rizal',
      howToGetThere: 'Alight at Taytay Municipal Hall and walk to the plaza.',
      imageUrl: null,
    ),
    PoiLogistics(
      id: 'poi-4',
      name: 'Balaw-Balaw Restaurant',
      description: 'Famous Angono delicacy restaurant.',
      categoryId: 'food-heritage',
      municipalityId: 'angono',
      poiType: 'unique_food',
      address: 'Angono, Rizal',
      operatingHours: '10:00 AM - 9:00 PM Daily',
      entranceFee: 'Free Gallery Entry',
      imageUrl: null,
      isPromoted: true,
    ),
  ];

  // ---- Streams (Supabase with mock fallback) ----

  @override
  Stream<List<EventItem>> get featuredEvents => _client
      .from('events')
      .stream(primaryKey: ['id'])
      .eq('is_featured', true)
      .eq('status', 'approved')
      .map((rows) {
        final events = rows.map((r) => EventItem.fromJson(r)).toList();
        return events.isNotEmpty
            ? events
            : _mockEvents.where((e) => e.isFeatured).toList();
      });

  @override
  Stream<List<EventItem>> get promoteTownsAndEvents => _client
      .from('events')
      .stream(primaryKey: ['id'])
      .eq('status', 'approved')
      .map((rows) {
        final events = rows.map((r) => EventItem.fromJson(r)).toList();
        return events.isNotEmpty
            ? events
            : _mockEvents; // scoring applied by consumers
      });

  @override
  Stream<List<PoiLogistics>> get pois =>
      _client.from('pois_logistics').stream(primaryKey: ['id']).map((rows) {
        final pois = rows.map((r) => PoiLogistics.fromJson(r)).toList();
        return pois.isNotEmpty ? pois : _mockPois;
      });

  @override
  Stream<List<Municipality>> get municipalities =>
      _client.from('municipalities').stream(primaryKey: ['id']).map((rows) {
        final munis = rows.map((r) => Municipality.fromJson(r)).toList();
        return munis.isNotEmpty
            ? munis
            : RizalMunicipalities.all
                  .map(
                    (m) => Municipality(
                      id: m.id,
                      name: m.name,
                      slug: m.id.replaceAll('_', '-'),
                      description: m.description,
                      latitude: m.geofenceLat,
                      longitude: m.geofenceLng,
                      geofenceRadiusMeters: m.geofenceRadiusMeters,
                      tourismOfficeName: m.tourismOfficeContact,
                    ),
                  )
                  .toList();
      });

  // ---- Futures (Supabase with mock fallback) ----

  @override
  Future<List<EventItem>> getEventsByMunicipality(String municipalityId) async {
    final response = await _client
        .from('events')
        .select()
        .eq('municipality_id', municipalityId)
        .eq('status', 'approved')
        .order('start_date', ascending: true);
    final events = response.map((r) => EventItem.fromJson(r)).toList();
    if (events.isNotEmpty) return events;
    return _mockEvents
        .where((e) => e.municipalityId == municipalityId)
        .toList();
  }

  @override
  Future<List<PoiLogistics>> getPoisByMunicipality(
    String municipalityId,
  ) async {
    final response = await _client
        .from('pois_logistics')
        .select()
        .eq('municipality_id', municipalityId);
    final pois = response.map((r) => PoiLogistics.fromJson(r)).toList();
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
    final events = response.map((r) => EventItem.fromJson(r)).toList();
    if (events.isNotEmpty) return events;
    return _mockEvents
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              (e.description ?? '').toLowerCase().contains(q),
        )
        .toList();
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

      // LGU promotion weight (events.promotion_weight)
      if (event.promotionWeight > 1.0) {
        score += ((event.promotionWeight - 1.0) * 40).round();
      }

      return event.withPromotedRank(score);
    }).toList()..sort((a, b) => b.promotedRank.compareTo(a.promotedRank));
  }

  // ---- RSVP / participation (event_participation) ----

  @override
  Future<void> rsvpEvent(
    String eventId,
    String rsvpStatus,
    String userId,
  ) async {
    // Live columns: id, user_id, event_id, status, created_at.
    await _client.from('event_participation').upsert({
      'event_id': eventId,
      'user_id': userId,
      'status': rsvpStatus,
    }, onConflict: 'user_id,event_id');
  }

  @override
  Future<void> removeRsvp(String eventId, String userId) async {
    await _client
        .from('event_participation')
        .delete()
        .eq('user_id', userId)
        .eq('event_id', eventId);
  }

  @override
  Stream<List<Map<String, dynamic>>> getMyParticipations(String userId) {
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
  @override
  Stream<List<EventItem>> get featuredEvents => Stream.value(
    SupabaseDiscoveryService._mockEvents.where((e) => e.isFeatured).toList(),
  );

  @override
  Stream<List<EventItem>> get promoteTownsAndEvents =>
      Stream.value(SupabaseDiscoveryService._mockEvents);

  @override
  Stream<List<PoiLogistics>> get pois =>
      Stream.value(SupabaseDiscoveryService._mockPois);

  @override
  Stream<List<Municipality>> get municipalities => Stream.value(
    RizalMunicipalities.all
        .map(
          (m) => Municipality(
            id: m.id,
            name: m.name,
            slug: m.id.replaceAll('_', '-'),
            description: m.description,
            latitude: m.geofenceLat,
            longitude: m.geofenceLng,
            geofenceRadiusMeters: m.geofenceRadiusMeters,
            tourismOfficeName: m.tourismOfficeContact,
          ),
        )
        .toList(),
  );

  @override
  Future<List<EventItem>> getEventsByMunicipality(
    String municipalityId,
  ) async => SupabaseDiscoveryService._mockEvents
      .where((e) => e.municipalityId == municipalityId)
      .toList();

  @override
  Future<List<PoiLogistics>> getPoisByMunicipality(
    String municipalityId,
  ) async => SupabaseDiscoveryService._mockPois
      .where((p) => p.municipalityId == municipalityId)
      .toList();

  @override
  Future<List<EventItem>> searchEvents(String query) async {
    final q = query.toLowerCase();
    return SupabaseDiscoveryService._mockEvents
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              (e.description ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  List<EventItem> scorePromoteTownsAndEvents({
    required List<EventItem> events,
    required List<String> userInterestCategoryIds,
    required Map<String, int> municipalityVisitCounts,
  }) {
    return events.map((event) {
      int score = 0;
      if (event.categoryId != null &&
          userInterestCategoryIds.contains(event.categoryId)) {
        score += 40;
      }
      final visits = municipalityVisitCounts[event.municipalityId] ?? 0;
      if (visits == 0) {
        score += 30;
      } else if (visits < 3) {
        score += 15;
      }
      if (event.isFeatured) score += 20;
      if (event.promotionWeight > 1.0) {
        score += ((event.promotionWeight - 1.0) * 40).round();
      }
      return event.withPromotedRank(score);
    }).toList()..sort((a, b) => b.promotedRank.compareTo(a.promotedRank));
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
  Future<void> removeRsvp(String eventId, String userId) async {
    // No-op in mock mode.
  }

  @override
  Stream<List<Map<String, dynamic>>> getMyParticipations(String userId) =>
      Stream.value([]);
}
