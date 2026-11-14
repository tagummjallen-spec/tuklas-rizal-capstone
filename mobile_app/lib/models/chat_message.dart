/// Mirrors `supabase/migrations/001_initial_schema.sql` conversation history (chat messages).
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final String? municipality;
  final List<String>? sources;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.municipality,
    this.sources,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      isUser: json['is_user'] as bool? ?? false,
      municipality: json['municipality'] as String?,
      sources: (json['sources'] as List<dynamic>?)?.cast<String>(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'is_user': isUser,
      'municipality': municipality,
      'sources': sources,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
