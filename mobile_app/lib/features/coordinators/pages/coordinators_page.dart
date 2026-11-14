import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../models/municipality.dart';
import '../../../models/coordinator_inquiry.dart';

/// Municipal Tourism Coordinator Directory & Direct Inquiry.
class CoordinatorsPage extends ConsumerWidget {
  const CoordinatorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.tourismCoordinatorDirectory),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Municipality>>(
        stream: ref.read(coordinatorServiceProvider).coordinatorDirectory,
        builder: (context, snap) {
          final municipalities = snap.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: municipalities.length,
            itemBuilder: (_, i) {
              final m = municipalities[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.business, color: Color(0xFF033300)),
                    title: Text(
                      '${m.name} Tourism Office',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Contact: ${m.tourismOfficeContact ?? 'TBD'}',
                          style: const TextStyle(color: Color(0xFF6B6B6B)),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.of(context)
                        .pushNamed('/inquiry/${m.id}'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Inquiry form — user sends a direct inquiry to a municipality's Tourism Coordinator.
class InquiryPage extends ConsumerStatefulWidget {
  final String municipalityId;
  const InquiryPage({super.key, required this.municipalityId});

  @override
  ConsumerState<InquiryPage> createState() => _InquiryPageState();
}

class _InquiryPageState extends ConsumerState<InquiryPage> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final m = const <String, String>{
      'angono': 'Angono',
      'antipolo': 'Antipolo',
      'baras': 'Baras',
      'binangonan': 'Binangonan',
      'cainta': 'Cainta',
      'cardona': 'Cardona',
      'jala_jala': 'Jala-Jala',
      'morong': 'Morong',
      'pililla': 'Pililla',
      'rodriguez': 'Rodriguez',
      'san_mateo': 'San Mateo',
      'tanay': 'Tanay',
      'taytay': 'Taytay',
      'teresa': 'Teresa',
    }[widget.municipalityId] ?? widget.municipalityId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Inquiry — $m Tourism Office'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Send a direct inquiry to the $m ${AppConstants.tourismCoordinatorTitle}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageCtrl,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              keyboardType: TextInputType.multiline,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  await ref.read(coordinatorServiceProvider).submitInquiry(
                        CoordinatorInquiry(
                          id: 'inq-${now.millisecondsSinceEpoch}',
                          municipalityId: widget.municipalityId,
                          userId: 'mock-user-1',
                          subject: _subjectCtrl.text,
                          message: _messageCtrl.text,
                          createdAt: now,
                          updatedAt: now,
                        ),
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Inquiry sent to Tourism Coordinator.'),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Send Inquiry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
