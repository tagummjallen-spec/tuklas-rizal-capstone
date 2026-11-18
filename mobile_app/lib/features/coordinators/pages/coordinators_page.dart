import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../models/municipality.dart';
import '../../../models/coordinator_inquiry.dart';

/// Municipal Tourism Coordinator Directory & Direct Inquiry.
///
/// The directory is public; sending an inquiry requires a signed-in account.
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
              final email = m.coordinatorContactEmail;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  child: ListTile(
                    leading:
                        const Icon(Icons.business, color: Color(0xFF033300)),
                    title: Text(
                      m.officeName,
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
                          '${m.name}, Rizal',
                          style: const TextStyle(color: Color(0xFF6B6B6B)),
                        ),
                        if (email != null && email.isNotEmpty)
                          Text(
                            email,
                            style: const TextStyle(color: Color(0xFF6B6B6B)),
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      final signedIn = await requireSignIn(
                        context,
                        ref,
                        action:
                            'message the ${m.name} Tourism Coordinator',
                      );
                      if (!signedIn || !context.mounted) return;
                      context.push('/inquiry/${m.id}');
                    },
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

/// Inquiry form — a signed-in user sends an inquiry to a municipality's
/// Tourism Coordinator (`public.coordinator_inquiries`).
class InquiryPage extends ConsumerStatefulWidget {
  final String municipalityId;
  const InquiryPage({super.key, required this.municipalityId});

  @override
  ConsumerState<InquiryPage> createState() => _InquiryPageState();
}

class _InquiryPageState extends ConsumerState<InquiryPage> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Municipality>>(
      stream: ref.read(coordinatorServiceProvider).coordinatorDirectory,
      builder: (context, snap) {
        final match = (snap.data ?? [])
            .where((m) => m.id == widget.municipalityId)
            .toList();
        final municipality = match.isEmpty ? null : match.first;
        final name = municipality?.name ?? widget.municipalityId;
        final office = municipality?.officeName ?? '$name Tourism Office';

        return Scaffold(
          appBar: AppBar(
            title: Text('Inquiry — $name'),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Send a direct inquiry to the $office '
                  '${AppConstants.tourismCoordinatorTitle}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B6B6B),
                  ),
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
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Send Inquiry'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final signedIn = await requireSignIn(
      context,
      ref,
      action: 'send an inquiry to the Tourism Coordinator',
    );
    if (!signedIn || !mounted) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a subject and a message.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final now = DateTime.now();
    try {
      await ref.read(coordinatorServiceProvider).submitInquiry(
            CoordinatorInquiry(
              id: '', // DB-generated UUID; never sent by the app.
              municipalityId: widget.municipalityId,
              userId: user.id,
              subject: subject,
              message: message,
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inquiry sent to Tourism Coordinator.'),
          backgroundColor: Color(0xFF033300),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send inquiry: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
