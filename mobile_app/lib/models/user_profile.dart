/// Mirrors the live `public.users` table exactly.
///
/// Columns: `id`, `email`, `full_name`, `avatar_url`, `role_tier`,
/// `role_title`, `municipality_id`, `barangay_id`, `is_approved`
/// (plus server-managed `created_at` / `updated_at`).
///
/// Do not add a column here without a matching migration — PostgREST rejects
/// unknown columns with PGRST204.
///
/// `role_tier` is an INTEGER column:
///   0 Resident & Tourist, 1 Barangay Official, 2 Tourism Coordinator
///   (Department Head), 3 Mayor / Municipal IT Admin,
///   4 Governor / Provincial IT Admin.
class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final int roleTier;
  final String roleTitle;
  final String? municipalityId;
  final String? barangayId;
  final bool isApproved;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    int roleTier = 0,
    String? roleTitle,
    this.municipalityId,
    this.barangayId,
    this.isApproved = true,
    this.createdAt,
  })  : roleTier = roleTier,
        roleTitle = roleTitle ?? roleTitleFor(roleTier);

  /// Human-readable LGU role title (Form I: never generic "Admin").
  static String roleTitleFor(int tier) {
    switch (tier) {
      case 1:
        return 'Barangay Official';
      case 2:
        return 'Tourism Coordinator';
      case 3:
        return 'Mayor / Municipal IT Admin';
      case 4:
        return 'Governor / Provincial IT Admin';
      default:
        return 'Resident & Tourist';
    }
  }

  /// Whether this user can publish events (tiers 2, 3, 4).
  bool get canPublishEvents => roleTier >= 2;

  /// Whether this user has province-wide oversight (tier 4).
  bool get isProvinceWide => roleTier == 4;

  /// Whether this user is LGU staff (tier 1 or above).
  bool get isLguStaff => roleTier >= 1;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'User',
      avatarUrl: json['avatar_url'] as String?,
      roleTier: parseRoleTier(json['role_tier']),
      roleTitle: json['role_title'] as String?,
      municipalityId: json['municipality_id'] as String?,
      barangayId: json['barangay_id'] as String?,
      isApproved: json['is_approved'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Only the columns that exist in `public.users`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'role_tier': roleTier,
      'role_title': roleTitle,
      'municipality_id': municipalityId,
      'barangay_id': barangayId,
      'is_approved': isApproved,
    };
  }

  /// `role_tier` arrives as an int from Postgres, but auth metadata can hold a
  /// stringified copy — accept both rather than throwing.
  static int parseRoleTier(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }
}

/// Mirrors the live `public.user_interests` table
/// (`user_id`, `category_id`, `created_at`).
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
