import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';

/// A single grounded assistant answer with its data provenance.
class RagReply {
  final String text;
  final String? municipality;
  final List<String> sources;
  final List<ChatItem> items;

  const RagReply(
    this.text, {
    this.municipality,
    this.sources = const [],
    this.items = const [],
  });
}

/// Contract for the live TuklasRizal AI Tour Guide.
///
/// Every answer is produced by the `rizal-ai-chat` Supabase Edge Function,
/// which retrieves approved events, POIs and tourism-office contacts from the
/// database before asking Groq (with Gemini fallback) to phrase the reply.
abstract class RagChatService {
  Stream<List<ChatMessage>> get messages;

  /// Sends [text] and, when present, scopes retrieval to [municipality].
  Future<void> sendMessage(String text, {String? municipality});

  Future<List<ChatMessage>> getHistory();
  Future<void> clearHistory();

  /// Last transport error, exposed so the UI can offer a friendly retry.
  String? get lastError;
}

/// Live implementation. There is no local knowledge base and no template
/// fallback: the Edge Function is the single source of answers.
class SupabaseRagChatService implements RagChatService {
  SupabaseRagChatService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final List<ChatMessage> _messages = <ChatMessage>[];
  final StreamController<List<ChatMessage>> _controller =
      StreamController<List<ChatMessage>>.broadcast();

  String? _lastError;

  /// QA/seed rows such as "Test 1" are never shown as recommendations, even if
  /// an older Edge Function deployment still returns them.
  static final RegExp _testRecordPattern = RegExp(
    r'\btest',
    caseSensitive: false,
  );

  @override
  String? get lastError => _lastError;

  @override
  Stream<List<ChatMessage>> get messages => _controller.stream;

  @override
  Future<List<ChatMessage>> getHistory() async =>
      List<ChatMessage>.unmodifiable(_messages);

  @override
  Future<void> clearHistory() async {
    _messages.clear();
    _lastError = null;
    _controller.add(const <ChatMessage>[]);
  }

  @override
  Future<void> sendMessage(String text, {String? municipality}) async {
    final prompt = text.trim();
    if (prompt.isEmpty) return;

    // Multi-turn context: previous user and assistant turns only.
    final history = _messages
        .where((message) => !message.isError)
        .map(
          (message) => <String, String>{
            'role': message.isUser ? 'user' : 'assistant',
            'text': message.text.length > 800
                ? message.text.substring(0, 800)
                : message.text,
          },
        )
        .toList();

    _messages.add(
      ChatMessage(
        id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
        text: prompt,
        isUser: true,
        createdAt: DateTime.now(),
      ),
    );
    _publish();
    _lastError = null;

    try {
      final response = await _client.functions.invoke(
        'rizal-ai-chat',
        body: <String, dynamic>{
          'message': prompt,
          'history': history,
          if (municipality != null && municipality.trim().isNotEmpty)
            'municipality': municipality.trim(),
        },
      );

      final data = _asMap(response.data);
      if (data == null) {
        throw const FormatException('Empty response from AI Tour Guide');
      }
      if (response.status >= 400) {
        throw Exception(
          data['error']?.toString() ??
              'AI Tour Guide returned status ${response.status}',
        );
      }

      final answer =
          _stringValue(data['reply']) ??
          _stringValue(data['answer']) ??
          _stringValue(data['text']) ??
          '';
      if (answer.isEmpty) {
        throw const FormatException('AI Tour Guide returned no answer');
      }

      final sources = _listValue(data['sources'])
          .map((source) => source.toString())
          .where((source) => source.isNotEmpty)
          .toList();

      // Verified records retrieved by the Edge Function, used for the inline
      // Follow / View Details action cards. Malformed entries are ignored.
      final items = _listValue(data['items'])
          .whereType<Map>()
          .map((item) => ChatItem.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.isValid && !_testRecordPattern.hasMatch(item.title))
          .toList();

      _messages.add(
        ChatMessage(
          id: 'msg-${DateTime.now().microsecondsSinceEpoch + 1}',
          text: answer,
          isUser: false,
          municipality: data['municipality']?.toString(),
          sources: sources.isEmpty ? null : sources,
          items: items,
          createdAt: DateTime.now(),
        ),
      );
    } catch (error) {
      _lastError = _friendlyError(error.toString());
      _messages.add(
        ChatMessage(
          id: 'msg-${DateTime.now().microsecondsSinceEpoch + 2}',
          text: _lastError!,
          isUser: false,
          isError: true,
          createdAt: DateTime.now(),
        ),
      );
    }
    _publish();
  }

  void _publish() => _controller.add(List<ChatMessage>.unmodifiable(_messages));

  static Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// Only accept real string answers so unexpected JSON shapes cannot leak
  /// map/list representations into the chat bubble.
  static String? _stringValue(dynamic raw) =>
      raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

  /// Malformed or unexpected list payloads are treated as empty, never as a
  /// cast failure that would discard an otherwise valid answer.
  static List<dynamic> _listValue(dynamic raw) =>
      raw is List ? raw : const <dynamic>[];

  static String _friendlyError(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('socketexception') ||
        value.contains('failed host lookup') ||
        value.contains('network') ||
        value.contains('offline') ||
        value.contains('connection')) {
      return 'You appear to be offline. Check your connection and retry. The '
          'AI Tour Guide needs internet access to verify Rizal records.';
    }
    if (value.contains('not found') || value.contains('404')) {
      return 'The AI Tour Guide service is not deployed yet. Ask your '
          'TuklasRizal administrator to deploy the rizal-ai-chat Edge Function.';
    }
    return 'I could not reach the TuklasRizal guide just now. Your question '
        'was not lost — please tap retry or send it again in a moment.';
  }
}
