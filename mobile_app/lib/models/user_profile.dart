/// Mirrors `supabase/migrations/001_initial_schema.sql` `users` table.
///
/// role_tier: '1' Barangay Official, '2' Department Head/Tourism Office,
// '3' Mayor/Municipal IT Admin, '4' Governor/Provincial IT Admin.
class UserProfile {
  final String id;
  final String authUserId;
  final String email;
  final String fullName;
  final String roleTier; // '1' | '2' | '3' | '4'
  final String? municipalityId;
  final String? barangayId;
  final String? phone;
  final String? profileImageUrl;
  final bool isActive;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.authUserId,
    required this.email,
    required this.fullName,
    required this.roleTier,
    this.municipalityId,
    this.barangayId,
    this.phone,
    this.profileImageUrl,
    this.isActive = true,
    this.createdAt,
  });

  /// Human-readable LGU role title (Form I: never generic "Admin").
  String get roleTitle {
    switch (roleTier) {
      case '1':
        return 'Barangay Official';
      case '2':
        return 'Tourism Coordinator (Department Head)';
      case '3':
        return 'Mayor / Municipal IT Admin';
      case '4':
        return 'Governor / Provincial IT Admin';
      default:
        return 'Tourism Coordinator';
    }
  }

  /// Whether this user can publish events (tiers 2, 3, 4).
  bool get canPublishEvents => roleTier == '2' || roleTier == '3' || roleTier == '4';

  /// Whether this user has province-wide oversight (tier 4).
  bool get isProvinceWide => roleTier == '4';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      authUserId: json['auth_user_id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      roleTier: json['role_tier'] as String,
      municipalityId: json['municipality_id'] as String?,
      barangayId: json['barangay_id'] as String?,
      phone: json['phone'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_user_id': authUserId,
      'email': email,
      'full_name': fullName,
      'role_tier': roleTier,
      'municipality_id': municipalityId,
      'barangay_id': barangayId,
      'phone': phone,
      'profile_image_url': profileImageUrl,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

/// Mirrors `supabase/migrations/001_initial_schema.sql` `user_interests` table.
class UserInterest {
  final String userId;
  final String categoryId;
  final DateTime createdAt;

  UserInterest({
    required this.userId,
    required this.categoryId,
    required this.createdAt,
  });

  factory UserInterest.fromJson(Map<String, dynamic> json) {
    return UserInterest(
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'category_id': categoryId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
