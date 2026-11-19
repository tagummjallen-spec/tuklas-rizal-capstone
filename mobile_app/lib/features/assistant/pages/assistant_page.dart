import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../models/chat_message.dart';
import '../../../models/event_item.dart';
import '../../../models/poi_logistics.dart';
import '../../../services/rag_chat_service.dart';
import '../../../services/saved_places_service.dart';

const List<String> _starterPrompts = <String>[
  'Festivals in Angono & Tanay',
  'How to commute to Daranak Falls',
  'Lesser-known heritage spots',
  'Weekend family itinerary',
];

/// Live AI Tour Guide — Groq + Gemini fallback RAG answers grounded in the
/// approved events, POIs and tourism-office records stored in Supabase.
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  static const Color _forest = Color(0xFF033300);

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _municipality;
  bool _sending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final chat = ref.read(ragChatServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      appBar: AppBar(
        title: const Text('AI Tour Guide'),
        centerTitle: true,
        backgroundColor: _forest,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear chat',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Clear conversation?'),
                  content: const Text(
                    'This removes the chat bubbles on this device. Your '
                    'verified TuklasRizal records are not affected.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await chat.clearHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _GuideHeader(
            municipality: _municipality,
            onMunicipalityChanged: (value) =>
                setState(() => _municipality = value),
          ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: chat.messages,
              builder: (context, snap) {
                final messages = snap.data ?? const <ChatMessage>[];
                if (messages.isEmpty) {
                  return _StarterPanel(
                    onStarterTap: (text) => _send(chat, text),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.animateTo(
                      _scrollCtrl.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                });
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  itemCount: messages.length + (_sending ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (index == messages.length) {
                      return const _TypingIndicator();
                    }
                    return _ChatBubble(
                      message: messages[index],
                      onRetry: messages[index].isError
                          ? () => _retry(chat)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _inputCtrl,
            sending: _sending,
            onSubmitted: (text) => _send(chat, text),
          ),
        ],
      ),
    );
  }

  Future<void> _retry(RagChatService chat) async {
    final history = await chat.getHistory();
    for (final message in history.reversed) {
      if (message.isUser && !message.isError) {
        await _send(chat, message.text);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Type your question again to retry.'),
          backgroundColor: _forest,
        ),
      );
    }
  }

  Future<void> _send(RagChatService chat, String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    try {
      await chat.sendMessage(text, municipality: _municipality);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _GuideHeader extends StatelessWidget {
  final String? municipality;
  final ValueChanged<String?> onMunicipalityChanged;

  const _GuideHeader({
    required this.municipality,
    required this.onMunicipalityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF033300), Color(0xFF0A5A16)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC800),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF033300),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TuklasRizal Provincial Tourism Guide',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Verified events, heritage sites, routes & contacts',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC800).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFC800)),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFFFFC800),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                color: Color(0xFFFFC800),
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'Focus town:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String?>(
                    value: municipality,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    icon: const Icon(
                      Icons.expand_more,
                      color: Color(0xFF033300),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'All 14 municipalities',
                          style: TextStyle(
                            color: Color(0xFF033300),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      for (final town in RizalMunicipalities.all)
                        DropdownMenuItem<String?>(
                          value: town.name,
                          child: Text(
                            town.name,
                            style: const TextStyle(
                              color: Color(0xFF033300),
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                    onChanged: onMunicipalityChanged,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarterPanel extends StatelessWidget {
  final ValueChanged<String> onStarterTap;

  const _StarterPanel({required this.onStarterTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFC800), width: 1.5),
            ),
            child: Column(
              children: [
                const Icon(Icons.tour, color: Color(0xFF033300), size: 44),
                const SizedBox(height: 10),
                Text(
                  'Kamusta! I am your Rizal tour guide.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF033300),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ask in English, Tagalog or Taglish. I answer only from '
                  'verified TuklasRizal records — no invented dates, fees '
                  'or routes.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFF6B6B6B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Try asking:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF033300),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final starter in _starterPrompts)
                _StarterChip(
                  label: starter,
                  onTap: () => onStarterTap(starter),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StarterChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFC800)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: 15,
                color: Color(0xFF033300),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF033300),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends ConsumerWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const _ChatBubble({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final saved = ref.watch(savedPlacesProvider);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFFFC800),
                child: Icon(
                  message.isError ? Icons.wifi_off : Icons.tour,
                  size: 16,
                  color: const Color(0xFF033300),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(13),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                ),
                decoration: BoxDecoration(
                  // Warm off-white paper instead of a stark white bubble.
                  color: isUser
                      ? const Color(0xFF033300)
                      : (message.isError
                            ? const Color(0xFFFFF3E0)
                            : const Color(0xFFFDFBF5)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: isUser
                      ? null
                      : Border.all(
                          color: message.isError
                              ? const Color(0xFFFFC800)
                              : const Color(0xFFEDE6D3),
                        ),
                  boxShadow: isUser
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isUser)
                      Text(
                        message.text,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      _AssistantRichText(
                        text: message.text,
                        isError: message.isError,
                      ),
                    if (!isUser &&
                        !message.isError &&
                        (message.sources ?? []).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'VERIFIED SOURCES · ${message.sources!.join('  ·  ')}',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          color: const Color(0xFF8A8272),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                    if (!isUser &&
                        !message.isError &&
                        message.items.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _AiItemsSection(items: message.items, saved: saved),
                    ],
                    if (onRetry != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Retry'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF033300),
                          side: const BorderSide(color: Color(0xFF033300)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight markdown-style rendering: bold section headers, spaced bullets
/// and editorial body copy instead of one raw unformatted text run.
class _AssistantRichText extends StatelessWidget {
  final String text;
  final bool isError;

  const _AssistantRichText({required this.text, required this.isError});

  static final RegExp _bullet = RegExp(r'^([-*•]|\d+\.)\s+');

  static bool _isBullet(String line) => _bullet.hasMatch(line);

  static bool _isHeader(String line) {
    if (line.startsWith('**') && line.endsWith('**')) return true;
    if (line.startsWith('#')) return true;
    if (line.endsWith(':') && line.length <= 80) return true;
    return line.length <= 48 &&
        !line.endsWith('.') &&
        !line.endsWith('!') &&
        !line.endsWith('?') &&
        !_isBullet(line);
  }

  static String _clean(String line) => line
      .replaceFirst(_bullet, '')
      .replaceAll(RegExp(r'^#{1,6}\s*'), '')
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('`', '')
      .trim();

  @override
  Widget build(BuildContext context) {
    final lines = text.split(RegExp(r'\r?\n'));
    final blocks = <Widget>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        blocks.add(const SizedBox(height: 6));
        i++;
        continue;
      }
      if (_isBullet(line)) {
        while (i < lines.length && _isBullet(lines[i].trim())) {
          blocks.add(_BulletLine(text: _clean(lines[i].trim())));
          i++;
        }
        continue;
      }
      if (_isHeader(line)) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 3),
            child: Text(
              _clean(line),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF033300),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      } else {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _clean(line),
              style: GoogleFonts.inter(
                color: isError
                    ? const Color(0xFF7A4B00)
                    : const Color(0xFF2B2B2B),
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        );
      }
      i++;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;

  const _BulletLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFFFFC800),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: const Color(0xFF2B2B2B),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Verified places/events returned with the answer, rendered as compact
/// Follow / Interested + View Details action cards inside the AI bubble.
class _AiItemsSection extends StatelessWidget {
  final List<ChatItem> items;
  final SavedPlacesController saved;

  const _AiItemsSection({required this.items, required this.saved});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE6D3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 2),
            child: Text(
              'EXPLORE THESE VERIFIED RECORDS',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF033300),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          for (final item in items.take(5))
            _AiItemCard(item: item, saved: saved),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _AiItemCard extends StatelessWidget {
  final ChatItem item;
  final SavedPlacesController saved;

  const _AiItemCard({required this.item, required this.saved});

  @override
  Widget build(BuildContext context) {
    final isEvent = item.type == ChatItemType.event;
    final isSaved = isEvent
        ? saved.isEventSaved(item.id)
        : saved.isPoiSaved(item.id);
    final detailRoute = isEvent ? '/event/${item.id}' : '/poi/${item.id}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isEvent
                  ? const Color(0x18FFC800)
                  : const Color(0x18033300),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isEvent ? Icons.event_available : Icons.place_outlined,
              size: 15,
              color: const Color(0xFF033300),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF1B1B1B),
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.municipality} · ${isEvent ? 'Event' : 'Place'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF6B6B6B),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: isSaved ? const Color(0xFF033300) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                if (isEvent) {
                  await saved.toggleEvent(_placeholderEvent(item));
                } else {
                  await saved.togglePoi(_placeholderPoi(item));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSaved
                        ? const Color(0xFF033300)
                        : const Color(0xFFD8CFAE),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSaved ? Icons.check : Icons.add,
                      size: 11,
                      color: isSaved
                          ? const Color(0xFFFFC800)
                          : const Color(0xFF033300),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isSaved
                          ? (isEvent ? 'Saved' : 'Following')
                          : (isEvent ? 'Interested' : 'Follow'),
                      style: GoogleFonts.inter(
                        color: isSaved ? Colors.white : const Color(0xFF033300),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Material(
            color: const Color(0xFFFFC800),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push(detailRoute),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Details',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF033300),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: Color(0xFF033300),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _municipalityId(String name) {
  for (final town in RizalMunicipalities.all) {
    if (town.name.toLowerCase() == name.toLowerCase()) return town.id;
  }
  return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}

EventItem _placeholderEvent(ChatItem item) {
  final now = DateTime.now();
  return EventItem(
    id: item.id,
    title: item.title,
    municipalityId: _municipalityId(item.municipality),
    status: 'approved',
    startDate: now,
    endDate: now,
    createdAt: now,
    updatedAt: now,
  );
}

PoiLogistics _placeholderPoi(ChatItem item) => PoiLogistics(
  id: item.id,
  name: item.title,
  municipalityId: _municipalityId(item.municipality),
);

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: const SizedBox(
          width: 36,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFFFFC800),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onSubmitted;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.viewPaddingOf(context).bottom + 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              textInputAction: TextInputAction.send,
              onSubmitted: sending ? null : onSubmitted,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Ask about festivals, places, food or routes…',
                filled: true,
                fillColor: const Color(0xFFF7F6F2),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFFC800),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF033300),
                      ),
                    )
                  : const Icon(Icons.send, color: Color(0xFF033300)),
              tooltip: 'Send',
              onPressed: sending
                  ? null
                  : () => onSubmitted(controller.text.trim()),
            ),
          ),
        ],
      ),
    );
  }
}
