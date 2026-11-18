import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../models/municipality.dart';
import '../../../models/coordinator_inquiry.dart';

/// Municipal Tourism Coordinator Directory & Direct Inquiry.
///
/// Signed-in tourists also get "My Inquiries & Replies", showing every message
/// they sent and the response posted by the Tourism Coordinator in web_admin.
class CoordinatorsPage extends ConsumerWidget {
  const CoordinatorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(authServiceProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.tourismCoordinatorDirectory),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Municipality>>(
        stream: ref.read(coordinatorServiceProvider).coordinatorDirectory,
        builder: (context, snap) {
          final municipalities = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (user != null) _MyInquiriesCard(userId: user.id),
              if (user != null)
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.upload_file,
                            color: Color(0xFF033300)),
                        title: Text(
                          'Submit content for review',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Send a photo and details; the Tourism Coordinator '
                          'approves them in the LGU portal.',
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.event,
                            color: Color(0xFF033300), size: 20),
                        title: const Text('Submit an event'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/submit/event'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.place,
                            color: Color(0xFF033300), size: 20),
                        title: const Text('Submit a place or local food'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/submit/poi'),
                      ),
                    ],
                  ),
                ),
              if (user == null)
                Card(
                  color: const Color(0xFFFFF4CC),
                  child: ListTile(
                    leading: const Icon(Icons.info_outline,
                        color: Color(0xFF033300)),
                    title: const Text('Sign in to message a Tourism Coordinator'),
                    subtitle: const Text(
                      'The directory is public; sending an inquiry and reading '
                      'replies needs an account.',
                    ),
                    trailing: TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Sign in'),
                    ),
                  ),
                ),
              for (final m in municipalities)
                Padding(
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
                          if (m.coordinatorContactEmail != null &&
                              m.coordinatorContactEmail!.isNotEmpty)
                            Text(
                              m.coordinatorContactEmail!,
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
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The tourist's own inquiries with the Tourism Coordinator's replies.
class _MyInquiriesCard extends ConsumerWidget {
  final String userId;
  const _MyInquiriesCard({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = DateFormat('MMM d, yyyy · h:mm a');
    return StreamBuilder<List<CoordinatorInquiry>>(
      stream: ref.read(coordinatorServiceProvider).getMyInquiries(userId),
      builder: (context, snap) {
        final inquiries = snap.data ?? [];
        final replied =
            inquiries.where((i) => (i.coordinatorReply ?? '').isNotEmpty).length;
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: const Icon(Icons.forum, color: Color(0xFF033300)),
            title: const Text(
              'My Inquiries & Replies',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              inquiries.isEmpty
                  ? 'You have not sent any inquiries yet'
                  : '${inquiries.length} sent · $replied replied',
            ),
            children: [
              if (inquiries.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Open a municipality below to ask its Tourism Coordinator '
                    'about schedules, directions or local delicacies.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
                  ),
                )
              else
                for (final inquiry in inquiries)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F6F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  inquiry.subject,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1B1B1B),
                                  ),
                                ),
                              ),
                              _StatusChip(status: inquiry.status),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatter.format(inquiry.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B6B6B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            inquiry.message,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          if ((inquiry.coordinatorReply ?? '').isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFFC800),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tourism Coordinator reply',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                      color: Color(0xFF7A5A00),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    inquiry.coordinatorReply!,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          else
                            const Text(
                              'Awaiting a reply from the Tourism Coordinator.',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF6B6B6B),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = status.replaceAll('_', ' ');
    final Color background;
    final Color foreground;
    switch (status) {
      case 'resolved':
        background = const Color(0xFFDCEFD9);
        foreground = const Color(0xFF1B5E20);
      case 'in_progress':
        background = const Color(0xFFE3F0FA);
        foreground = const Color(0xFF0D47A1);
      case 'closed':
        background = const Color(0xFFEDEDED);
        foreground = const Color(0xFF5F5F5F);
      default:
        background = const Color(0xFFFFF4CC);
        foreground = const Color(0xFF7A5A00);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
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
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

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
