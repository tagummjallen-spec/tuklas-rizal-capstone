import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/coordinator_inquiry.dart';
import '../models/municipality.dart';
import '../core/constants/municipalities.dart';

/// Interface for the Municipal Tourism Coordinator directory & inquiries.
abstract class CoordinatorService {
  /// Public directory — readable by guests.
  Stream<List<Municipality>> get coordinatorDirectory;

  /// Requires a signed-in user (RLS: user_id = auth.uid()).
  Future<void> submitInquiry(CoordinatorInquiry inquiry);

  /// Requires a signed-in user (RLS scopes to their own rows).
  Stream<List<CoordinatorInquiry>> getMyInquiries(String userId);

  /// RSVP / bookmark an event (writes to public.event_participation).
  Future<void> rsvpEvent(String eventId, String rsvpStatus, String userId);
  Stream<List<Map<String, dynamic>>> getMyParticipations(String userId);
}

/// ---------------------------------------------------------------------------
/// Production Supabase-backed implementation.
///
/// Directory: `public.municipalities`
///   (id, name, slug, description, latitude, longitude,
///    geofence_radius_meters, tourism_office_name,
///    coordinator_contact_email, coordinator_contact_phone,
///    tourism_office_address, visitor_priority_boost)
/// Inquiries: `public.coordinator_inquiries`
///   (municipality_id, user_id, subject, message, status) — id/created_at/
///   updated_at are DB-managed, and there is no responded_at column.
/// ---------------------------------------------------------------------------
class SupabaseCoordinatorService implements CoordinatorService {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Stream<List<Municipality>> get coordinatorDirectory =>
      _client.from('municipalities').stream(primaryKey: ['id']).order('name').map(
            (rows) => rows.map((r) => Municipality.fromJson(r)).toList(),
          );

  @override
  Future<void> submitInquiry(CoordinatorInquiry inquiry) async {
    await _client
        .from('coordinator_inquiries')
        .insert(inquiry.toInsertJson());
  }

  @override
  Stream<List<CoordinatorInquiry>> getMyInquiries(String userId) =>
      _client
          .from('coordinator_inquiries')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map((rows) =>
              rows.map((r) => CoordinatorInquiry.fromJson(r)).toList());

  @override
  Future<void> rsvpEvent(
    String eventId,
    String rsvpStatus,
    String userId,
  ) async {
    // Live columns: id, user_id, event_id, status, created_at.
    await _client.from('event_participation').upsert(
      {
        'event_id': eventId,
        'user_id': userId,
        'status': rsvpStatus,
      },
      onConflict: 'user_id,event_id',
    );
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
class MockCoordinatorService implements CoordinatorService {
  @override
  Stream<List<Municipality>> get coordinatorDirectory =>
      Stream.value(RizalMunicipalities.all
          .map((m) => Municipality(
                id: m.id,
                name: m.name,
                slug: m.id.replaceAll('_', '-'),
                description: m.description,
                latitude: m.geofenceLat,
                longitude: m.geofenceLng,
                geofenceRadiusMeters: m.geofenceRadiusMeters,
                tourismOfficeName: m.tourismOfficeContact,
                coordinatorContactEmail: m.tourismOfficeEmail,
              ))
          .toList());

  final _inquiries = <CoordinatorInquiry>[];
  final _controller = StreamController<List<CoordinatorInquiry>>.broadcast();

  @override
  Future<void> submitInquiry(CoordinatorInquiry inquiry) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _inquiries.add(inquiry);
    _controller.add(List.unmodifiable(_inquiries));
  }

  @override
  Stream<List<CoordinatorInquiry>> getMyInquiries(String userId) =>
      _controller.stream;

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
