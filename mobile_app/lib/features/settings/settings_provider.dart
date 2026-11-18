import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide settings persisted locally with SharedPreferences.
///
/// Text size and high contrast are applied globally in `main.dart`; the three
/// notification switches are read by the Home feed (recommendations) and are
/// available to any notification/reminder integration.
class AppSettingsController extends ChangeNotifier {
  static const String _textScaleKey = 'settings_text_scale_v1';
  static const String _highContrastKey = 'settings_high_contrast_v1';
  static const String _eventRemindersKey = 'settings_event_reminders_v1';
  static const String _newEventsKey = 'settings_new_events_area_v1';
  static const String _recommendationsKey = 'settings_recommendations_v1';

  static const double minTextScale = 0.90;
  static const double maxTextScale = 1.30;
  static const double textScaleStep = 0.05;

  bool _loaded = false;
  double _textScale = 1.0;
  bool _highContrast = false;
  bool _eventReminders = true;
  bool _newEventsInMyArea = true;
  bool _recommendations = true;

  bool get isLoaded => _loaded;
  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  bool get eventReminders => _eventReminders;
  bool get newEventsInMyArea => _newEventsInMyArea;
  bool get recommendationsEnabled => _recommendations;

  /// 90–130, shown as a whole percentage in Settings.
  int get textScalePercent => (_textScale * 100).round();
  bool get canDecreaseText => _textScale > minTextScale + 0.001;
  bool get canIncreaseText => _textScale < maxTextScale - 0.001;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _textScale = (prefs.getDouble(_textScaleKey) ?? 1.0)
          .clamp(minTextScale, maxTextScale)
          .toDouble();
      _highContrast = prefs.getBool(_highContrastKey) ?? false;
      _eventReminders = prefs.getBool(_eventRemindersKey) ?? true;
      _newEventsInMyArea = prefs.getBool(_newEventsKey) ?? true;
      _recommendations = prefs.getBool(_recommendationsKey) ?? true;
    } catch (_) {
      // Storage unavailable: keep the defaults.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> increaseTextScale() =>
      _setTextScale(_textScale + textScaleStep);

  Future<void> decreaseTextScale() =>
      _setTextScale(_textScale - textScaleStep);

  Future<void> resetTextScale() => _setTextScale(1.0);

  Future<void> _setTextScale(double value) async {
    _textScale = value.clamp(minTextScale, maxTextScale).toDouble();
    notifyListeners();
    await _writeDouble(_textScaleKey, _textScale);
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    notifyListeners();
    await _writeBool(_highContrastKey, value);
  }

  Future<void> setEventReminders(bool value) async {
    _eventReminders = value;
    notifyListeners();
    await _writeBool(_eventRemindersKey, value);
  }

  Future<void> setNewEventsInMyArea(bool value) async {
    _newEventsInMyArea = value;
    notifyListeners();
    await _writeBool(_newEventsKey, value);
  }

  Future<void> setRecommendations(bool value) async {
    _recommendations = value;
    notifyListeners();
    await _writeBool(_recommendationsKey, value);
  }

  Future<void> _writeBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  Future<void> _writeDouble(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (_) {
      // Best-effort persistence.
    }
  }
}
