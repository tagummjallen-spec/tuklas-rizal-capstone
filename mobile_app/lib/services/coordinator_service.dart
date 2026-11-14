import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/coordinator_inquiry.dart';
import '../models/municipality.dart';
import '../core/constants/municipalities.dart';

/// Interface for the Municipal Tourism Coordinator directory & inquiries.
abstract class CoordinatorService {
  Stream<List<Municipality>> get coordinatorDirectory;
  Future<void> submitInquiry(CoordinatorInquiry inquiry);
  Stream<List<CoordinatorInquiry>> get myInquiries;
  /// RSVP / bookmark an event (writes to public.event_participation).
  Future<void> rsvpEvent(String eventId, String rsvpStatus, String userId);
  Stream<List<Map<String, dynamic>>> getMyParticipations(String userId);
}

/// ---------------------------------------------------------------------------
/// Production Supabase-backed implementation.
/// Directory uses public.municipalities (+ public.users with role_tier >= 2
/// for Tourism Coordinators).
/// ---------------------------------------------------------------------------
class SupabaseCoordinatorService implements CoordinatorService {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Stream<List<Municipality>> get coordinatorDirectory =>
      _client
          .from('municipalities')
          .stream(primaryKey: ['id'])
          .eq('is_active', true)
          .map((rows) {
        return rows
            .map((r) => Municipality.fromJson(r))
            .toList();
      });

  @override
  Future<void> submitInquiry(CoordinatorInquiry inquiry) async {
    await _client.from('coordinator_inquiries').upsert({
      'id': inquiry.id,
      'municipality_id': inquiry.municipalityId,
      'user_id': inquiry.userId,
      'subject': inquiry.subject,
      'message': inquiry.message,
      'status': inquiry.status,
      'created_at': inquiry.createdAt.toIso8601String(),
      'updated_at': inquiry.updatedAt.toIso8601String(),
    });
  }

  @override
  Stream<List<CoordinatorInquiry>> get myInquiries =>
      _client
          .from('coordinator_inquiries')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((rows) {
        return rows
            .map((r) => CoordinatorInquiry.fromJson(r))
            .toList();
      });

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
class MockCoordinatorService implements CoordinatorService {
  @override
  Stream<List<Municipality>> get coordinatorDirectory =>
      Stream.value(RizalMunicipalities.all
          .map((m) => Municipality(
                id: m.id,
                name: m.name,
                description: m.description,
                geofenceLat: m.geofenceLat,
                geofenceLng: m.geofenceLng,
                geofenceRadiusMeters: m.geofenceRadiusMeters,
                tourismOfficeContact: m.tourismOfficeContact,
                tourismOfficeEmail: m.tourismOfficeEmail,
                website: m.website,
                imageUrl: m.imageAsset,
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
  Stream<List<CoordinatorInquiry>> get myInquiries =>
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
