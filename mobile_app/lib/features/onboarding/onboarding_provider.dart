import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-first onboarding state for the one-time, four-step welcome flow.
///
/// The flow runs exactly once per device (gated by `has_completed_onboarding`)
/// and persists the guest's selected tourism interests so the Home feed can
/// recommend matching events and POIs immediately — even before the user ever
/// signs in. When the user later signs in or registers, those saved interests
/// are synced to `public.user_interests` in Supabase.
class OnboardingController extends ChangeNotifier {
  static const String _completedKey = 'has_completed_onboarding';
  static const String _interestsKey = 'tuklas_onboarding_interests_v1';

  bool _loaded = false;
  bool _completed = false;
  final List<String> _interests = [];

  bool get isLoading => !_loaded;
  bool get hasCompleted => _completed;
  List<String> get interests => List.unmodifiable(_interests);
  bool get hasInterests => _interests.isNotEmpty;

  /// Loads persisted onboarding state from SharedPreferences.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _completed = prefs.getBool(_completedKey) ?? false;
      _interests
        ..clear()
        ..addAll(prefs.getStringList(_interestsKey) ?? const []);
    } catch (_) {
      // Storage unavailable: start fresh; preferences are best-effort.
    }
    _loaded = true;
    notifyListeners();
  }

  /// Toggles a single onboarding interest and persists immediately.
  Future<void> toggleInterest(String interestId) async {
    if (_interests.contains(interestId)) {
      _interests.remove(interestId);
    } else {
      _interests.add(interestId);
    }
    await _persist();
    notifyListeners();
  }

  /// Replaces the selected interests and persists immediately.
  Future<void> setInterests(Iterable<String> interestIds) async {
    _interests
      ..clear()
      ..addAll(interestIds);
    await _persist();
    notifyListeners();
  }

  /// Clears locally stored interests (e.g. when the user signs out).
  Future<void> clearInterests() async {
    _interests.clear();
    await _persist();
    notifyListeners();
  }

  /// Marks the onboarding flow as completed and persists the flag + interests.
  Future<void> complete() async {
    await _persist();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_completedKey, true);
    } catch (_) {
      // Best-effort local persistence.
    }
    _completed = true;
    notifyListeners();
  }

  /// Replays the welcome guide: clears the completion flag so the router's
  /// redirect sends the app back to the four-step flow.
  Future<void> resetOnboarding() async {
    _completed = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_completedKey, false);
    } catch (_) {
      // Best-effort local persistence.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_interestsKey, _interests);
    } catch (_) {
      // Best-effort local persistence.
    }
  }
}

/// The single app-wide onboarding controller.
///
/// `main.dart` awaits [OnboardingController.load] on this instance before the
/// app starts, so GoRouter's initial redirect can read the persisted
/// `has_completed_onboarding` flag synchronously.
final OnboardingController onboardingController = OnboardingController();
