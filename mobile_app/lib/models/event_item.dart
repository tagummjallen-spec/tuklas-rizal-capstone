/// Mirrors `supabase/migrations/001_initial_schema.sql` `events` table.
///
/// status: 'draft' | 'published' | 'archived' | 'cancelled'.
/// promoted_rank: Rule-Based AI "Promote Towns and Events" boost rank.
class EventItem {
  final String id;
  final String title;
  final String? description;
  final String? shortSummary;
  final String? categoryId;
  final String municipalityId;
  final String? barangayId;
  final String organizerId;
  final String status; // 'draft' | 'published' | 'archived' | 'cancelled'
  final DateTime startDate;
  final DateTime endDate;
  final String? location;
  final String? address;
  final double? lat;
  final double? lng;
  final String? imageUrl;
  final String? contactPerson; // Tourism Coordinator contact
  final String? contactEmail;
  final String? contactPhone;
  final bool isFeatured;
  final int promotedRank;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventItem({
    required this.id,
    required this.title,
    this.description,
    this.shortSummary,
    this.categoryId,
    required this.municipalityId,
    this.barangayId,
    required this.organizerId,
    this.status = 'published',
    required this.startDate,
    required this.endDate,
    this.location,
    this.address,
    this.lat,
    this.lng,
    this.imageUrl,
    this.contactPerson,
    this.contactEmail,
    this.contactPhone,
    this.isFeatured = false,
    this.promotedRank = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      shortSummary: json['short_summary'] as String?,
      categoryId: json['category_id'] as String?,
      municipalityId: json['municipality_id'] as String,
      barangayId: json['barangay_id'] as String?,
      organizerId: json['organizer_id'] as String,
      status: json['status'] as String? ?? 'published',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      location: json['location'] as String?,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String?,
      contactPerson: json['contact_person'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      promotedRank: json['promoted_rank'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'short_summary': shortSummary,
      'category_id': categoryId,
      'municipality_id': municipalityId,
      'barangay_id': barangayId,
      'organizer_id': organizerId,
      'status': status,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'location': location,
      'address': address,
      'lat': lat,
      'lng': lng,
      'image_url': imageUrl,
      'contact_person': contactPerson,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'is_featured': isFeatured,
      'promoted_rank': promotedRank,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Whether the event is currently happening.
  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  @override
  String toString() => 'EventItem(id: $id, title: $title)';
}

/// Mirrors `supabase/migrations/001_initial_schema.sql` `event_participation` table.
class EventParticipation {
  final String id;
  final String userId;
  final String eventId;
  final String rsvpStatus; // 'going' | 'interested' | 'declined'
  final DateTime? participatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventParticipation({
    required this.id,
    required this.userId,
    required this.eventId,
    this.rsvpStatus = 'interested',
    this.participatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventParticipation.fromJson(Map<String, dynamic> json) {
    return EventParticipation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      eventId: json['event_id'] as String,
      rsvpStatus: json['rsvp_status'] as String? ?? 'interested',
      participatedAt: json['participated_at'] != null
          ? DateTime.parse(json['participated_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_id': eventId,
      'rsvp_status': rsvpStatus,
      'participated_at': participatedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
