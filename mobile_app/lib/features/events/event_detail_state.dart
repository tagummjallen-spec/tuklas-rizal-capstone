import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';

/// Stable, deterministic seed so each event shows consistent demo counts.
int seedOf(String id) {
  var hash = 0;
  for (final code in id.codeUnits) {
    hash = (hash * 31 + code) % 100003;
  }
  return hash;
}

/// RSVP state for the `I'm Interested` / `I'm Going` chips.
///
/// The signed-in user's choice is written through to
/// `event_participation` by the detail page (optimistically, never blocking the
/// UI); the aggregate counts are deterministic per event plus the local choice
/// so tapping a chip visibly increments/decrements the counters.
class EventRsvpController extends ChangeNotifier {
  static const String _key = 'tuklas_event_rsvp_v1';

  final Map<String, String> _status = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (key is String && value is String) _status[key] = value;
          });
        }
      }
    } catch (_) {
      // Storage unavailable: keep in-memory state for this session.
    }
    _loaded = true;
    notifyListeners();
  }

  String? statusFor(String eventId) => _status[eventId];

  int goingCount(String eventId) {
    final base = 40 + seedOf(eventId) % 60;
    return base + (statusFor(eventId) == 'going' ? 1 : 0);
  }

  int interestedCount(String eventId) {
    final base = 20 + seedOf(eventId) % 40;
    return base + (statusFor(eventId) == 'interested' ? 1 : 0);
  }

  /// Returns true when the status is now active for this event.
  Future<bool> toggle(String eventId, String status) async {
    final active = _status[eventId] != status;
    if (active) {
      _status[eventId] = status;
    } else {
      _status.remove(eventId);
    }
    notifyListeners();
    await _persist();
    return active;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_status));
    } catch (_) {
      // Best effort — the in-memory value stays correct for this session.
    }
  }
}

/// Heart/like state, persisted locally and mirrored to Supabase when possible.
class EventLikesController extends ChangeNotifier {
  static const String _key = 'tuklas_event_likes_v1';

  final Set<String> _liked = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _liked
        ..clear()
        ..addAll(prefs.getStringList(_key) ?? const []);
    } catch (_) {
      // Storage unavailable.
    }
    _loaded = true;
    notifyListeners();
  }

  bool isLiked(String eventId) => _liked.contains(eventId);

  int hearts(String eventId) {
    final base = 120 + seedOf(eventId) % 220;
    return base + (isLiked(eventId) ? 1 : 0);
  }

  Future<bool> toggle(String eventId) async {
    final liked = !_liked.contains(eventId);
    if (liked) {
      _liked.add(eventId);
    } else {
      _liked.remove(eventId);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _liked.toList());
    } catch (_) {
      // Best effort.
    }
    return liked;
  }

  /// Mirrors the heart to the optional `event_likes` table for signed-in users.
  ///
  /// The local toggle is already applied; a missing table or RLS rejection is
  /// swallowed so the counter never blocks or reverts.
  Future<void> mirrorToSupabase(
    String eventId,
    String userId,
    bool liked,
  ) async {
    if (!AppConstants.isSupabaseConfigured) return;
    try {
      final table = Supabase.instance.client.from('event_likes');
      if (liked) {
        await table.upsert({
          'event_id': eventId,
          'user_id': userId,
        }, onConflict: 'user_id,event_id');
      } else {
        await table.delete().eq('event_id', eventId).eq('user_id', userId);
      }
    } catch (_) {
      // Optional table — the heart still persists on this device.
    }
  }
}

/// A single community review.
class EventReview {
  final String id;
  final String eventId;
  final String author;
  final int rating;
  final String text;
  final DateTime createdAt;

  const EventReview({
    required this.id,
    required this.eventId,
    required this.author,
    required this.rating,
    required this.text,
    required this.createdAt,
  });

  factory EventReview.fromJson(Map<String, dynamic> json) {
    return EventReview(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      author: json['author'] as String? ?? 'Guest Explorer',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      text: json['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'event_id': eventId,
    'author': author,
    'rating': rating,
    'text': text,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Community reviews: seeded demo reviews plus locally persisted user reviews.
///
/// New reviews are also inserted into the optional `event_reviews` Supabase
/// table. If that table is not provisioned the insert is skipped silently and
/// the review still appears immediately from local state.
class EventReviewsController extends ChangeNotifier {
  static const String _key = 'tuklas_event_reviews_v1';
  static const int baseReviewCount = 679;
  static const double baseRating = 4.0;

  final Map<String, List<EventReview>> _reviews = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final raw in prefs.getStringList(_key) ?? const <String>[]) {
        try {
          final review = EventReview.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          if (review.eventId.isEmpty) continue;
          _reviews.putIfAbsent(review.eventId, () => []).add(review);
        } catch (_) {
          // Ignore a single corrupt entry.
        }
      }
    } catch (_) {
      // Storage unavailable.
    }
    _loaded = true;
    notifyListeners();
  }

  List<EventReview> _seed(String eventId) {
    return [
      EventReview(
        id: 'seed-1',
        eventId: eventId,
        author: 'Maria S.',
        rating: 5,
        text:
            'Beautifully organized and very welcoming. The locals made us feel '
            'right at home — worth the trip from Manila!',
        createdAt: DateTime(2026, 10, 18),
      ),
      EventReview(
        id: 'seed-2',
        eventId: eventId,
        author: 'Jose R.',
        rating: 4,
        text:
            'Great food stalls and a lively crowd. Arrive early, parking fills '
            'up fast around the venue.',
        createdAt: DateTime(2026, 10, 12),
      ),
      EventReview(
        id: 'seed-3',
        eventId: eventId,
        author: 'Angela D.',
        rating: 5,
        text:
            'A wonderful showcase of Rizal culture. I brought my family and we '
            'all enjoyed the program.',
        createdAt: DateTime(2026, 10, 4),
      ),
    ];
  }

  List<EventReview> reviewsFor(String eventId) {
    final custom = _reviews[eventId] ?? const <EventReview>[];
    return [...custom, ..._seed(eventId)];
  }

  int reviewCount(String eventId) =>
      baseReviewCount + (_reviews[eventId]?.length ?? 0);

  double averageRating(String eventId) {
    final custom = _reviews[eventId] ?? const <EventReview>[];
    if (custom.isEmpty) return baseRating;
    final total =
        baseRating * baseReviewCount +
        custom.fold<int>(0, (sum, review) => sum + review.rating);
    return total / (baseReviewCount + custom.length);
  }

  Future<void> addReview({
    required String eventId,
    required String author,
    required int rating,
    required String text,
    String? userId,
  }) async {
    // Local-first: the review is persisted before the network write so the UI
    // never depends on the optional `event_reviews` table being provisioned.
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final review = EventReview(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      eventId: eventId,
      author: author.trim().isEmpty ? 'Guest Explorer' : author.trim(),
      rating: rating.clamp(1, 5),
      text: trimmed,
      createdAt: DateTime.now(),
    );
    _reviews.putIfAbsent(eventId, () => []).insert(0, review);
    notifyListeners();
    await _persist();

    if (AppConstants.isSupabaseConfigured) {
      try {
        await Supabase.instance.client.from('event_reviews').insert({
          'event_id': eventId,
          'user_id': userId,
          'author_name': review.author,
          'rating': review.rating,
          'review_text': review.text,
        });
      } catch (_) {
        // The optional reviews table may not be provisioned — the review is
        // already saved on this device.
      }
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = [
        for (final list in _reviews.values) ...[
          for (final review in list) jsonEncode(review.toJson()),
        ],
      ];
      await prefs.setStringList(_key, all);
    } catch (_) {
      // Best effort.
    }
  }
}

final eventRsvpProvider = ChangeNotifierProvider<EventRsvpController>((ref) {
  final controller = EventRsvpController();
  controller.load();
  return controller;
});

final eventLikesProvider = ChangeNotifierProvider<EventLikesController>((ref) {
  final controller = EventLikesController();
  controller.load();
  return controller;
});

final eventReviewsProvider = ChangeNotifierProvider<EventReviewsController>((
  ref,
) {
  final controller = EventReviewsController();
  controller.load();
  return controller;
});
