import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/app_providers.dart';
import '../../models/event_item.dart';

/// A single row in the Notification Inbox.
///
/// Notifications are derived from live Supabase data — approved events and the
/// LGU "Civic Broadcast:" records created by the Web Admin broadcast action —
/// so nothing here is hard-coded demo copy.
enum AppNotificationKind { civicBroadcast, newEvent, upcomingEvent }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final AppNotificationKind kind;
  final DateTime createdAt;
  final String eventId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    required this.eventId,
  });
}

/// Builds the inbox from the live approved-event stream, newest first.
///
/// - Civic broadcasts are always included (they are LGU announcements).
/// - Events approved in the last 30 days appear as "New event".
/// - Events starting within the next 14 days appear as "Upcoming".
List<AppNotification> buildEventNotifications(List<EventItem> events) {
  final now = DateTime.now();
  final items = <AppNotification>[];

  for (final event in events) {
    final isBroadcast = event.title.startsWith('Civic Broadcast:');
    if (isBroadcast) {
      final headline = event.title.replaceFirst('Civic Broadcast:', '').trim();
      items.add(
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

    final age = now.difference(event.createdAt);
    if (!age.isNegative && age.inDays <= 30) {
      items.add(
        AppNotification(
          id: 'new-${event.id}',
          title: 'New event approved: ${event.title}',
          body: 'A newly approved event is now open in the Rizal Events Hub.',
          kind: AppNotificationKind.newEvent,
          createdAt: event.createdAt,
          eventId: event.id,
        ),
      );
    }

    final daysUntil = event.startDate.difference(now).inDays;
    if (daysUntil >= 0 && daysUntil <= 14) {
      items.add(
        AppNotification(
          id: 'upcoming-${event.id}',
          title: 'Upcoming: ${event.title}',
          body: (event.venueName?.trim().isNotEmpty ?? false)
              ? 'Happening at ${event.venueName!.trim()}.'
              : 'Happening soon in ${event.municipalityId}.',
          kind: AppNotificationKind.upcomingEvent,
          createdAt: event.createdAt,
          eventId: event.id,
        ),
      );
    }
  }

  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items.take(40).toList(growable: false);
}

/// Persists which notification ids the user has already opened.
class NotificationsController extends ChangeNotifier {
  static const String _key = 'tuklas_notifications_read_v1';

  final Set<String> _read = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _read
        ..clear()
        ..addAll(prefs.getStringList(_key) ?? const <String>[]);
    } catch (_) {
      // Storage unavailable: unread state lives for this session only.
    }
    _loaded = true;
    notifyListeners();
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
      controller.load();
      return controller;
    });

/// Inbox contents derived from the live event stream.
final appNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final events = ref.watch(allApprovedEventsProvider).valueOrNull;
  if (events == null) return const <AppNotification>[];
  return buildEventNotifications(events);
});
