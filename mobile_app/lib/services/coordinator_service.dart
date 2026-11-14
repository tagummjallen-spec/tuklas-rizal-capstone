import 'dart:async';

import '../models/coordinator_inquiry.dart';
import '../models/municipality.dart';
import '../core/constants/municipalities.dart';

/// Interface for the Municipal Tourism Coordinator directory & inquiries.
abstract class CoordinatorService {
  Stream<List<Municipality>> get coordinatorDirectory;
  Future<void> submitInquiry(CoordinatorInquiry inquiry);
  Stream<List<CoordinatorInquiry>> get myInquiries;
}

/// Stub coordinator service backed by the 14 Rizal municipalities.
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
}
