import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps driving/directions for an event or POI.
///
/// Coordinates win when present (most accurate); otherwise the venue or street
/// address is used as the destination query.
class MapLauncher {
  const MapLauncher._();

  static Uri directionsUri({
    double? latitude,
    double? longitude,
    String? address,
    String? label,
  }) {
    if (latitude != null && longitude != null) {
      return Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$latitude,$longitude&travelmode=driving',
      );
    }
    final query = (address ?? label ?? 'Rizal, Philippines').trim();
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${Uri.encodeComponent(query)}&travelmode=driving',
    );
  }

  /// Returns true when an external maps app accepted the intent.
  static Future<bool> openDirections({
    double? latitude,
    double? longitude,
    String? address,
    String? label,
  }) async {
    final uri = directionsUri(
      latitude: latitude,
      longitude: longitude,
      address: address,
      label: label,
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
