/// Mirrors `supabase/migrations/001_initial_schema.sql` `pois_logistics` table.
class PoiLogistics {
  final String id;
  final String name;
  final String? description;
  final String? categoryId;
  final String municipalityId;
  final String? barangayId;
  final String? address;
  final double? lat;
  final double? lng;
  final String? contactPerson; // Tourism Coordinator / establishment contact
  final String? contactPhone;
  final String? imageUrl;
  final bool isActive;

  PoiLogistics({
    required this.id,
    required this.name,
    this.description,
    this.categoryId,
    required this.municipalityId,
    this.barangayId,
    this.address,
    this.lat,
    this.lng,
    this.contactPerson,
    this.contactPhone,
    this.imageUrl,
    this.isActive = true,
  });

  factory PoiLogistics.fromJson(Map<String, dynamic> json) {
    return PoiLogistics(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      municipalityId: json['municipality_id'] as String,
      barangayId: json['barangay_id'] as String?,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      contactPerson: json['contact_person'] as String?,
      contactPhone: json['contact_phone'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'municipality_id': municipalityId,
      'barangay_id': barangayId,
      'address': address,
      'lat': lat,
      'lng': lng,
      'contact_person': contactPerson,
      'contact_phone': contactPhone,
      'image_url': imageUrl,
      'is_active': isActive,
    };
  }

  @override
  String toString() => 'PoiLogistics(id: $id, name: $name)';
}

/// Mirrors `supabase/migrations/001_initial_schema.sql` `coordinator_inquiries` table.
class CoordinatorInquiry {
  final String id;
  final String municipalityId;
  final String userId;
  final String subject;
  final String message;
  final String status; // 'open' | 'in_progress' | 'resolved' | 'closed'
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CoordinatorInquiry({
    required this.id,
    required this.municipalityId,
    required this.userId,
    required this.subject,
    required this.message,
    this.status = 'open',
    this.respondedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoordinatorInquiry.fromJson(Map<String, dynamic> json) {
    return CoordinatorInquiry(
      id: json['id'] as String,
      municipalityId: json['municipality_id'] as String,
      userId: json['user_id'] as String,
      subject: json['subject'] as String,
      message: json['message'] as String,
      status: json['status'] as String? ?? 'open',
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'municipality_id': municipalityId,
      'user_id': userId,
      'subject': subject,
      'message': message,
      'status': status,
      'responded_at': respondedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Mirrors `supabase/migrations/001_initial_schema.sql` `event_embeddings` table.
class EventEmbedding {
  final String id;
  final String eventId;
  final List<double> embedding;
  final String model;

  EventEmbedding({
    required this.id,
    required this.eventId,
    required this.embedding,
    this.model = 'llama-rag',
  });

  factory EventEmbedding.fromJson(Map<String, dynamic> json) {
    return EventEmbedding(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      embedding: (json['embedding'] as List<dynamic>).cast<double>(),
      model: json['model'] as String? ?? 'llama-rag',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'embedding': embedding,
      'model': model,
    };
  }
}
