/// Mirrors `supabase/migrations/001_initial_schema.sql` `municipalities` table.
class Municipality {
  final String id;
  final String name;
  final String province;
  final String? description;
  final double? geofenceLat;
  final double? geofenceLng;
  final int? geofenceRadiusMeters;
  final String? tourismOfficeContact;
  final String? tourismOfficeEmail;
  final String? website;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;

  Municipality({
    required this.id,
    required this.name,
    this.province = 'Rizal',
    this.description,
    this.geofenceLat,
    this.geofenceLng,
    this.geofenceRadiusMeters,
    this.tourismOfficeContact,
    this.tourismOfficeEmail,
    this.website,
    this.imageUrl,
    this.isActive = true,
    this.createdAt,
  });

  factory Municipality.fromJson(Map<String, dynamic> json) {
    return Municipality(
      id: json['id'] as String,
      name: json['name'] as String,
      province: json['province'] as String? ?? 'Rizal',
      description: json['description'] as String?,
      geofenceLat: (json['geofence_lat'] as num?)?.toDouble(),
      geofenceLng: (json['geofence_lng'] as num?)?.toDouble(),
      geofenceRadiusMeters: json['geofence_radius_m'] as int?,
      tourismOfficeContact: json['tourism_office_contact'] as String?,
      tourismOfficeEmail: json['tourism_office_email'] as String?,
      website: json['website'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'province': province,
      'description': description,
      'geofence_lat': geofenceLat,
      'geofence_lng': geofenceLng,
      'geofence_radius_m': geofenceRadiusMeters,
      'tourism_office_contact': tourismOfficeContact,
      'tourism_office_email': tourismOfficeEmail,
      'website': website,
      'image_url': imageUrl,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'Municipality(id: $id, name: $name)';
}

/// Mirrors `supabase/migrations/001_initial_schema.sql` `barangays` table.
class Barangay {
  final String id;
  final String municipalityId;
  final String name;
  final String? description;
  final bool isActive;

  Barangay({
    required this.id,
    required this.municipalityId,
    required this.name,
    this.description,
    this.isActive = true,
  });

  factory Barangay.fromJson(Map<String, dynamic> json) {
    return Barangay(
      id: json['id'] as String,
      municipalityId: json['municipality_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'municipality_id': municipalityId,
      'name': name,
      'description': description,
      'is_active': isActive,
    };
  }
}
