import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide Light / Dark appearance, persisted on the device.
///
/// `app_theme_mode` stores `'light'` or `'dark'`. The value is intentionally
/// **never** `ThemeMode.system`: a fresh install always opens in crisp Light
/// mode, and only an explicit user choice switches it to Dark.
class ThemeModeController extends ChangeNotifier {
  static const String storageKey = 'app_theme_mode';
  static const String lightValue = 'light';
  static const String darkValue = 'dark';

  ThemeMode _themeMode = ThemeMode.light;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get isLoaded => _loaded;
  bool get isDark => _themeMode == ThemeMode.dark;

  /// Loads the persisted mode before the first frame. Anything other than an
  /// explicit `'dark'` (missing, corrupt, legacy `'system'`) resolves to Light.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _themeMode =
          prefs.getString(storageKey) == darkValue ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      _themeMode = ThemeMode.light;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final next = mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == next) return;
    _themeMode = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        storageKey,
        next == ThemeMode.dark ? darkValue : lightValue,
      );
    } catch (_) {
      // Best-effort persistence; the in-memory choice still applies.
    }
  }

  Future<void> setDark(bool dark) =>
      setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);

  Future<void> toggle() => setDark(!isDark);
}

/// Single shared instance, loaded in `main()` before `runApp`.
final ThemeModeController themeModeController = ThemeModeController();
