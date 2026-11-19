import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/municipalities.dart';
import '../models/municipality.dart';

/// What triggered an in-app cultural alert.
enum GeofenceAlertKind { municipality, poi }

/// An entry event emitted when a visitor enters a Rizal municipality or comes
/// within approach distance of a registered heritage/POI record.
class GeofenceEntry {
  final Municipality municipality;
  final DateTime enteredAt;
  final GeofenceAlertKind kind;
  final String? poiName;
  final String? poiType;
  final double? distanceMeters;

  GeofenceEntry({
    required this.municipality,
    required this.enteredAt,
    this.kind = GeofenceAlertKind.municipality,
    this.poiName,
    this.poiType,
    this.distanceMeters,
  });

  bool get isPoi => kind == GeofenceAlertKind.poi;
}

/// Interface for municipal / POI GPS geofencing.
abstract class GeofenceService {
  Stream<GeofenceEntry> get entryEvents;
  Stream<bool> get isLocationEnabled;

  /// Requests OS location permission. Callers must first obtain RA 10173
  /// consent from the visitor (see the Data Privacy disclosure dialog).
  Future<bool> requestLocationPermission();
  Future<bool> isPermissionGranted();

  /// Begin on-device position checks. Town centres and registered POIs are
  /// loaded from Supabase (curated town centres are used if the API is down).
  Future<void> startMonitoring();
  void stopMonitoring();

  double distanceMeters(double lat1, double lng1, double lat2, double lng2);
  Municipality? municipalityAt(double lat, double lng);

  /// Kept for the developer simulator surface; simulated entries are always
  /// emitted so the capstone demo works reliably indoors.
  void setDebugMode(bool enabled);
  bool get isDebugMode;
  Future<void> simulateEntry(String municipalityId);

  Future<double?> getCurrentLatitude();
  Future<double?> getCurrentLongitude();
  void dispose();
}

class _NearbyPoi {
  final String id;
  final String name;
  final String? type;
  final double latitude;
  final double longitude;
  final String municipalityId;
  final String municipalityName;

  const _NearbyPoi({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.municipalityId,
    required this.municipalityName,
  });
}

/// Production implementation: geolocator for coordinates, Supabase for the
/// municipality centres and POI registry. No coordinate is uploaded by the app.
class GeolocatorGeofenceService implements GeofenceService {
  GeolocatorGeofenceService() {
    Future<bool>.microtask(() async {
      final enabled = await isPermissionGranted();
      _enabledController.add(enabled);
      return enabled;
    });
  }

  static const double _poiApproachRadiusMeters = 200;
  static const Duration _alertCooldown = Duration(minutes: 5);

  final _entryController = StreamController<GeofenceEntry>.broadcast();
  final _enabledController = StreamController<bool>.broadcast();
  StreamSubscription<Position>? _positionSub;

  List<Municipality> _municipalities = _curatedMunicipalities();
  final List<_NearbyPoi> _pois = <_NearbyPoi>[];
  final Map<String, DateTime> _lastNotifiedAt = <String, DateTime>{};

  bool _monitoring = false;
  bool _debugMode = false;
  String? _lastTownId;

  @override
  Stream<GeofenceEntry> get entryEvents => _entryController.stream;

  @override
  Stream<bool> get isLocationEnabled => _enabledController.stream;

  @override
  bool get isDebugMode => _debugMode;

  @override
  void setDebugMode(bool enabled) => _debugMode = enabled;

  @override
  double distanceMeters(double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

  @override
  Future<bool> isPermissionGranted() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      // Web browsers without geolocation support / denied permission.
      return false;
    }
  }

  @override
  Future<bool> requestLocationPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _enabledController.add(false);
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      _enabledController.add(granted);
      return granted;
    } catch (_) {
      _enabledController.add(false);
      return false;
    }
  }

  @override
  Future<void> startMonitoring() async {
    if (_monitoring) return;
    _monitoring = true;

    await _loadLiveGeofences();
    final granted = await isPermissionGranted();
    _enabledController.add(granted);
    if (!granted) {
      _monitoring = false;
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      _handlePosition(position);
    } catch (_) {
      // A first fix may be unavailable indoors; the stream still delivers one.
    }

    try {
      await _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 50,
        ),
      ).listen(
        _handlePosition,
        onError: (_) {
          _enabledController.add(false);
        },
      );
    } catch (_) {
      _monitoring = false;
    }
  }

  @override
  void stopMonitoring() {
    _monitoring = false;
    _positionSub?.cancel();
    _positionSub = null;
    _lastTownId = null;
    _enabledController.add(false);
  }

  @override
  void dispose() {
    stopMonitoring();
    _entryController.close();
    _enabledController.close();
  }

  /// Live municipality centres + registered POIs from Supabase. If the API is
  /// unreachable the curated 14 town centres remain available; no POI alerts
  /// are fabricated because POIs only ever come from the database.
  Future<void> _loadLiveGeofences() async {
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('municipalities')
          .select(
            'id,name,slug,description,latitude,longitude,'
            'geofence_radius_meters,tourism_office_name,'
            'coordinator_contact_email,coordinator_contact_phone',
          )
          .order('name')
          .limit(50);
      final live = rows
          .map((row) => Municipality.fromJson(Map<String, dynamic>.from(row)))
          .where((m) => m.latitude != null && m.longitude != null)
          .toList();
      if (live.isNotEmpty) {
        _municipalities = live;
      }

      final poiRows = await client
          .from('pois_logistics')
          .select(
            'id,name,poi_type,latitude,longitude,municipality_id',
          )
          .limit(500);
      final names = <String, String>{
        for (final m in _municipalities) m.id: m.name,
      };
      _pois
        ..clear()
        ..addAll(
          poiRows.where((row) {
            final lat = (row['latitude'] as num?)?.toDouble();
            final lng = (row['longitude'] as num?)?.toDouble();
            return lat != null && lng != null;
          }).map((row) {
            final municipalityId = row['municipality_id'] as String? ?? '';
            return _NearbyPoi(
              id: row['id'] as String? ?? '',
              name: row['name'] as String? ?? 'Heritage site',
              type: row['poi_type'] as String?,
              latitude: (row['latitude'] as num).toDouble(),
              longitude: (row['longitude'] as num).toDouble(),
              municipalityId: municipalityId,
              municipalityName: names[municipalityId] ?? 'Rizal',
            );
          }),
        );
    } catch (_) {
      // Offline / denied: curated municipal centres still drive town alerts.
    }
  }

  void _handlePosition(Position position) {
    if (!_monitoring) return;
    final town = municipalityAt(position.latitude, position.longitude);
    if (town != null && town.id != _lastTownId) {
      _lastTownId = town.id;
      _emit(
        GeofenceEntry(
          municipality: town,
          enteredAt: DateTime.now(),
        ),
        'town:${town.id}',
      );
    } else if (town == null) {
      _lastTownId = null;
    }

    for (final poi in _pois) {
      final distance = distanceMeters(
        position.latitude,
        position.longitude,
        poi.latitude,
        poi.longitude,
      );
      if (distance > _poiApproachRadiusMeters) continue;
      final key = 'poi:${poi.id}';
      if (!_canNotify(key)) continue;
      _emit(
        GeofenceEntry(
          municipality: _municipalityFor(poi),
          enteredAt: DateTime.now(),
          kind: GeofenceAlertKind.poi,
          poiName: poi.name,
          poiType: poi.type,
          distanceMeters: distance,
        ),
        key,
      );
    }
  }

  Municipality _municipalityFor(_NearbyPoi poi) {
    for (final m in _municipalities) {
      if (m.id == poi.municipalityId) return m;
    }
    return Municipality(id: poi.municipalityId, name: poi.municipalityName);
  }

  bool _canNotify(String key) {
    final last = _lastNotifiedAt[key];
    return last == null || DateTime.now().difference(last) > _alertCooldown;
  }

  void _emit(GeofenceEntry entry, String key, {bool force = false}) {
    if (!force && !_canNotify(key)) return;
    _lastNotifiedAt[key] = DateTime.now();
    if (!_entryController.isClosed) _entryController.add(entry);
  }

  @override
  Municipality? municipalityAt(double lat, double lng) {
    for (final m in _municipalities) {
      if (m.latitude == null || m.longitude == null) continue;
      final radius = (m.geofenceRadiusMeters ?? 5000).toDouble();
      if (distanceMeters(lat, lng, m.latitude!, m.longitude!) <= radius) {
        return m;
      }
    }
    return null;
  }

  @override
  Future<void> simulateEntry(String municipalityId) async {
    final municipality = _findMunicipality(municipalityId);
    if (municipality == null) return;
    // Demo entries bypass cooldown: the caller wants a visible alert every
    // time, even when two towns are selected back-to-back indoors.
    _emit(
      GeofenceEntry(municipality: municipality, enteredAt: DateTime.now()),
      'town:${municipality.id}',
      force: true,
    );
  }

  Municipality? _findMunicipality(String idOrSlug) {
    final normalized = _normalize(idOrSlug);
    for (final m in _municipalities) {
      if (m.id == idOrSlug ||
          _normalize(m.slug) == normalized ||
          _normalize(m.name) == normalized) {
        return m;
      }
    }
    for (final m in _curatedMunicipalities()) {
      if (_normalize(m.slug) == normalized || _normalize(m.name) == normalized) {
        return m;
      }
    }
    return null;
  }

  @override
  Future<double?> getCurrentLatitude() async {
    try {
      return (await Geolocator.getCurrentPosition()).latitude;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<double?> getCurrentLongitude() async {
    try {
      return (await Geolocator.getCurrentPosition()).longitude;
    } catch (_) {
      return null;
    }
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static List<Municipality> _curatedMunicipalities() => RizalMunicipalities.all
      .map(
        (town) => Municipality(
          id: town.id,
          name: town.name,
          slug: town.id.replaceAll('_', '-'),
          description: town.description,
          latitude: town.geofenceLat,
          longitude: town.geofenceLng,
          geofenceRadiusMeters: town.geofenceRadiusMeters,
          tourismOfficeName: town.tourismOfficeContact,
        ),
      )
      .toList(growable: false);
}
