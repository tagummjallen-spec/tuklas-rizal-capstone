/// Mirrors the live `public.events` table exactly.
///
/// Columns: `id`, `municipality_id`, `barangay_id`, `category_id`,
/// `created_by`, `approved_by`, `title`, `description`, `venue_name`,
/// `how_to_get_there`, `latitude`, `longitude`, `start_date`, `end_date`,
/// `image_url`, `status`, `is_featured`, `promotion_weight`
/// (plus server-managed `created_at` / `updated_at`).
///
/// `status` is an enum on the live project; approved events use `'approved'`.
class EventItem {
  final String id;
  final String title;
  final String? description;
  final String? categoryId;
  final String municipalityId;
  final String? barangayId;
  final String? venueName;
  final String? howToGetThere;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String status; // 'draft' | 'pending' | 'approved' | 'archived' | 'cancelled'
  final DateTime startDate;
  final DateTime endDate;
  final bool isFeatured;

  /// Rule-Based AI "Promote Towns and Events" weight stored in the DB.
  final double promotionWeight;

  /// In-app computed score (never written back to the DB).
  final int promotedRank;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventItem({
    required this.id,
    required this.title,
    this.description,
    this.categoryId,
    required this.municipalityId,
    this.barangayId,
    this.venueName,
    this.howToGetThere,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.status = 'approved',
    required this.startDate,
    required this.endDate,
    this.isFeatured = false,
    this.promotionWeight = 1.0,
    this.promotedRank = 0,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Back-compat alias used by the UI for `venue_name`.
  String? get location => venueName;

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled event',
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      municipalityId: json['municipality_id'] as String,
      barangayId: json['barangay_id'] as String?,
      venueName: json['venue_name'] as String?,
      howToGetThere: json['how_to_get_there'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String?,
      status: json['status'] as String? ?? 'approved',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isFeatured: json['is_featured'] as bool? ?? false,
      promotionWeight: (json['promotion_weight'] as num?)?.toDouble() ?? 1.0,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Only the columns that exist in `public.events`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'municipality_id': municipalityId,
      'barangay_id': barangayId,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'venue_name': venueName,
      'how_to_get_there': howToGetThere,
      'latitude': latitude,
      'longitude': longitude,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'image_url': imageUrl,
      'status': status,
      'is_featured': isFeatured,
      'promotion_weight': promotionWeight,
    };
  }

  /// Whether the event is currently happening.
  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  EventItem withPromotedRank(int rank) {
    return EventItem(
      id: id,
      title: title,
      description: description,
      categoryId: categoryId,
      municipalityId: municipalityId,
      barangayId: barangayId,
      venueName: venueName,
      howToGetThere: howToGetThere,
      latitude: latitude,
      longitude: longitude,
      imageUrl: imageUrl,
      status: status,
      startDate: startDate,
      endDate: endDate,
      isFeatured: isFeatured,
      promotionWeight: promotionWeight,
      promotedRank: rank,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() => 'EventItem(id: $id, title: $title)';
}

/// Mirrors the live `public.event_participation` table
/// (`id`, `user_id`, `event_id`, `status`, `created_at`).
///
/// The live table stores the RSVP in a `status` column that accepts
/// `'going'`, `'interested'` and `'attended'`. It has NO `rsvp_status`,
/// `updated_at` or `participated_at` column — writing those fails with
/// PGRST204.
class EventParticipation {
  final String id;
  final String userId;
  final String eventId;
  final String status; // 'going' | 'interested' | 'attended'
  final DateTime createdAt;

  EventParticipation({
    required this.id,
    required this.userId,
    required this.eventId,
    this.status = 'interested',
    required this.createdAt,
  });

  factory EventParticipation.fromJson(Map<String, dynamic> json) {
    return EventParticipation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      eventId: json['event_id'] as String,
      status: json['status'] as String? ?? 'interested',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'event_id': eventId,
      'status': status,
    };
  }
}
