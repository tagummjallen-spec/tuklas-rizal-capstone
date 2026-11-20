import 'package:flutter/material.dart';

import '../../../core/theme/tuklas_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';

/// LGU / Admin access request with document upload.
///
/// Writes the applicant's details and verification document paths to
/// `public.users` (`requested_role_tier`, `requested_municipality`,
/// `department_office`, `official_position`, `contact_number`,
/// `request_reason`, `verification_doc_urls`) and sets the request back to
/// `pending`, where the Level 4 reviewer inspects it in the web admin portal.
///
/// Bucket + policies: `supabase/admin_user_approvals.sql`.
class LguAccessRequestPage extends ConsumerStatefulWidget {
  const LguAccessRequestPage({super.key});

  @override
  ConsumerState<LguAccessRequestPage> createState() =>
      _LguAccessRequestPageState();
}

class _LguAccessRequestPageState extends ConsumerState<LguAccessRequestPage> {
  static const Color forest = Color(0xFF033300);
  static const Color cream = Color(0xFFF7F6F2);
  static const int maxDocs = 3;
  static const int maxDocBytes = 10 * 1024 * 1024;
  static const Set<String> allowedDocExtensions = {
    'pdf', 'jpg', 'jpeg', 'png', 'webp',
  };
  static const Set<String> allowedDocMimeTypes = {
    'application/pdf', 'image/jpeg', 'image/png', 'image/webp',
  };

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _picker = ImagePicker();

  final List<XFile> _docs = [];
  int _tier = 2;
  String? _municipalityId;
  bool _submitting = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _departmentCtrl.dispose();
    _positionCtrl.dispose();
    _contactCtrl.dispose();
    _reasonCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user != null && !_prefilled) {
      _prefilled = true;
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = user.fullName;
      if (user.municipalityId != null &&
          RizalMunicipalities.byId(user.municipalityId!) != null) {
        _municipalityId = user.municipalityId;
      }
    }

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: forest,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'LGU Access Request',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: user == null
          ? _buildSignedOut()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _buildIntro(),
                  const SizedBox(height: 16),
                  _buildApplicantCard(),
                  const SizedBox(height: 14),
                  _buildAssignmentCard(),
                  const SizedBox(height: 14),
                  _buildDocumentsCard(),
                  const SizedBox(height: 14),
                  _buildReasonCard(),
                  const SizedBox(height: 20),
                  _buildSubmit(user.id),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'Reviewed by the Governor / Provincial IT Admin (Level 4).\n'
                      'You will be notified once a decision is recorded.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: Color(0xFF8A8A8A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSignedOut() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F0E5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, color: forest, size: 30),
            ),
            const SizedBox(height: 14),
            const Text(
              'Sign in to request LGU access',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'We need your account to attach the request and verification '
              'documents to your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => context.push('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: forest,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(200, 46),
                shape: const StadiumBorder(),
              ),
              child: const Text('Sign In / Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: forest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user, color: Color(0xFFFFC800), size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apply for LGU / Admin access',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Upload your Official LGU ID, endorsement letter or '
                  'authorization memo so the Provincial IT Admin can verify '
                  'you before granting portal access.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantCard() {
    return _RequestCard(
      title: 'APPLICANT DETAILS',
      children: [
        _label('Full legal name *'),
        TextFormField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Juan Dela Cruz',
          ),
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.length < 3) return 'Enter your full legal name.';
            if (text.split(RegExp(r'\s+')).length < 2) {
              return 'Please include your first and last name.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _label('Government / LGU contact number *'),
        TextFormField(
          controller: _contactCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '0917 123 4567',
          ),
          validator: (value) {
            final digits =
                (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
            if (digits.length < 7) {
              return 'Enter a reachable mobile or landline number.';
            }
            if (digits.length > 13) return 'That number looks too long.';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAssignmentCard() {
    return _RequestCard(
      title: 'REQUESTED ROLE & OFFICE',
      children: [
        _label('Requested role tier *'),
        DropdownButtonFormField<int>(
          initialValue: _tier,
          decoration: const InputDecoration(),
          items: const [
            DropdownMenuItem(
              value: 2,
              child: Text('Tier 2 — Municipal Tourism Coordinator'),
            ),
            DropdownMenuItem(
              value: 3,
              child: Text('Tier 3 — Municipal LGU / IT Admin'),
            ),
            DropdownMenuItem(
              value: 4,
              child: Text('Tier 4 — Provincial Admin'),
            ),
          ],
          onChanged: (value) => setState(() => _tier = value ?? 2),
        ),
        const SizedBox(height: 12),
        _label('Assigned municipality *'),
        DropdownButtonFormField<String>(
          initialValue: _municipalityId,
          isExpanded: true,
          decoration: const InputDecoration(),
          items: [
            for (final municipality in RizalMunicipalities.all)
              DropdownMenuItem(
                value: municipality.id,
                child: Text(municipality.name),
              ),
          ],
          onChanged: (value) => setState(() => _municipalityId = value),
          validator: (value) =>
              value == null ? 'Select the municipality you represent.' : null,
        ),
        const SizedBox(height: 12),
        _label('Department / office name *'),
        TextFormField(
          controller: _departmentCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Municipal Tourism Office',
          ),
          validator: (value) => (value ?? '').trim().length < 3
              ? 'Enter your department or office.'
              : null,
        ),
        const SizedBox(height: 12),
        _label('Official position / designation *'),
        TextFormField(
          controller: _positionCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Tourism Officer II',
          ),
          validator: (value) => (value ?? '').trim().length < 2
              ? 'Enter your official position.'
              : null,
        ),
      ],
    );
  }

  Widget _buildDocumentsCard() {
    return _RequestCard(
      title: 'VERIFICATION DOCUMENTS',
      children: [
        const Text(
          'Attach your Official LGU ID, endorsement letter or authorization '
          'memo. JPG, PNG or WebP, up to 10 MB each, maximum $maxDocs files. '
          'PDF endorsements may be emailed to the Provincial Tourism Office.',
          style: TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF5F5F5F)),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _docs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCFE0CB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined,
                      size: 18, color: forest),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _docs[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove document',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _docs.removeAt(i)),
                  ),
                ],
              ),
            ),
          ),
        if (_docs.length < maxDocs)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : _pickDocument,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(
                _docs.isEmpty ? 'Attach verification document' : 'Add another document',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: forest,
                side: const BorderSide(color: Color(0xFFCFE0CB)),
                minimumSize: const Size.fromHeight(46),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        if (_docs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'At least one document is required before submitting.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFFB3261E)),
            ),
          ),
        const SizedBox(height: 10),
        _label('Document link (optional)'),
        TextFormField(
          controller: _linkCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://drive.google.com/…',
          ),
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) return null;
            final uri = Uri.tryParse(text);
            if (uri == null || !uri.isAbsolute ||
                (uri.scheme != 'http' && uri.scheme != 'https')) {
              return 'Enter a valid http(s) link or leave it blank.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildReasonCard() {
    return _RequestCard(
      title: 'JUSTIFICATION',
      children: [
        TextFormField(
          controller: _reasonCtrl,
          minLines: 4,
          maxLines: 6,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText:
                'Explain your role in municipal tourism and what you will '
                'publish or manage in TuklasRizal.',
          ),
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.length < 20) {
              return 'Please write at least 20 characters of justification.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmit(String userId) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : () => _submit(userId),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, size: 18),
            label: Text(_submitting ? 'Submitting…' : 'Submit access request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: forest,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _submitting ? null : _openEmail,
          icon: const Icon(Icons.mail_outline, size: 16),
          label: const Text('Send documents by email instead'),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B6B6B),
        ),
      ),
    );
  }

  Future<void> _pickDocument() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 88,
      );
      if (!mounted || picked == null) return;
      final ext = picked.name.split('.').last.toLowerCase();
      final mime = (picked.mimeType ?? '').toLowerCase();
      if (!allowedDocExtensions.contains(ext) ||
          (mime.isNotEmpty && !allowedDocMimeTypes.contains(mime))) {
        _snack('Only PDF, JPG, PNG or WebP documents are supported.');
        return;
      }
      final length = await picked.length();
      if (!mounted) return;
      if (length <= 0) {
        _snack('That file is empty. Please choose another document.');
        return;
      }
      if (length > maxDocBytes) {
        _snack('Each document must be 10 MB or smaller.');
        return;
      }
      setState(() => _docs.add(picked));
    } catch (_) {
      _snack('Could not open the file picker. Please try again.');
    }
  }

  Future<void> _submit(String userId) async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_docs.isEmpty) {
      _snack('Attach at least one verification document.');
      return;
    }
    if (!AppConstants.isSupabaseConfigured) {
      _snack('Supabase is not configured, so the request was not sent.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final storage = ref.read(storageServiceProvider);
      final paths = <String>[];
      for (final doc in _docs) {
        final bytes = await doc.readAsBytes();
        if (!mounted) return;
        final path = await storage.uploadVerificationDocument(
          bytes: bytes,
          fileName: doc.name,
          contentType: _contentTypeFor(doc.name),
          userId: userId,
        );
        if (!mounted) return;
        if (path.isNotEmpty) paths.add(path);
      }
      if (paths.isEmpty) {
        if (!mounted) return;
        setState(() => _submitting = false);
        _snack(
          'None of the documents could be uploaded. Please try again or '
          'email them to ${AppConstants.tourismOfficeEmail}.',
        );
        return;
      }
      final link = _linkCtrl.text.trim();
      if (link.isNotEmpty) paths.add(link);

      final municipality =
          RizalMunicipalities.byId(_municipalityId ?? '')?.name ?? '';

      await Supabase.instance.client.from('users').update({
        'full_name': _nameCtrl.text.trim(),
        'requested_role_tier': _tier,
        'requested_municipality': municipality,
        'department_office': _departmentCtrl.text.trim(),
        'official_position': _positionCtrl.text.trim(),
        'contact_number': _contactCtrl.text.trim(),
        'request_reason': _reasonCtrl.text.trim(),
        'verification_doc_urls': paths,
        'approval_status': 'pending',
        'requested_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      if (!mounted) return;
      await _showSubmitted();
      if (!mounted) return;
      setState(() => _submitting = false);
      context.pop();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(
        'Could not save your request (${error.code ?? 'server error'}). '
        'Please try again or email ${AppConstants.tourismOfficeEmail}.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(
        'Could not submit the request. Check your connection and try again.',
      );
    }
  }

  Future<void> _showSubmitted() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Request submitted',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: const Text(
          'The Governor / Provincial IT Admin will inspect your documents and '
          'verify your endorsement. You can keep using TuklasRizal as a guest '
          'while your request is pending.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: forest,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEmail() async {
    // Email is the fallback for documents the device cannot upload (PDFs).
    final name = _nameCtrl.text.trim();
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.tourismOfficeEmail,
      query:
          'subject=LGU%20Access%20Request%3A%20${Uri.encodeComponent(name)}'
          '&body=Hello%20Provincial%20Tourism%20Office%2C%0A%0A'
          'I%20am%20submitting%20my%20LGU%20access%20request%20with%20'
          'attached%20verification%20documents.%0A%0A'
          'Tier%3A%20$_tier%0A'
          'Municipality%3A%20${Uri.encodeComponent(
            RizalMunicipalities.byId(_municipalityId ?? '')?.name ?? '',
          )}%0A'
          'Office%3A%20${Uri.encodeComponent(_departmentCtrl.text.trim())}%0A'
          'Position%3A%20${Uri.encodeComponent(_positionCtrl.text.trim())}%0A'
          'Contact%20number%3A%20${Uri.encodeComponent(_contactCtrl.text.trim())}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      _snack(
        'No email app available. Send your documents to '
        '${AppConstants.tourismOfficeEmail}.',
      );
    }
  }

  static String _contentTypeFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'pdf' => 'application/pdf',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RequestCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _RequestCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: context.tuklasSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF033300),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
