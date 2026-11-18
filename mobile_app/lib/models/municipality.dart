/// Mirrors the live `public.municipalities` table exactly.
///
/// Columns: `id`, `name`, `slug`, `description`, `latitude`, `longitude`,
/// `geofence_radius_meters`, `tourism_office_name`, `coordinator_contact_email`,
/// `coordinator_contact_phone`, `tourism_office_address`,
/// `visitor_priority_boost` (plus server-managed `created_at`).
class Municipality {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final double? latitude;
  final double? longitude;
  final int? geofenceRadiusMeters;
  final String? tourismOfficeName;
  final String? coordinatorContactEmail;
  final String? coordinatorContactPhone;
  final String? tourismOfficeAddress;

  /// Rule-Based AI "Promote Towns and Events" boost (1.00 = neutral).
  final double visitorPriorityBoost;
  final DateTime? createdAt;

  Municipality({
    required this.id,
    required this.name,
    String? slug,
    this.description,
    this.latitude,
    this.longitude,
    this.geofenceRadiusMeters,
    this.tourismOfficeName,
    this.coordinatorContactEmail,
    this.coordinatorContactPhone,
    this.tourismOfficeAddress,
    this.visitorPriorityBoost = 1.0,
    this.createdAt,
  }) : slug = slug ?? _slugify(name);

  /// Display-safe office name even when the LGU has not filled it in.
  String get officeName =>
      tourismOfficeName ?? '$name Municipal Tourism Office';

  static String _slugify(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  factory Municipality.fromJson(Map<String, dynamic> json) {
    return Municipality(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadiusMeters: (json['geofence_radius_meters'] as num?)?.toInt(),
      tourismOfficeName: json['tourism_office_name'] as String?,
      coordinatorContactEmail: json['coordinator_contact_email'] as String?,
      coordinatorContactPhone: json['coordinator_contact_phone'] as String?,
      tourismOfficeAddress: json['tourism_office_address'] as String?,
      visitorPriorityBoost:
          (json['visitor_priority_boost'] as num?)?.toDouble() ?? 1.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Only the columns that exist in `public.municipalities`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'geofence_radius_meters': geofenceRadiusMeters,
      'tourism_office_name': tourismOfficeName,
      'coordinator_contact_email': coordinatorContactEmail,
      'coordinator_contact_phone': coordinatorContactPhone,
      'tourism_office_address': tourismOfficeAddress,
      'visitor_priority_boost': visitorPriorityBoost,
    };
  }

  @override
  String toString() => 'Municipality(id: $id, name: $name)';
}

/// Mirrors the live `public.barangays` table
/// (`id`, `municipality_id`, `name`, `latitude`, `longitude`, `created_at`).
class Barangay {
  final String id;
  final String municipalityId;
  final String name;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;

  Barangay({
    required this.id,
    required this.municipalityId,
    required this.name,
    this.latitude,
    this.longitude,
    this.createdAt,
  });

  factory Barangay.fromJson(Map<String, dynamic> json) {
    return Barangay(
      id: json['id'] as String,
      municipalityId: json['municipality_id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'municipality_id': municipalityId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
