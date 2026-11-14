import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../models/chat_message.dart';
import '../../../services/rag_chat_service.dart';

/// Conversational AI Assistant (Llama LLM + RAG) — answers who, what, when,
/// how to get there, and coordinator contact details.
///
/// Backed by a stubbed RAG service until the full dataset + Llama pipeline are ready.
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _inputCtrl = TextEditingController();
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final chat = ref.read(ragChatServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.conversationalAssistant),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () async {
              await chat.clearHistory();
            },
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: chat.messages,
              builder: (context, snap) {
                final messages = snap.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Ask me about Rizal — festivals, heritage sites, foods, '
                      'or Tourism Coordinator contacts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Color(0xFF6B6B6B)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    return Align(
                      alignment: m.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.82,
                        ),
                        decoration: BoxDecoration(
                          color: m.isUser
                              ? const Color(0xFF033300)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: m.isUser
                              ? null
                              : Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.text,
                              style: TextStyle(
                                color: m.isUser
                                    ? Colors.white
                                    : const Color(0xFF1B1B1B),
                              ),
                            ),
                            if (!m.isUser && (m.sources ?? []).isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Sources: ${m.sources!.join(', ')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF6B6B6B),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ask about Higantes Festival, Petroglyphs, Tiangge...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12,
                        ),
                      ),
                      onSubmitted: _sending ? null : (_) => _send(chat),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF033300),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sending ? null : () => _send(chat),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(RagChatService chat) async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    await chat.sendMessage(text);
    setState(() => _sending = false);
  }
}
