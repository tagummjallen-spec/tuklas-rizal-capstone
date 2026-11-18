import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';

/// A single grounded assistant answer with its data provenance.
class RagReply {
  final String text;
  final String? municipality;
  final List<String> sources;

  const RagReply(this.text, {this.municipality, this.sources = const []});
}

/// Interface for the Conversational AI Assistant (Llama LLM + RAG).
///
/// Answers who, what, when, how to get there, and coordinator contact details.
abstract class RagChatService {
  Stream<List<ChatMessage>> get messages;
  Future<void> sendMessage(String text);
  Future<List<ChatMessage>> getHistory();
  Future<void> clearHistory();

  /// True when answers come from the bundled offline knowledge base only.
  bool get isStubbed;

  /// When true the retrieved rows are handed to the Llama LLM for natural
  /// language phrasing; when false the grounded template is used directly.
  /// Toggling this never changes the chat UI.
  bool get useRemoteLlm;
}

/// ---------------------------------------------------------------------------
/// Shared chat pipeline: message bookkeeping + reply delivery. Subclasses only
/// provide [retrieve], so the UI contract is identical for mock, live-retrieval
/// and future LLM-backed implementations.
/// ---------------------------------------------------------------------------
abstract class _RagChatBase implements RagChatService {
  final _messages = <ChatMessage>[];
  final _controller = StreamController<List<ChatMessage>>.broadcast();

  Future<RagReply> retrieve(String text);

  @override
  bool get isStubbed => true;

  @override
  bool get useRemoteLlm => false;

  @override
  Stream<List<ChatMessage>> get messages => _controller.stream;

  @override
  Future<void> sendMessage(String text) async {
    final userMsg = ChatMessage(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      isUser: true,
      createdAt: DateTime.now(),
    );
    _messages.add(userMsg);
    _controller.add(List.unmodifiable(_messages));

    RagReply reply;
    try {
      reply = await retrieve(text);
    } catch (_) {
      reply = OfflineRizalKnowledge.answer(text);
    }

    final botMsg = ChatMessage(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch + 1}',
      text: reply.text,
      isUser: false,
      municipality: reply.municipality,
      sources: reply.sources.isEmpty ? null : reply.sources,
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
}

/// ---------------------------------------------------------------------------
/// Live retrieval implementation — grounded in the Supabase project.
///
/// Reads only columns that exist on the live project:
///   municipalities (name, description, tourism_office_name,
///                   coordinator_contact_email/phone, tourism_office_address)
///   events          (status = 'approved', venue_name, how_to_get_there, dates)
///   pois_logistics  (poi_type, address, how_to_get_there, operating_hours,
///                    entrance_fee)
/// Falls back to the offline knowledge base when offline, unauthenticated in a
/// way that fails the request, or when no record matches.
/// ---------------------------------------------------------------------------
class SupabaseRagChatService extends _RagChatBase {
  SupabaseRagChatService({this.useRemoteLlm = false})
      : _client = Supabase.instance.client;

  final SupabaseClient _client;

  @override
  final bool useRemoteLlm;

  @override
  bool get isStubbed => false;

  static const String _municipalityColumns =
      'id,name,slug,description,latitude,longitude,geofence_radius_meters,'
      'tourism_office_name,coordinator_contact_email,coordinator_contact_phone,'
      'tourism_office_address,visitor_priority_boost';

  static const String _eventColumns =
      'id,title,description,municipality_id,barangay_id,category_id,'
      'venue_name,how_to_get_there,latitude,longitude,start_date,end_date,'
      'image_url,status,is_featured,promotion_weight';

  static const String _poiColumns =
      'id,name,description,municipality_id,barangay_id,category_id,poi_type,'
      'address,how_to_get_there,operating_hours,entrance_fee,latitude,longitude,'
      'image_url,is_promoted';

  @override
  Future<RagReply> retrieve(String text) async {
    try {
      final municipalities = await _client
          .from('municipalities')
          .select(_municipalityColumns)
          .order('name');
      final events = await _client
          .from('events')
          .select(_eventColumns)
          .eq('status', 'approved')
          .order('start_date');
      final pois =
          await _client.from('pois_logistics').select(_poiColumns).order('name');

      final grounded = _compose(
        query: text,
        municipalities: municipalities,
        events: events,
        pois: pois,
      );
      final reply = grounded ?? OfflineRizalKnowledge.answer(text);
      return await _finalize(text, reply);
    } catch (_) {
      // Offline, network error or RLS denial — keep the assistant usable.
      return OfflineRizalKnowledge.answer(text);
    }
  }

  /// Hook for the Llama endpoint. Today the grounded template is returned.
  Future<RagReply> _finalize(String query, RagReply grounded) async {
    if (!useRemoteLlm) return grounded;
    final remote = await _composeWithRemoteLlm(query, grounded);
    return remote ?? grounded;
  }

  /// Placeholder for the future Llama call (Supabase Edge Function
  /// `/rag-chat`). Send [grounded] as the RAG context and return the model's
  /// phrasing. Returning null keeps the grounded answer, so the UI never
  /// depends on the model being available.
  Future<RagReply?> _composeWithRemoteLlm(String query, RagReply grounded) {
    return Future<RagReply?>.value(null);
  }

  // ---- Grounding / composition -------------------------------------------

  RagReply? _compose({
    required String query,
    required List<Map<String, dynamic>> municipalities,
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> pois,
  }) {
    final q = _normalize(query);
    final intent = _Intent.from(q);

    final municipality = _matchMunicipality(q, municipalities);
    final nameById = <String, String>{
      for (final m in municipalities)
        if (m['id'] is String) m['id'] as String: (m['name'] as String? ?? ''),
    };

    if (municipality != null) {
      final id = municipality['id'];
      return _municipalityAnswer(
        municipality: municipality,
        events: events.where((e) => e['municipality_id'] == id).toList(),
        pois: pois.where((p) => p['municipality_id'] == id).toList(),
        intent: intent,
      );
    }

    if (!intent.any) return null;
    return _provinceAnswer(
      events: events,
      pois: pois,
      municipalities: municipalities,
      nameById: nameById,
      intent: intent,
    );
  }

  RagReply _municipalityAnswer({
    required Map<String, dynamic> municipality,
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> pois,
    required _Intent intent,
  }) {
    final name = (municipality['name'] as String? ?? 'This municipality');
    final description = _text(municipality['description']);
    final generic = !intent.any;

    final buffer = StringBuffer('$name, Rizal');
    if (description.isNotEmpty) buffer.write(' — $description');
    final sources = <String>['public.municipalities ($name)'];

    if (intent.contact || generic) {
      final office = _text(municipality['tourism_office_name']).isEmpty
          ? '$name Municipal Tourism Office'
          : _text(municipality['tourism_office_name']);
      final email = _text(municipality['coordinator_contact_email']);
      final phone = _text(municipality['coordinator_contact_phone']);
      final address = _text(municipality['tourism_office_address']);
      buffer.writeln('\n\nTourism Coordinator — $office');
      if (email.isNotEmpty) buffer.writeln('• Email: $email');
      if (phone.isNotEmpty) buffer.writeln('• Phone: $phone');
      if (address.isNotEmpty) buffer.writeln('• Address: $address');
      if (email.isEmpty && phone.isEmpty) {
        buffer.writeln(
          '• No published contact details yet — send an inquiry from the '
          'Coordinators tab and it will be routed to the $name Tourism Coordinator.',
        );
      }
      sources.add('public.municipalities ($name — coordinator contact)');
    }

    final foodPois = pois.where(_isFoodPoi).toList();
    if (intent.food || generic) {
      if (foodPois.isNotEmpty) {
        buffer.writeln('\n\nFood & local delicacies in $name:');
        for (final p in foodPois.take(4)) {
          buffer.writeln('• ${_poiLine(p)}');
        }
        sources.add('public.pois_logistics ($name — food & heritage)');
      } else if (intent.food) {
        buffer.writeln(
          '\n\nNo food or delicacy listings are published for $name yet.',
        );
      }
    }

    if (intent.festival || generic) {
      if (events.isNotEmpty) {
        buffer.writeln('\n\nApproved events in $name:');
        for (final e in events.take(4)) {
          buffer.writeln('• ${_eventLine(e)}');
        }
        sources.add('public.events ($name — status = approved)');
      } else if (intent.festival) {
        buffer.writeln(
          '\n\nThere are no approved events published for $name right now.',
        );
      }
    }

    if (intent.directions) {
      final routeEvent = _firstWithRoute(events);
      final routePoi = _firstWithRoute(pois);
      buffer.writeln('\n\nHow to get there:');
      if (routeEvent != null) {
        buffer.writeln(
          '• ${_text(routeEvent['title'])}: ${_text(routeEvent['how_to_get_there'])}',
        );
      }
      if (routePoi != null) {
        buffer.writeln(
          '• ${_text(routePoi['name'])}: ${_text(routePoi['how_to_get_there'])}',
        );
      }
      if (routeEvent == null && routePoi == null) {
        buffer.writeln(
          '• No published route guide for $name yet — message the Tourism '
          'Coordinator for directions.',
        );
      }
      sources.add('public.events / public.pois_logistics (how_to_get_there)');
    }

    if (generic && pois.isNotEmpty) {
      buffer.writeln('\n\nPlaces to visit in $name:');
      for (final p in pois.take(3)) {
        buffer.writeln('• ${_poiLine(p)}');
      }
      sources.add('public.pois_logistics ($name)');
    }

    return RagReply(
      buffer.toString().trim(),
      municipality: name,
      sources: sources,
    );
  }

  RagReply? _provinceAnswer({
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> pois,
    required List<Map<String, dynamic>> municipalities,
    required Map<String, String> nameById,
    required _Intent intent,
  }) {
    final buffer = StringBuffer();
    final sources = <String>[];

    if (intent.festival && events.isNotEmpty) {
      buffer.writeln('Approved events across Rizal:');
      for (final e in events.take(5)) {
        final town = nameById[e['municipality_id']] ?? 'Rizal';
        buffer.writeln('• ${_eventLine(e)} — $town');
      }
      sources.add('public.events (status = approved)');
    }

    if (intent.food) {
      final foodPois = pois.where(_isFoodPoi).toList();
      if (foodPois.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln('Food & delicacy spots across Rizal:');
        for (final p in foodPois.take(5)) {
          final town = nameById[p['municipality_id']] ?? 'Rizal';
          buffer.writeln('• ${_poiLine(p)} — $town');
        }
        sources.add('public.pois_logistics (unique foods)');
      }
    }

    if (intent.contact && municipalities.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('Municipal Tourism Coordinator offices:');
      for (final m in municipalities.take(8)) {
        final name = _text(m['name']);
        final office = _text(m['tourism_office_name']).isEmpty
            ? '$name Municipal Tourism Office'
            : _text(m['tourism_office_name']);
        final email = _text(m['coordinator_contact_email']);
        buffer.writeln('• $name — $office${email.isEmpty ? '' : ' ($email)'}');
      }
      sources.add('public.municipalities (tourism office contacts)');
    }

    if (intent.directions) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(
        'Tell me which town you are heading to and I will give the commute '
        'route from the published event and POI guides:',
      );
      final towns = municipalities
          .map((m) => _text(m['name']))
          .where((n) => n.isNotEmpty)
          .toList();
      if (towns.isNotEmpty) buffer.writeln('• ${towns.join(', ')}');
      sources.add('public.municipalities (destinations)');
    }

    if (buffer.isEmpty) return null;
    return RagReply(buffer.toString().trim(), sources: sources);
  }

  // ---- Helpers ------------------------------------------------------------

  Map<String, dynamic>? _matchMunicipality(
    String q,
    List<Map<String, dynamic>> municipalities,
  ) {
    for (final m in municipalities) {
      final name = _normalize(_text(m['name']));
      final slug = _normalize(_text(m['slug']));
      if (name.isEmpty) continue;
      if (q.contains(name) || q.contains(name.replaceAll('-', ' '))) return m;
      if (slug.isNotEmpty && q.contains(slug.replaceAll('-', ' '))) return m;
    }
    return null;
  }

  Map<String, dynamic>? _firstWithRoute(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      if (_text(row['how_to_get_there']).isNotEmpty) return row;
    }
    return null;
  }

  static bool _isFoodPoi(Map<String, dynamic> poi) {
    final type = _text(poi['poi_type']).toLowerCase();
    final name = _text(poi['name']).toLowerCase();
    final description = _text(poi['description']).toLowerCase();
    return type.contains('food') ||
        name.contains('restaurant') ||
        name.contains('food') ||
        name.contains('stall') ||
        description.contains('delicac') ||
        description.contains('cuisine');
  }

  static String _poiLine(Map<String, dynamic> poi) {
    final name = _text(poi['name']);
    final parts = <String>[];
    final address = _text(poi['address']);
    final hours = _text(poi['operating_hours']);
    final fee = _text(poi['entrance_fee']);
    final description = _text(poi['description']);
    if (description.isNotEmpty) parts.add(description);
    if (address.isNotEmpty) parts.add(address);
    if (hours.isNotEmpty) parts.add(hours);
    if (fee.isNotEmpty) parts.add('Fee: $fee');
    return parts.isEmpty ? name : '$name — ${parts.join(' · ')}';
  }

  static String _eventLine(Map<String, dynamic> event) {
    final title = _text(event['title']);
    final venue = _text(event['venue_name']);
    final dates = _eventDates(event);
    final buffer = StringBuffer(title);
    if (venue.isNotEmpty) buffer.write(' at $venue');
    if (dates.isNotEmpty) buffer.write(' ($dates)');
    return buffer.toString();
  }

  static String _eventDates(Map<String, dynamic> event) {
    final start = DateTime.tryParse(_text(event['start_date']));
    final end = DateTime.tryParse(_text(event['end_date']));
    if (start == null) return '';
    if (end == null || _sameDay(start, end)) return _formatDate(start);
    return '${_formatDate(start)} – ${_formatDate(end)}';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, ${date.year}';

  static String _text(dynamic value) => value is String ? value.trim() : '';

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static bool _hasAny(String query, List<String> keys) =>
      keys.any(query.contains);
}

/// Keyword intent parsed from the user's question.
class _Intent {
  final bool festival;
  final bool food;
  final bool directions;
  final bool contact;

  const _Intent({
    required this.festival,
    required this.food,
    required this.directions,
    required this.contact,
  });

  bool get any => festival || food || directions || contact;

  factory _Intent.from(String q) {
    return _Intent(
      festival: SupabaseRagChatService._hasAny(q, const [
        'festival', 'fiesta', 'event', 'celebrat', 'parade', 'higantes',
        'calendar', 'schedule', 'when is',
      ]),
      food: SupabaseRagChatService._hasAny(q, const [
        'food', 'eat', 'restaurant', 'delicac', 'cuisine', 'suman', 'kasuy',
        'bibingka', 'dish', 'kain', 'lutong', 'specialty',
      ]),
      directions: SupabaseRagChatService._hasAny(q, const [
        'how to get', 'how do i get', 'direction', 'commute', 'jeepney', 'bus',
        'uv express', 'tricycle', 'route', 'get there', 'going to', 'travel',
      ]),
      contact: SupabaseRagChatService._hasAny(q, const [
        'coordinator', 'contact', 'email', 'phone', 'call', 'inquir', 'office',
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Offline knowledge base — used when Supabase is not configured, when the
// device is offline, or when live retrieval returns no match.
// ---------------------------------------------------------------------------
class _OfflineEntry {
  final List<String> keywords;
  final String answer;
  final String municipality;
  final List<String> sources;

  const _OfflineEntry({
    required this.keywords,
    required this.answer,
    required this.municipality,
    this.sources = const [],
  });
}

class OfflineRizalKnowledge {
  static const String helpText =
      'I could not find a published record for that yet. Try naming a Rizal '
      'municipality or asking about a festival, local food, how to get there, '
      'or the Tourism Coordinator — for example: "Higantes Festival Angono", '
      '"food in Antipolo", "how to get to Daranak Falls", or '
      '"Binangonan Tourism Coordinator contact".';

  static const List<_OfflineEntry> _entries = [
    _OfflineEntry(
      keywords: ['higantes', 'angono', 'festival'],
      answer:
          'The Higantes Festival is Angono’s iconic cultural celebration held every '
          'November, featuring giant papier-mâché puppets (higantes) paraded through '
          'the streets. It honors the town’s artistic heritage and San Clemente.',
      municipality: 'Angono',
      sources: ['Angono Municipal Tourism Office', 'TuklasRizal curated dataset'],
    ),
    _OfflineEntry(
      keywords: ['petroglyphs', 'binangonan', 'how to get', 'directions'],
      answer:
          'The Binangonan Petroglyphs are ancient rock engravings located in Binangonan, '
          'Rizal, on the lakeshore of Laguna de Bay. From Manila, take the East service '
          'road of Manila East Road toward Binangonan; the site is signposted near the '
          'town proper. Contact the Binangonan Tourism Coordinator for guided tours.',
      municipality: 'Binangonan',
      sources: ['Binangonan Municipal Tourism Office', 'National Museum'],
    ),
    _OfflineEntry(
      keywords: ['tiangge', 'taytay'],
      answer:
          'Taytay’s Tiangge is a weekend marketplace famous for local garments, '
          'fashion finds, and Rizal delicacies. Visit the Taytay Municipal Grounds '
          'on Saturdays and Sundays. The Taytay Tourism Coordinator can provide '
          'stall directories and schedules.',
      municipality: 'Taytay',
      sources: ['Taytay Municipal Tourism Office'],
    ),
    _OfflineEntry(
      keywords: ['coordinator', 'contact', 'angono', 'email'],
      answer:
          'Reach the Angono Municipal Tourism Coordinator at the Angono Municipal '
          'Tourism Office. Email: tourism@angono.gov.ph. They handle inquiries about '
          'Higantes Festival, heritage sites, and local guides.',
      municipality: 'Angono',
      sources: ['Angono Municipal Tourism Office'],
    ),
    _OfflineEntry(
      keywords: ['food', 'restaurant', 'delicacy', 'balaw', 'antipolo', 'suman'],
      answer:
          'Rizal is known for balaw-balaw in Angono, Binangonan lakeshore tilapia and '
          'kinilaw, and Antipolo’s suman, mangoes and kasuy. Ask me about a specific '
          'town for its restaurants and operating hours.',
      municipality: 'Angono',
      sources: ['TuklasRizal curated dataset'],
    ),
    _OfflineEntry(
      keywords: ['daranak', 'tanay', 'falls'],
      answer:
          'Daranak Falls is in Barangay Plaza Aldea, Tanay. Ride a Tanay-bound jeepney '
          'from Shaw Blvd or Cubao to Tanay Public Market, then hire a tricycle to the '
          'falls. The Tanay Tourism Coordinator can confirm operating hours and fees.',
      municipality: 'Tanay',
      sources: ['Tanay Municipal Tourism Office'],
    ),
  ];

  static RagReply answer(String query) {
    final q = query.toLowerCase();
    var bestScore = 0;
    _OfflineEntry? best;
    for (final entry in _entries) {
      var score = 0;
      for (final keyword in entry.keywords) {
        if (q.contains(keyword)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }
    if (best != null) {
      return RagReply(
        best.answer,
        municipality: best.municipality,
        sources: best.sources,
      );
    }
    return const RagReply(helpText);
  }
}

/// Offline-only assistant used when Supabase is not configured.
class MockRagChatService extends _RagChatBase {
  @override
  Future<RagReply> retrieve(String text) async =>
      OfflineRizalKnowledge.answer(text);
}
