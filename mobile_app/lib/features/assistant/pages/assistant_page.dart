import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/tuklas_colors.dart';
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
///
/// The screen owns the whole viewport (it is pushed on the root navigator, so
/// the five-tab bar never eats the chat area). The guide banner lives in a
/// floating [SliverAppBar]: scrolling the conversation up slides it away and
/// gives the messages the full height back.
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key, this.initialQuestion});

  /// Optional question passed from an event or POI detail page. When present it
  /// is placed in the composer so the visitor can send it immediately.
  final String? initialQuestion;

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  static const Color _forest = Color(0xFF033300);
  static const int _maxChars = 500;

  // Always starts empty: no placeholder text is ever pre-filled.
  final _inputCtrl = TextEditingController(text: '');
  final _scrollCtrl = ScrollController();
  String? _municipality;
  bool _sending = false;
  bool _retrying = false;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _applyInitialQuestion();
  }

  @override
  void didUpdateWidget(covariant AssistantPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuestion != widget.initialQuestion) {
      _applyInitialQuestion();
    }
  }

  void _applyInitialQuestion() {
    final question = widget.initialQuestion?.trim();
    if (question == null || question.isEmpty) return;
    _inputCtrl.text = question;
    _inputCtrl.selection = TextSelection.collapsed(offset: question.length);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmClear(RagChatService chat) async {
    if (!mounted || _clearing) return;
    setState(() => _clearing = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Clear conversation?'),
          content: const Text(
            'This removes the chat bubbles on this device. '
            'Your verified TuklasRizal records are not affected.',
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
      if (!mounted) return;
      if (confirmed == true) await chat.clearHistory();
      if (!mounted) return;
    } catch (_) {
      _showInputHint('Could not clear the chat. Please try again.');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final chat = ref.read(ragChatServiceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          _buildCollapsibleHeader(chat),
          StreamBuilder<List<ChatMessage>>(
            stream: chat.messages,
            builder: (context, snap) {
              final messages = snap.data ?? const <ChatMessage>[];
              if (messages.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _StarterPanel(onStarterTap: (text) => _send(chat, text)),
                );
              }
              _scrollToLatest();
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                sliver: SliverList.builder(
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
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _Composer(
        controller: _inputCtrl,
        sending: _sending,
        maxChars: _maxChars,
        onSubmitted: (text) => _send(chat, text),
      ),
    );
  }

  /// Floating, snapping (unpinned) app bar: it is visible at the top of the
  /// conversation and slides out of the way as soon as the visitor scrolls up,
  /// then returns on the first downward swipe.
  Widget _buildCollapsibleHeader(RagChatService chat) {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      expandedHeight: 232,
      backgroundColor: _forest,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleSpacing: 0,
      title: Text(
        'AI Tour Guide',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: 'Clear chat',
          onPressed: _clearing ? null : () => _confirmClear(chat),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _GuideHeader(
          municipality: _municipality,
          onMunicipalityChanged: (value) =>
              setState(() => _municipality = value),
        ),
      ),
    );
  }

  void _scrollToLatest() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _retry(RagChatService chat) async {
    if (!mounted || _sending || _retrying) return;
    setState(() => _retrying = true);
    try {
      final history = await chat.getHistory();
      if (!mounted) return;
      for (final message in history.reversed) {
        if (message.isUser && !message.isError) {
          await _send(chat, message.text);
          return;
        }
      }
      if (mounted) _showInputHint('Type your question again to retry.');
    } catch (_) {
      if (mounted) _showInputHint('Could not retry just now. Please try again.');
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _send(RagChatService chat, String rawText) async {
    if (!mounted || _sending) return;
    final text = rawText.trim();
    if (text.isEmpty) {
      _showInputHint('Type a question before sending.');
      return;
    }
    if (text.length > _maxChars) {
      _showInputHint('Messages must be $_maxChars characters or fewer.');
      return;
    }
    setState(() => _sending = true);
    _inputCtrl.clear();
    try {
      await chat.sendMessage(text, municipality: _municipality);
    } catch (_) {
      _showInputHint(
        'Could not reach the AI Tour Guide. Check your connection and retry.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showInputHint(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _forest),
    );
  }
}

/// Green banner with the guide title, the trust line and the focus-town
/// selector. It is the `background` of the floating [SliverAppBar], so it
/// collapses together with the bar.
class _GuideHeader extends StatelessWidget {
  final String? municipality;
  final ValueChanged<String?> onMunicipalityChanged;

  const _GuideHeader({
    required this.municipality,
    required this.onMunicipalityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.tuklasScheme;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF033300), Color(0xFF0A5A16)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC800),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF033300),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TuklasRizal Provincial Tourism Guide',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Verified events, heritage sites, routes & contacts',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.filter_alt_outlined,
                      color: Color(0xFFFFC800),
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Focus town:',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: municipality,
                            isExpanded: true,
                            isDense: true,
                            dropdownColor: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                            icon: Icon(
                              Icons.expand_more,
                              color: scheme.onSurfaceVariant,
                              size: 20,
                            ),
                            style: GoogleFonts.inter(
                              color: scheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'All 14 municipalities',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: scheme.onSurface,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              for (final town in RizalMunicipalities.all)
                                DropdownMenuItem<String?>(
                                  value: town.name,
                                  child: Text(
                                    town.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: scheme.onSurface,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: onMunicipalityChanged,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StarterPanel extends StatelessWidget {
  final ValueChanged<String> onStarterTap;

  const _StarterPanel({required this.onStarterTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.tuklasSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.tuklasGold, width: 1.5),
            ),
            child: Column(
              children: [
                Icon(Icons.tour, color: context.tuklasForestInk, size: 40),
                const SizedBox(height: 10),
                Text(
                  'Kamusta! I am your Rizal tour guide.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: context.tuklasInk,
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
                    color: context.tuklasMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Try asking:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.tuklasInk,
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
      color: context.tuklasSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.tuklasGold.withValues(alpha: 0.85),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 15,
                color: context.tuklasForestInk,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.tuklasInk,
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
    final isDark = context.tuklasIsDark;

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
                  color: isUser
                      ? (isDark
                            ? const Color(0xFF1F5A32)
                            : const Color(0xFF033300))
                      : (message.isError
                            ? (isDark
                                  ? const Color(0xFF322410)
                                  : const Color(0xFFFFF3E0))
                            : context.tuklasSurface),
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
                              : context.tuklasHairline,
                        ),
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
                          color: context.tuklasMuted,
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
                          foregroundColor: context.tuklasForestInk,
                          side: BorderSide(color: context.tuklasForestInk),
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

  /// `|---|:--:|` style separators carry no meaning on a phone; drop them.
  static bool _isTableSeparator(String line) =>
      line.contains('|') &&
      RegExp(r'^\|?[\s:\-|]+\|?$').hasMatch(line) &&
      line.contains('-');

  /// A row such as `| Tanay | April 12 | Falls |`.
  static bool _isTableRow(String line) =>
      !_isTableSeparator(line) && '|'.allMatches(line).length >= 2;

  /// Flattens one pipe row into a readable bullet instead of a table.
  static String _tableRowToText(String line) {
    final cells = line
        .split('|')
        .map(_clean)
        .where((cell) => cell.isNotEmpty)
        .toList();
    if (cells.isEmpty) return '';
    if (cells.length == 1) return cells.first;
    final label = cells.first;
    final rest = cells.skip(1).join(' · ');
    return '$label: $rest';
  }

  static String _clean(String line) => line
      .replaceFirst(_bullet, '')
      .replaceAll(RegExp(r'^#{1,6}\s*'), '')
      .replaceAll('__', '')
      .replaceAll('`', '')
      .trim();

  /// Splits `**label**` runs into bold spans so labels read cleanly.
  static List<InlineSpan> _spans(String text, Color accent) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(fontWeight: FontWeight.w800, color: accent),
        ),
      );
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final lines = text.split(RegExp(r'\r?\n'));
    final blocks = <Widget>[];
    final bodyColor = isError
        ? (context.tuklasIsDark
              ? const Color(0xFFFFD8A8)
              : const Color(0xFF7A4B00))
        : context.tuklasInk;
    final accent = context.tuklasForestInk;
    var i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        blocks.add(const SizedBox(height: 6));
        i++;
        continue;
      }
      // Tables are flattened into bullets: no raw pipes on mobile.
      if (_isTableSeparator(line)) {
        i++;
        continue;
      }
      if (_isTableRow(line)) {
        final row = _tableRowToText(line);
        if (row.isNotEmpty) {
          blocks.add(_BulletLine(text: row, bodyColor: bodyColor));
        }
        i++;
        continue;
      }
      if (_isBullet(line)) {
        while (i < lines.length && _isBullet(lines[i].trim())) {
          blocks.add(
            _BulletLine(
              text: _clean(lines[i].trim()),
              bodyColor: bodyColor,
            ),
          );
          i++;
        }
        continue;
      }
      if (_isHeader(line)) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 3),
            child: Text(
              _clean(line).replaceAll('**', ''),
              style: GoogleFonts.plusJakartaSans(
                color: accent,
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
            child: Text.rich(
              TextSpan(
                style: GoogleFonts.inter(
                  color: bodyColor,
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
                children: _spans(_clean(line), accent),
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
  final Color bodyColor;

  const _BulletLine({required this.text, required this.bodyColor});

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
            child: Text.rich(
              TextSpan(
                style: GoogleFonts.inter(
                  color: bodyColor,
                  fontSize: 12.5,
                  height: 1.5,
                ),
                children: _AssistantRichText._spans(
                  text,
                  context.tuklasForestInk,
                ),
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
        color: context.tuklasSurfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.tuklasHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 2),
            child: Text(
              'RECOMMENDED FOR YOUR REQUEST',
              style: GoogleFonts.plusJakartaSans(
                color: context.tuklasMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          for (final item in items.take(4))
            _AiItemCard(item: item, saved: saved),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _AiItemCard extends StatefulWidget {
  final ChatItem item;
  final SavedPlacesController saved;

  const _AiItemCard({required this.item, required this.saved});

  @override
  State<_AiItemCard> createState() => _AiItemCardState();
}

class _AiItemCardState extends State<_AiItemCard> {
  bool _saving = false;
  bool _navigating = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final saved = widget.saved;
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
                  ? const Color(0x26FFC800)
                  : const Color(0x26033000),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isEvent ? Icons.event_available : Icons.place_outlined,
              size: 15,
              color: context.tuklasForestInk,
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
                    color: context.tuklasInk,
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
                    color: context.tuklasMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: isSaved
                ? context.tuklasForestInk
                : context.tuklasSurface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _saving || _navigating
                  ? null
                  : () async {
                      if (!mounted || _saving || _navigating) return;
                      setState(() => _saving = true);
                      try {
                        if (isEvent) {
                          await saved.toggleEvent(_placeholderEvent(item));
                        } else {
                          await saved.togglePoi(_placeholderPoi(item));
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not update your saved list. Please '
                                'try again.',
                              ),
                              backgroundColor: Color(0xFF033300),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSaved
                        ? context.tuklasForestInk
                        : context.tuklasHairline,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSaved ? Icons.check : Icons.add,
                      size: 11,
                      color: isSaved
                          ? const Color(0xFF033300)
                          : context.tuklasForestInk,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isSaved
                          ? (isEvent ? 'Saved' : 'Following')
                          : (isEvent ? 'Interested' : 'Follow'),
                      style: GoogleFonts.inter(
                        color: isSaved
                            ? const Color(0xFF033300)
                            : context.tuklasForestInk,
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
              onTap: _saving || _navigating
                  ? null
                  : () async {
                      if (!mounted || _saving || _navigating) return;
                      setState(() => _navigating = true);
                      try {
                        await context.push(detailRoute);
                      } finally {
                        if (mounted) setState(() => _navigating = false);
                      }
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 6,
                ),
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
          color: context.tuklasSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.tuklasHairline),
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

/// Compact single-line composer that grows up to four lines.
///
/// The field starts empty with a short muted hint, the character counter stays
/// hidden until the visitor passes 350 characters, and the send button is a
/// 44px gold circle that sits comfortably above the keyboard.
class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final int maxChars;
  final ValueChanged<String> onSubmitted;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.maxChars,
    required this.onSubmitted,
  });

  static const int _counterThreshold = 350;

  @override
  Widget build(BuildContext context) {
    final scheme = context.tuklasScheme;

    return Container(
      decoration: BoxDecoration(
        color: context.tuklasSurface,
        border: Border(top: BorderSide(color: context.tuklasHairline)),
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.viewPaddingOf(context).bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              textInputAction: TextInputAction.send,
              onSubmitted: sending ? null : onSubmitted,
              minLines: 1,
              maxLines: 4,
              maxLength: maxChars,
              style: TextStyle(fontSize: 14, color: context.tuklasInk),
              cursorColor: scheme.primary,
              // Hidden until the message gets long, then shown small and muted.
              buildCounter:
                  (
                    context, {
                    required int currentLength,
                    required bool isFocused,
                    required int? maxLength,
                  }) {
                    if (currentLength <= _counterThreshold) return null;
                    return Padding(
                      padding: const EdgeInsets.only(top: 2, left: 4),
                      child: Text(
                        '$currentLength/$maxChars',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.tuklasMuted,
                        ),
                      ),
                    );
                  },
              decoration: InputDecoration(
                hintText: 'Ask about Rizal...',
                hintStyle: TextStyle(
                  color: context.tuklasMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                hintMaxLines: 1,
                isDense: true,
                filled: true,
                fillColor: context.tuklasSurfaceAlt,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: context.tuklasHairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: context.tuklasHairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: scheme.primary, width: 1.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: const Color(0xFFFFC800),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: sending
                    ? null
                    : () => onSubmitted(controller.text.trim()),
                child: Center(
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF033300),
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: Color(0xFF033300),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
