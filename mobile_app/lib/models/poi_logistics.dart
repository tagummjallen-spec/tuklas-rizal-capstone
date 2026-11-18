/// Mirrors the live `public.pois_logistics` table exactly.
///
/// Columns: `id`, `municipality_id`, `barangay_id`, `category_id`, `name`,
/// `poi_type`, `description`, `address`, `how_to_get_there`,
/// `operating_hours`, `entrance_fee`, `latitude`, `longitude`, `image_url`,
/// `is_promoted` (plus server-managed `created_at`).
class PoiLogistics {
  final String id;
  final String name;
  final String? description;
  final String? categoryId;
  final String municipalityId;
  final String? barangayId;
  final String? poiType; // heritage_site | unique_food | destination
  final String? address;
  final String? howToGetThere;
  final String? operatingHours;
  final String? entranceFee;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final bool isPromoted;
  final DateTime? createdAt;

  PoiLogistics({
    required this.id,
    required this.name,
    this.description,
    this.categoryId,
    required this.municipalityId,
    this.barangayId,
    this.poiType,
    this.address,
    this.howToGetThere,
    this.operatingHours,
    this.entranceFee,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.isPromoted = false,
    this.createdAt,
  });

  /// Whether this POI is a food/delicacy destination.
  bool get isFood {
    final type = (poiType ?? '').toLowerCase();
    return type.contains('food') ||
        (categoryId ?? '').toLowerCase().contains('food') ||
        (name.toLowerCase().contains('restaurant') ||
            name.toLowerCase().contains('food') ||
            name.toLowerCase().contains('stall'));
  }

  factory PoiLogistics.fromJson(Map<String, dynamic> json) {
    return PoiLogistics(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed place',
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      municipalityId: json['municipality_id'] as String,
      barangayId: json['barangay_id'] as String?,
      poiType: json['poi_type'] as String?,
      address: json['address'] as String?,
      howToGetThere: json['how_to_get_there'] as String?,
      operatingHours: json['operating_hours'] as String?,
      entranceFee: json['entrance_fee'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String?,
      isPromoted: json['is_promoted'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Only the columns that exist in `public.pois_logistics`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'municipality_id': municipalityId,
      'barangay_id': barangayId,
      'category_id': categoryId,
      'name': name,
      'poi_type': poiType,
      'description': description,
      'address': address,
      'how_to_get_there': howToGetThere,
      'operating_hours': operatingHours,
      'entrance_fee': entranceFee,
      'latitude': latitude,
      'longitude': longitude,
      'image_url': imageUrl,
      'is_promoted': isPromoted,
    };
  }

  @override
  String toString() => 'PoiLogistics(id: $id, name: $name)';
}

/// Mirrors the live `public.event_embeddings` table
/// (`id`, `event_id`, `embedding`, `model`, `created_at`).
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
