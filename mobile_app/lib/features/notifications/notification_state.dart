import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/app_providers.dart';
import '../../models/coordinator_inquiry.dart';
import '../../models/event_item.dart';

/// A single row in the Notification Inbox.
///
/// Nothing here is auto-generated from historical rows: a signed-in user only
/// sees activity that concerns them — coordinator replies, approvals of their
/// own submissions, reminders for events they saved, and events approved after
/// their account baseline. Guests always see an empty inbox.
enum AppNotificationKind {
  civicBroadcast,
  newEvent,
  upcomingEvent,
  coordinatorReply,
  submissionUpdate,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final AppNotificationKind kind;
  final DateTime createdAt;

  /// Event opened when the row is tapped; null for rows with no detail page
  /// (e.g. a coordinator reply).
  final String? eventId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    this.eventId,
  });
}

/// Test/demo rows that must never reach the inbox.
final RegExp _testRecordPattern = RegExp(
  r'\btest\b|\bshesh\b',
  caseSensitive: false,
);

bool _isTestText(String? value) =>
    value != null && _testRecordPattern.hasMatch(value);

/// Legacy brand copy stored in older rows.
String _brand(String value) =>
    value.replaceAll('Rizal Events Hub', 'TuklasRizal');

const String _appName = 'TuklasRizal';

/// Builds the inbox for [userId].
///
/// Returns an empty list for guests. For signed-in users only relevant rows are
/// produced:
/// - approvals of events the user submitted,
/// - coordinator replies to the user's inquiries,
/// - reminders for events the user saved (next 14 days),
/// - civic broadcasts and newly approved events created after [baseline]
///   (never backfilled from historical rows).
List<AppNotification> buildNotifications({
  required String? userId,
  required DateTime? baseline,
  required List<EventItem> events,
  required List<EventItem> savedEvents,
  required List<CoordinatorInquiry> inquiries,
}) {
  if (userId == null || userId.trim().isEmpty) {
    return const <AppNotification>[];
  }

  final now = DateTime.now();
  final since = baseline ?? now;
  final items = <AppNotification>[];
  final seen = <String>{};

  void add(AppNotification notification) {
    if (!seen.add(notification.id)) return;
    if (_isTestText(notification.title) || _isTestText(notification.body)) {
      return;
    }
    items.add(
      AppNotification(
        id: notification.id,
        title: _brand(notification.title),
        body: _brand(notification.body),
        kind: notification.kind,
        createdAt: notification.createdAt,
        eventId: notification.eventId,
      ),
    );
  }

  for (final event in events) {
    final isOwn = event.createdBy != null && event.createdBy == userId;
    final isBroadcast = event.title.startsWith('Civic Broadcast:');
    final isNew = !event.createdAt.isBefore(since);

    if (isOwn) {
      // Status update on something the user submitted themselves.
      add(
        AppNotification(
          id: 'submission-${event.id}',
          title: 'Your event is now live',
          body:
              '"${event.title}" was approved by the Provincial Tourism Office '
              'and is visible in $_appName.',
          kind: AppNotificationKind.submissionUpdate,
          createdAt: event.updatedAt.isAfter(event.createdAt)
              ? event.updatedAt
              : event.createdAt,
          eventId: event.id,
        ),
      );
      continue;
    }

    if (!isNew) continue;

    if (isBroadcast) {
      final headline = event.title.replaceFirst('Civic Broadcast:', '').trim();
      add(
        AppNotification(
          id: 'broadcast-${event.id}',
          title: headline.isEmpty ? 'Civic broadcast' : headline,
          body: (event.description?.trim().isNotEmpty ?? false)
              ? event.description!.trim()
              : 'An advisory from the Provincial Tourism Office.',
          kind: AppNotificationKind.civicBroadcast,
          createdAt: event.createdAt,
          eventId: event.id,
        ),
      );
      continue;
    }

    add(
      AppNotification(
        id: 'new-${event.id}',
        title: 'New event in Rizal: ${event.title}',
        body: 'A newly approved event is now open in $_appName.',
        kind: AppNotificationKind.newEvent,
        createdAt: event.createdAt,
        eventId: event.id,
      ),
    );
  }

  // Reminders only for events this user actually saved.
  final today = DateTime(now.year, now.month, now.day);
  for (final event in savedEvents) {
    final start = DateTime(
      event.startDate.year,
      event.startDate.month,
      event.startDate.day,
    );
    final daysUntil = start.difference(today).inDays;
    if (daysUntil < 0 || daysUntil > 14) continue;
    add(
      AppNotification(
        id: 'saved-${event.id}',
        title: 'Saved event: ${event.title}',
        body: daysUntil == 0
            ? 'Your saved event starts today'
                  '${(event.venueName?.trim().isNotEmpty ?? false) ? ' at ${event.venueName!.trim()}' : ''}.'
            : daysUntil == 1
            ? 'Your saved event starts tomorrow.'
            : 'Your saved event starts in $daysUntil days.',
        kind: AppNotificationKind.upcomingEvent,
        createdAt: now,
        eventId: event.id,
      ),
    );
  }

  for (final inquiry in inquiries) {
    final reply = inquiry.coordinatorReply?.trim();
    if (reply == null || reply.isEmpty) continue;
    add(
      AppNotification(
        id: 'reply-${inquiry.id}',
        title: 'Tourism Coordinator replied',
        body: inquiry.subject.trim().isEmpty
            ? reply
            : '${inquiry.subject.trim()} — $reply',
        kind: AppNotificationKind.coordinatorReply,
        createdAt: inquiry.updatedAt,
      ),
    );
  }

  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items.take(20).toList(growable: false);
}

/// Persists which notification ids the user has already opened, plus the
/// account baseline timestamp used to suppress historical event backfill.
///
/// State is namespaced per account (`notifications_<userId>` /
/// `notifications_guest`), so a first-time guest or a different account never
/// inherits someone else's read/unread history. Signing out clears the guest
/// namespace back to a fresh empty state.
class NotificationsController extends ChangeNotifier {
  static const String _prefix = 'notifications';
  static const String _baselinePrefix = 'notifications_baseline';
  static const String guestScope = 'guest';

  final Set<String> _read = {};
  String _scope = guestScope;
  bool _loaded = false;
  DateTime? _baseline;

  bool get isLoaded => _loaded;
  String get scope => _scope;

  /// Moment this account first opened the inbox on this device. Events created
  /// before it are never surfaced as "new".
  DateTime? get baseline => _baseline;

  String get _key => '${_prefix}_$_scope';
  String get _baselineKey => '${_baselinePrefix}_$_scope';

  /// Loads the read-state and baseline for [userId] (guest namespace when null).
  Future<void> loadForUser(String? userId) async {
    final next = (userId == null || userId.trim().isEmpty)
        ? guestScope
        : userId.trim();
    if (_scope == next && _loaded) return;

    _scope = next;
    _read.clear();
    _baseline = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      _read.addAll(prefs.getStringList(_key) ?? const <String>[]);
      if (_scope == guestScope) {
        // Guests have no inbox at all — no baseline is needed.
        _baseline = null;
      } else {
        final stored = prefs.getString(_baselineKey);
        var baseline = stored != null ? DateTime.tryParse(stored) : null;
        if (baseline == null) {
          // First time this account opens the inbox: everything already in the
          // database is history, so only later activity can notify them.
          baseline = DateTime.now();
          await prefs.setString(_baselineKey, baseline.toIso8601String());
        }
        _baseline = baseline;
      }
    } catch (_) {
      // Storage unavailable: unread state lives for this session only and the
      // inbox keeps the current account's baseline in memory.
      _baseline = _scope == guestScope ? null : DateTime.now();
    }
    _loaded = true;
    notifyListeners();
  }

  /// Clears the guest namespace so a freshly signed-out (or first-time) guest
  /// starts with a clean, empty inbox.
  Future<void> clearGuestState() async {
    _scope = guestScope;
    final hadState = _read.isNotEmpty;
    _read.clear();
    _baseline = null;
    _loaded = true;
    if (hadState) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_prefix}_$guestScope');
      await prefs.remove('${_baselinePrefix}_$guestScope');
    } catch (_) {
      // Best effort — memory is already empty.
    }
  }

  bool isRead(String id) => _read.contains(id);

  int unreadCount(Iterable<AppNotification> notifications) =>
      notifications.where((n) => !_read.contains(n.id)).length;

  Future<void> markRead(String id) async {
    if (!_read.add(id)) return;
    notifyListeners();
    await _persist();
  }

  Future<void> markAllRead(Iterable<String> ids) async {
    final before = _read.length;
    _read.addAll(ids);
    if (_read.length == before) return;
    notifyListeners();
    await _persist();
  }

  Future<void> clearReadState() async {
    if (_read.isEmpty) return;
    _read.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Best effort.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _read.toList());
    } catch (_) {
      // Best effort — the in-memory set is still correct.
    }
  }
}

/// All approved events, shared by the Home bell badge and the inbox.
final allApprovedEventsProvider = StreamProvider<List<EventItem>>((ref) {
  return ref.watch(discoveryServiceProvider).promoteTownsAndEvents;
});

final notificationsControllerProvider =
    ChangeNotifierProvider<NotificationsController>((ref) {
      final controller = NotificationsController();
      final initial =
          ref.read(authStateProvider).valueOrNull ??
          ref.read(authServiceProvider).currentUser;
      unawaited(controller.loadForUser(initial?.id));

      // Keep read state scoped to whoever is signed in. On sign-out the guest
      // namespace is reset, so the bell badge starts clean.
      ref.listen(authStateProvider, (previous, next) {
        final previousId = previous?.valueOrNull?.id;
        final nextId = next.valueOrNull?.id;
        if (previousId == nextId) return;
        if (nextId == null) {
          unawaited(controller.clearGuestState());
        } else {
          unawaited(controller.loadForUser(nextId));
        }
      });
      return controller;
    });

/// Inbox contents for the signed-in user. Guests always get an empty list, so
/// a first-time guest never sees notifications or a bell badge.
final appNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final user = ref.watch(verifiedAuthUserProvider);
  if (user == null) return const <AppNotification>[];

  final controller = ref.watch(notificationsControllerProvider);
  // The baseline is established asynchronously on first load; watching the
  // controller rebuilds this provider (and empties the inbox until then).
  final events =
      ref.watch(allApprovedEventsProvider).valueOrNull ??
      const <EventItem>[];
  final saved = ref.watch(savedPlacesProvider).savedEvents;
  final inquiries =
      ref.watch(myInquiriesProvider).valueOrNull ??
      const <CoordinatorInquiry>[];

  return buildNotifications(
    userId: user.id,
    baseline: controller.baseline,
    events: events,
    savedEvents: saved,
    inquiries: inquiries,
  );
});
