/// Mirrors the live `public.coordinator_inquiries` table exactly.
///
/// Columns: `id`, `municipality_id`, `user_id`, `subject`, `message`,
/// `status`, `created_at`, `updated_at`.
///
/// The live table has NO `responded_at` column — writing it fails with PGRST204.
/// `id` is a DB-generated UUID, so it is never sent by the app.
class CoordinatorInquiry {
  final String id;
  final String municipalityId;
  final String userId;
  final String subject;
  final String message;
  final String status; // 'open' | 'in_progress' | 'resolved' | 'closed'
  final DateTime createdAt;
  final DateTime updatedAt;

  CoordinatorInquiry({
    required this.id,
    required this.municipalityId,
    required this.userId,
    required this.subject,
    required this.message,
    this.status = 'open',
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoordinatorInquiry.fromJson(Map<String, dynamic> json) {
    return CoordinatorInquiry(
      id: json['id'] as String,
      municipalityId: json['municipality_id'] as String,
      userId: json['user_id'] as String,
      subject: json['subject'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Insert payload — only columns that exist in `public.coordinator_inquiries`,
  /// and never the DB-generated `id`.
  Map<String, dynamic> toInsertJson() {
    return {
      'municipality_id': municipalityId,
      'user_id': userId,
      'subject': subject,
      'message': message,
      'status': status,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'municipality_id': municipalityId,
      'user_id': userId,
      'subject': subject,
      'message': message,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
