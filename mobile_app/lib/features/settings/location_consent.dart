import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted RA 10173 consent for on-device municipal geofencing.
class LocationConsentController extends ChangeNotifier {
  static const String _noticeKey = 'tuklas_location_dpa_notice_accepted_v1';
  static const String _enabledKey = 'tuklas_location_alerts_enabled_v1';

  bool dpaNoticeAccepted = false;
  bool alertsEnabled = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      dpaNoticeAccepted = prefs.getBool(_noticeKey) ?? false;
      alertsEnabled =
          (prefs.getBool(_enabledKey) ?? false) && dpaNoticeAccepted;
    } catch (_) {
      dpaNoticeAccepted = false;
      alertsEnabled = false;
    }
    notifyListeners();
  }

  Future<void> acceptNotice() async {
    dpaNoticeAccepted = true;
    notifyListeners();
    await _persist();
  }

  Future<void> setEnabled(bool enabled) async {
    alertsEnabled = enabled && dpaNoticeAccepted;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_noticeKey, dpaNoticeAccepted);
      await prefs.setBool(_enabledKey, alertsEnabled);
    } catch (_) {
      // Consent still applies for this session when storage is unavailable.
    }
  }
}

/// Single controller instance shared by the startup bootstrap and the widget
/// tree, mirroring the onboarding controller pattern.
final locationConsentController = LocationConsentController();

final locationConsentProvider =
    ChangeNotifierProvider<LocationConsentController>((ref) {
  return locationConsentController;
});

/// Clear Data Privacy Act disclosure shown BEFORE the OS location prompt.
/// Returns true only when the visitor explicitly agrees.
Future<bool> showLocationPrivacyDialog(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      title: const Row(
        children: [
          Icon(Icons.privacy_tip_outlined, color: Color(0xFF033300), size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your Location, Your Choice',
              style: TextStyle(
                color: Color(0xFF033300),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Data Privacy Act (RA 10173) Notice',
              style: TextStyle(
                color: Color(0xFF033300),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'If you enable Municipal Cultural Alerts, TuklasRizal checks your '
              'GPS coordinates on your device against the 14 Rizal municipality '
              'centres and the registered heritage/POI list. This happens '
              'locally to trigger a cultural welcome banner when you enter a '
              'town or approach a heritage site.',
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
            SizedBox(height: 10),
            Text(
              'Your coordinates are not uploaded by this app, are not sold, '
              'rented or shared with third parties, and are not used to build '
              'a tracking profile. You may turn alerts off at any time in '
              'Settings. Your device OS still controls the location permission.',
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(
            'Not now',
            style: TextStyle(color: Color(0xFF6B6B6B)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC800),
            foregroundColor: const Color(0xFF033300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(
            'Agree & Enable',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
  return accepted ?? false;
}
