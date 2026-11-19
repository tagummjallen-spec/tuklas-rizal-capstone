import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_item.dart';
import '../models/poi_logistics.dart';

/// Saved Trips / Bookmarks.
///
/// Persisted on the device with SharedPreferences so guests keep their saves
/// too; signed-in users additionally have their event interest synced to
/// `event_participation` by the card/detail actions.
///
/// Storage is namespaced per account (`saved_events_<userId>` /
/// `saved_events_guest`) so one account never inherits another account's
/// collection. A brand-new guest therefore always starts with **0 saved
/// events**, and signing out resets the guest namespace back to empty.
class SavedPlacesController extends ChangeNotifier {
  static const String _eventsPrefix = 'saved_events';
  static const String _poisPrefix = 'saved_pois';
  static const String guestScope = 'guest';

  final Map<String, EventItem> _events = {};
  final Map<String, PoiLogistics> _pois = {};

  String _scope = guestScope;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  String get scope => _scope;
  List<EventItem> get savedEvents => _events.values.toList(growable: false);
  List<PoiLogistics> get savedPois => _pois.values.toList(growable: false);
  int get totalCount => _events.length + _pois.length;

  String get _eventsKey => '${_eventsPrefix}_$_scope';
  String get _poisKey => '${_poisPrefix}_$_scope';

  bool isEventSaved(String id) => _events.containsKey(id);
  bool isPoiSaved(String id) => _pois.containsKey(id);

  /// Loads the collection for [userId] (or the guest namespace when null/empty).
  ///
  /// Switching accounts clears the in-memory view first, so a signed-in user
  /// never briefly sees the previous account's (or the guest's) bookmarks.
  Future<void> loadForUser(String? userId) async {
    final next = (userId == null || userId.trim().isEmpty)
        ? guestScope
        : userId.trim();
    if (_scope == next && _loaded) return;

    _scope = next;
    _events.clear();
    _pois.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawEvents = prefs.getStringList(_eventsKey) ?? const [];
      for (final raw in rawEvents) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final event = EventItem.fromJson(json);
          _events[event.id] = event;
        } catch (_) {
          // Ignore a single corrupt entry rather than losing every bookmark.
        }
      }
      final rawPois = prefs.getStringList(_poisKey) ?? const [];
      for (final raw in rawPois) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final poi = PoiLogistics.fromJson(json);
          _pois[poi.id] = poi;
        } catch (_) {
          // Same as above.
        }
      }
    } catch (_) {
      // Storage unavailable (e.g. restricted browser): keep in-memory saves.
    }

    _loaded = true;
    notifyListeners();
  }

  /// Clears the guest namespace so a freshly signed-out (or first-time) guest
  /// always starts from an empty collection.
  Future<void> clearGuestState() async {
    _scope = guestScope;
    final hadItems = _events.isNotEmpty || _pois.isNotEmpty;
    _events.clear();
    _pois.clear();
    _loaded = true;
    if (hadItems) notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_eventsPrefix}_$guestScope');
      await prefs.remove('${_poisPrefix}_$guestScope');
    } catch (_) {
      // Best effort — memory is already empty.
    }
  }

  /// Returns true when the event is now saved.
  Future<bool> toggleEvent(EventItem event) async {
    final saved = !_events.containsKey(event.id);
    if (saved) {
      _events[event.id] = event;
    } else {
      _events.remove(event.id);
    }
    notifyListeners();
    await _persistEvents();
    return saved;
  }

  /// Returns true when the place is now saved.
  Future<bool> togglePoi(PoiLogistics poi) async {
    final saved = !_pois.containsKey(poi.id);
    if (saved) {
      _pois[poi.id] = poi;
    } else {
      _pois.remove(poi.id);
    }
    notifyListeners();
    await _persistPois();
    return saved;
  }

  Future<void> clear() async {
    _events.clear();
    _pois.clear();
    notifyListeners();
    await _persistEvents();
    await _persistPois();
  }

  Future<void> _persistEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _eventsKey,
        _events.values.map((event) => jsonEncode(event.toJson())).toList(),
      );
    } catch (_) {
      // Best effort — the in-memory list stays correct for this session.
    }
  }

  Future<void> _persistPois() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _poisKey,
        _pois.values.map((poi) => jsonEncode(poi.toJson())).toList(),
      );
    } catch (_) {
      // Best effort.
    }
  }
}
