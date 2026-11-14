import 'dart:async';
import '../models/municipality.dart';
import '../core/constants/municipalities.dart';

/// Geofence entry event emitted when a user enters a municipality boundary.
class GeofenceEntry {
  final Municipality municipality;
  final DateTime enteredAt;

  GeofenceEntry({required this.municipality, required this.enteredAt});
}

/// Interface for geofencing & location services.
abstract class GeofenceService {
  Stream<GeofenceEntry> get entryEvents;
  Stream<bool> get isLocationEnabled;
  Future<bool> requestLocationPermission();
  Future<double?> getCurrentLatitude();
  Future<double?> getCurrentLongitude();
  /// Compute distance in meters between two lat/lng points.
  double distanceMeters(double lat1, double lng1, double lat2, double lng2);
  /// Check which municipality (if any) the given coordinates fall within.
  Municipality? municipalityAt(double lat, double lng);
  /// Enable/disable the dev debug simulator.
  void setDebugMode(bool enabled);
  bool get isDebugMode;
  /// Simulate entering a municipality — used by the debug panel.
  Future<void> simulateEntry(String municipalityId);
}

/// Production implementation using geolocator plugin.
class GeolocatorGeofenceService implements GeofenceService {
  final _entryController = StreamController<GeofenceEntry>.broadcast();
  bool _debugMode = false;
  GeofenceEntry? _lastNotified;

  @override
  Stream<GeofenceEntry> get entryEvents => _entryController.stream;

  @override
  Stream<bool> get isLocationEnabled => Stream.value(true);

  @override
  Future<bool> requestLocationPermission() async {
    // TODO: call geolocator.checkPermission / requestPermission
    return true;
  }

  @override
  Future<double?> getCurrentLatitude() async {
    // TODO: final pos = await Geolocator.getCurrentPosition(); return pos.latitude;
    return null;
  }

  @override
  Future<double?> getCurrentLongitude() async {
    return null;
  }

  @override
  double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_deg2rad(lat1)) * _cos(_deg2rad(lat2)) *
            _sin(dLng / 2) * _sin(dLng / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return (earthRadiusKm * c) * 1000;
  }

  @override
  Municipality? municipalityAt(double lat, double lng) {
    for (final m in RizalMunicipalities.all) {
      final d = distanceMeters(lat, lng, m.geofenceLat, m.geofenceLng);
      if (d <= m.geofenceRadiusMeters) {
        return Municipality(
          id: m.id,
          name: m.name,
          description: m.description,
          geofenceLat: m.geofenceLat,
          geofenceLng: m.geofenceLng,
          geofenceRadiusMeters: m.geofenceRadiusMeters,
          tourismOfficeContact: m.tourismOfficeContact,
          imageUrl: m.imageAsset,
        );
      }
    }
    return null;
  }

  @override
  void setDebugMode(bool enabled) => _debugMode = enabled;

  @override
  bool get isDebugMode => _debugMode;

  @override
  Future<void> simulateEntry(String municipalityId) async {
    if (!_debugMode) return;
    final m = RizalMunicipalities.byId(municipalityId);
    if (m == null) return;
    // Avoid re-notifying the same municipality within 5 minutes.
    if (_lastNotified?.municipality.id == m.id &&
        DateTime.now().difference(_lastNotified!.enteredAt) <
            const Duration(minutes: 5)) {
      return;
    }
    _lastNotified = GeofenceEntry(
      municipality: Municipality(
        id: m.id,
        name: m.name,
        description: m.description,
        geofenceLat: m.geofenceLat,
        geofenceLng: m.geofenceLng,
        geofenceRadiusMeters: m.geofenceRadiusMeters,
        tourismOfficeContact: m.tourismOfficeContact,
        imageUrl: m.imageAsset,
      ),
      enteredAt: DateTime.now(),
    );
    _entryController.add(_lastNotified!);
  }

  double _deg2rad(double deg) => deg * 3.141592653589793 / 180;
  double _sin(double x) {
    var result = x;
    var term = x;
    for (var i = 1; i <= 6; i++) {
      term *= -(x * x) / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
  double _cos(double x) => _sin(x + 3.141592653589793 / 2);
  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }
  double _atan(double x) {
    var result = x;
    var term = x;
    for (var i = 1; i <= 8; i++) {
      term *= -(x * x) * (2 * i - 1) / (2 * i + 1);
      result += term;
    }
    return result;
  }
  double _sqrt(double x) {
    if (x < 0) return 0;
    var guess = x;
    for (var i = 0; i < 10; i++) {
      guess = 0.5 * (guess + x / guess);
    }
    return guess;
  }
}

/// Mock implementation — no real location, fully simulated.
class MockGeofenceService implements GeofenceService {
  final _controller = StreamController<GeofenceEntry>.broadcast();
  bool _debugMode = false;

  @override
  Stream<GeofenceEntry> get entryEvents => _controller.stream;

  @override
  Stream<bool> get isLocationEnabled => Stream.value(true);

  @override
  Future<bool> requestLocationPermission() async => true;

  @override
  Future<double?> getCurrentLatitude() async => null;

  @override
  Future<double?> getCurrentLongitude() async => null;

  @override
  double distanceMeters(double a, double b, double c, double d) => 0;

  @override
  Municipality? municipalityAt(double lat, double lng) => null;

  @override
  void setDebugMode(bool enabled) => _debugMode = enabled;

  @override
  bool get isDebugMode => _debugMode;

  @override
  Future<void> simulateEntry(String municipalityId) async {
    if (!_debugMode) return;
    final m = RizalMunicipalities.byId(municipalityId);
    if (m == null) return;
    _controller.add(GeofenceEntry(
      municipality: Municipality(
        id: m.id,
        name: m.name,
        description: m.description,
        geofenceLat: m.geofenceLat,
        geofenceLng: m.geofenceLng,
        geofenceRadiusMeters: m.geofenceRadiusMeters,
        tourismOfficeContact: m.tourismOfficeContact,
        imageUrl: m.imageAsset,
      ),
      enteredAt: DateTime.now(),
    ));
  }
}
