// Mirrors `supabase/migrations/001_initial_schema.sql` conversation history (chat messages).

/// A verified Rizal event or place returned alongside an AI answer so the UI
/// can render actionable Follow / View Details cards.
enum ChatItemType { event, poi }

class ChatItem {
  final String id;
  final ChatItemType type;
  final String title;
  final String municipality;

  const ChatItem({
    required this.id,
    required this.type,
    required this.title,
    required this.municipality,
  });

  factory ChatItem.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString().toLowerCase() ?? 'poi';
    return ChatItem(
      id: json['id']?.toString() ?? '',
      type: rawType == 'event' ? ChatItemType.event : ChatItemType.poi,
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      municipality: json['municipality']?.toString() ?? 'Rizal',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type == ChatItemType.event ? 'event' : 'poi',
    'title': title,
    'municipality': municipality,
  };

  bool get isValid => id.isNotEmpty && title.isNotEmpty;
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final String? municipality;
  final List<String>? sources;
  final DateTime createdAt;

  /// Verified events/places referenced by this answer.
  final List<ChatItem> items;

  /// True when this bubble reports a transport/offline error rather than an
  /// answer from the live Edge Function.
  final bool isError;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.municipality,
    this.sources,
    required this.createdAt,
    this.items = const <ChatItem>[],
    this.isError = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      isUser: json['is_user'] as bool? ?? false,
      municipality: json['municipality'] as String?,
      sources: (json['sources'] as List<dynamic>?)?.cast<String>(),
      createdAt: DateTime.parse(json['created_at'] as String),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => ChatItem.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.isValid)
          .toList(),
      isError: json['is_error'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'is_user': isUser,
      'municipality': municipality,
      'sources': sources,
      'items': items.map((item) => item.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'is_error': isError,
    };
  }
}
