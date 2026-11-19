import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../services/geofence_service.dart';

/// Geofence Simulator — developer debug toggle to trigger municipal entry
/// alerts without physically visiting each town.
class GeofenceSimulatorPage extends ConsumerStatefulWidget {
  const GeofenceSimulatorPage({super.key});

  @override
  ConsumerState<GeofenceSimulatorPage> createState() => _GeofenceSimulatorPageState();
}

class _GeofenceSimulatorPageState extends ConsumerState<GeofenceSimulatorPage> {
  bool _debugEnabled = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final geofence = ref.read(geofenceServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo: Simulate Town Entry'),
        centerTitle: true,
      ),
      body: StreamBuilder<GeofenceEntry>(
        stream: geofence.entryEvents,
        builder: (context, snap) {
          final entry = snap.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Simulate Geofence Entry',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF033300),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Trigger a live municipal welcome alert to test cultural '
                'banners during the capstone defense — no physical travel '
                'required.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text(AppConstants.geofenceDebugToggleLabel),
                subtitle: const Text('Demo mode for staged entry alerts'),
                value: _debugEnabled,
                activeThumbColor: const Color(0xFF033300),
                onChanged: (v) {
                  setState(() => _debugEnabled = v);
                  geofence.setDebugMode(v);
                },
              ),
              const Divider(),
              const Text(
                'Select a municipality to simulate entry:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...RizalMunicipalities.all.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.location_city,
                          color: Color(0xFF033300)),
                      title: Text(m.name),
                      subtitle: Text(m.tourismOfficeContact),
                      trailing: const Icon(Icons.play_circle,
                          color: Color(0xFFFFC800)),
                      onTap: () async {
                        await geofence.simulateEntry(m.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Simulated entry to ${m.name}'),
                            ),
                          );
                        }
                      },
                    ),
                  )),
              const SizedBox(height: 24),
              if (entry != null) ...[
                Card(
                  color: const Color(0xFFFFC800),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: Color(0xFF033300)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppConstants.geofenceWelcomeAlertTitle.replaceAll(
                                  '{municipality}',
                                  entry.municipality.name,
                                ),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF033300),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(entry.municipality.description ?? ''),
                        const SizedBox(height: 8),
                        Text(
                          'Contact: ${entry.municipality.tourismOfficeName ?? 'TBD'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B6B6B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
