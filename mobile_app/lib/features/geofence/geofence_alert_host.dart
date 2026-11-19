import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../services/geofence_service.dart';
import '../settings/location_consent.dart';

const Color _forest = Color(0xFF033300);
const Color _gold = Color(0xFFFFC800);

/// App-wide host for municipal / heritage arrival banners. It watches the live
/// geofence stream and turns consent on/off without blocking navigation.
class GeofenceAlertHost extends ConsumerStatefulWidget {
  final Widget child;

  const GeofenceAlertHost({super.key, required this.child});

  @override
  ConsumerState<GeofenceAlertHost> createState() => _GeofenceAlertHostState();
}

class _GeofenceAlertHostState extends ConsumerState<GeofenceAlertHost> {
  StreamSubscription<GeofenceEntry>? _subscription;
  Timer? _dismissTimer;
  GeofenceEntry? _entry;
  bool _monitoring = false;

  @override
  void initState() {
    super.initState();
    final geofence = ref.read(geofenceServiceProvider);
    _subscription = geofence.entryEvents.listen(_showBanner);
    if (ref.read(locationConsentProvider).alertsEnabled) {
      _monitoring = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => geofence.startMonitoring());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _showBanner(GeofenceEntry entry) {
    if (!mounted) return;
    _dismissTimer?.cancel();
    setState(() => _entry = entry);
    _dismissTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _entry = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      locationConsentProvider.select((consent) => consent.alertsEnabled),
      (previous, enabled) {
        final geofence = ref.read(geofenceServiceProvider);
        if (enabled && !_monitoring) {
          _monitoring = true;
          geofence.startMonitoring();
        } else if (!enabled && _monitoring) {
          _monitoring = false;
          geofence.stopMonitoring();
          if (mounted) setState(() => _entry = null);
        }
      },
    );

    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_entry != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _WelcomeBanner(
                  entry: _entry!,
                  onDismiss: () {
                    _dismissTimer?.cancel();
                    setState(() => _entry = null);
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final GeofenceEntry entry;
  final VoidCallback onDismiss;

  const _WelcomeBanner({required this.entry, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final poi = entry.isPoi;
    final title = poi
        ? 'Heritage site nearby: ${entry.poiName ?? 'TuklasRizal POI'}'
        : AppConstants.geofenceWelcomeAlertTitle.replaceAll(
            '{municipality}',
            entry.municipality.name,
          );
    final subtitle = poi
        ? '${entry.municipality.name}, Rizal · about '
            '${(entry.distanceMeters ?? 0).round()} m away. '
            'Check the POI entry for verified hours, fees and routes.'
        : (entry.municipality.description?.isNotEmpty ?? false)
            ? entry.municipality.description!
            : 'Discover verified events, heritage sites and local food in '
                '${entry.municipality.name}.';
    final office = entry.municipality.officeName;

    return Material(
      color: _gold,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _forest, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: _forest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                poi ? Icons.account_balance : Icons.location_city,
                color: _gold,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _forest,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _forest,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tourism Coordinator: $office',
                    style: const TextStyle(
                      color: _forest,
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: _forest, size: 18),
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            ),
          ],
        ),
      ),
    );
  }
}
