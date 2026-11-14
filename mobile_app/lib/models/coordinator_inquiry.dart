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
