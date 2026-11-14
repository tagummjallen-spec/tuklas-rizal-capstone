import 'dart:async';

import '../models/chat_message.dart';

/// A single canned RAG answer used by the mock pipeline.
class RagAnswer {
  final String question;
  final String answer;
  final String municipality;
  final List<String> sources;

  RagAnswer({
    required this.question,
    required this.answer,
    required this.municipality,
    this.sources = const [],
  });
}

/// Interface for the Conversational AI Assistant (Llama LLM + RAG).
///
/// Answers who, what, when, how to get there, and coordinator contact details.
abstract class RagChatService {
  Stream<List<ChatMessage>> get messages;
  Future<void> sendMessage(String text);
  Future<List<ChatMessage>> getHistory();
  Future<void> clearHistory();
  bool get isStubbed;
}

/// Stubbed Llama LLM + RAG assistant grounded in sample Rizal data.
///
/// Replaced with the real pgvector semantic-search pipeline once the full
/// Rizal dataset and Llama LLM are available (see DEFERRED_FEATURES.md).
class MockRagChatService implements RagChatService {
  final _messages = <ChatMessage>[];
  final _controller = StreamController<List<ChatMessage>>.broadcast();

  static final List<RagAnswer> _knowledgeBase = [
    RagAnswer(
      question: 'Higantes Festival Angono',
      answer:
          'The Higantes Festival is Angono’s iconic cultural celebration held every '
          'November, featuring giant papier-mâché puppets (higantes) paraded through '
          'the streets. It honors the town’s artistic heritage and San Clemente.',
      municipality: 'Angono',
      sources: ['Angono Municipal Tourism Office', 'TuklasRizal curated dataset'],
    ),
    RagAnswer(
      question: 'Binangonan Petroglyphs how to get there',
      answer:
          'The Binangonan Petroglyphs are ancient rock engravings located in Binangonan, '
          'Rizal, on the lakeshore of Laguna de Bay. From Manila, take the East service '
          'road of Manila East Road toward Binangonan; the site is signposted near the '
          'town proper. Contact the Binangonan Tourism Coordinator for guided tours.',
      municipality: 'Binangonan',
      sources: ['Binangonan Municipal Tourism Office', 'National Museum'],
    ),
    RagAnswer(
      question: 'Taytay Tiangge',
      answer:
          'Taytay’s Tiangge is a weekend marketplace famous for local garments, '
          'fashion finds, and Rizal delicacies. Visit the Taytay Municipal Grounds '
          'on Saturdays and Sundays. The Taytay Tourism Coordinator can provide '
          'stall directories and schedules.',
      municipality: 'Taytay',
      sources: ['Taytay Municipal Tourism Office'],
    ),
    RagAnswer(
      question: 'coordinator contact Angono',
      answer:
          'Reach the Angono Municipal Tourism Coordinator at the Angono Municipal '
          'Tourism Office. Email: tourism@angono.gov.ph. They handle inquiries about '
          'Higantes Festival, heritage sites, and local guides.',
      municipality: 'Angono',
      sources: ['Angono Municipal Tourism Office'],
    ),
    RagAnswer(
      question: 'coordinator contact Binangonan',
      answer:
          'Reach the Binangonan Municipal Tourism Coordinator at the Binangonan '
          'Municipal Tourism Office. They manage Petroglyphs tours and lakeshore '
          'attraction information.',
      municipality: 'Binangonan',
      sources: ['Binangonan Municipal Tourism Office'],
    ),
    RagAnswer(
      question: 'coordinator contact Taytay',
      answer:
          'Reach the Taytay Municipal Tourism Coordinator at the Taytay Municipal '
          'Tourism Office. They coordinate Tiangge schedules, Santa Ana Church visits, '
          'and garment-industry tours.',
      municipality: 'Taytay',
      sources: ['Taytay Municipal Tourism Office'],
    ),
  ];

  @override
  Stream<List<ChatMessage>> get messages => _controller.stream;

  @override
  Future<void> sendMessage(String text) async {
    final userMsg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: true,
      createdAt: DateTime.now(),
    );
    _messages.add(userMsg);
    _controller.add(List.unmodifiable(_messages));

    await Future.delayed(const Duration(milliseconds: 800));

    final lower = text.toLowerCase();
    RagAnswer? match;
    for (final entry in _knowledgeBase) {
      final keywords = entry.question.toLowerCase().split(' ');
      if (keywords.any((k) => lower.contains(k))) {
        match = entry;
        break;
      }
    }

    final answerText =
        match?.answer ??
        'I am still learning about Rizal. Please ask about the Higantes Festival '
        '(Angono), the Petroglyphs (Binangonan), or the Tiangge (Taytay). For '
        'coordinator contact details, name the municipality.';

    final botMsg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch + 1}',
      text: answerText,
      isUser: false,
      municipality: match?.municipality,
      sources: match?.sources,
      createdAt: DateTime.now(),
    );
    _messages.add(botMsg);
    _controller.add(List.unmodifiable(_messages));
  }

  @override
  Future<List<ChatMessage>> getHistory() async => List.unmodifiable(_messages);

  @override
  Future<void> clearHistory() async {
    _messages.clear();
    _controller.add([]);
  }

  @override
  bool get isStubbed => true;
}
