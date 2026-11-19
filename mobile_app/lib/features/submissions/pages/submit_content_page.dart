import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../services/lookup_service.dart';

/// Submit an event draft or a new place/POI from the phone, with a gallery
/// photo uploaded to `tourism-media`. Events are saved as `draft` so the
/// municipal Tourism Coordinator reviews them in the web admin portal.
class SubmitContentPage extends ConsumerStatefulWidget {
  final String type; // 'event' | 'poi'
  const SubmitContentPage({super.key, required this.type});

  @override
  ConsumerState<SubmitContentPage> createState() => _SubmitContentPageState();
}

class _SubmitContentPageState extends ConsumerState<SubmitContentPage> {
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _directionsCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();

  final _picker = ImagePicker();
  Uint8List? _photoBytes;
  String? _photoName;
  String? _municipalityId;
  String? _categoryId;
  DateTime _start = DateTime.now().add(const Duration(days: 7));
  DateTime _end = DateTime.now().add(const Duration(days: 8));
  bool _saving = false;
  String? _error;

  bool get _isEvent => widget.type == 'event';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _venueCtrl.dispose();
    _directionsCtrl.dispose();
    _hoursCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = ref.watch(lookupsProvider).valueOrNull ?? LookupTables.empty;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEvent ? 'Submit an Event' : 'Submit a Place'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _isEvent
                ? 'Events are submitted as drafts and reviewed by the Municipal '
                    'Tourism Coordinator before they appear publicly.'
                : 'Places and local foods are reviewed by the Municipal Tourism '
                    'Coordinator before publication.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],

          // Gallery photo ----------------------------------------------------
          Text(
            _isEvent ? 'Event photo' : 'Place photo',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _saving ? null : _pickPhoto,
            child: Container(
              height: 170,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0E8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD5E2D2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _photoBytes == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate,
                            size: 40, color: Color(0xFF033300)),
                        SizedBox(height: 8),
                        Text(
                          'Choose a photo from your gallery',
                          style: TextStyle(color: Color(0xFF033300)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'JPEG, PNG or WebP up to 5 MB',
                          style:
                              TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)),
                        ),
                      ],
                    )
                  : Image.memory(_photoBytes!, fit: BoxFit.cover),
            ),
          ),
          if (_photoBytes != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _photoBytes = null;
                          _photoName = null;
                        }),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Remove photo'),
              ),
            ),
          const SizedBox(height: 8),

          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: _isEvent ? 'Event title' : 'Place name',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionCtrl,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _municipalityId,
            decoration: const InputDecoration(labelText: 'Municipality'),
            items: [
              for (final entry in _sorted(labels.municipalityNames))
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _municipalityId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final entry in _sorted(labels.categoryNames))
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _venueCtrl,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: _isEvent ? 'Venue' : 'Address',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _directionsCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'How to Get There (commuting guide)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),

          if (_isEvent) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text('Starts ${dateFormat.format(_start)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: Text('Ends ${dateFormat.format(_end)}'),
                  ),
                ),
              ],
            ),
          ] else ...[
            TextField(
              controller: _hoursCtrl,
              decoration: const InputDecoration(
                labelText: 'Operating hours',
                hintText: '8:00 AM - 5:00 PM (Tue-Sun)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feeCtrl,
              decoration: const InputDecoration(
                labelText: 'Entrance fee',
                hintText: 'Free or PHP 50',
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEvent ? 'Submit event draft' : 'Submit place'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<MapEntry<String, String>> _sorted(Map<String, String> source) {
    final entries = source.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 85,
      );
      if (!mounted || picked == null) return;
      final ext = picked.name.split('.').last.toLowerCase();
      final mime = (picked.mimeType ?? '').toLowerCase();
      const allowedExts = {'jpg', 'jpeg', 'png', 'webp'};
      const allowedMimes = {'image/jpeg', 'image/png', 'image/webp'};
      if (!allowedExts.contains(ext) ||
          (mime.isNotEmpty && !allowedMimes.contains(mime))) {
        setState(() =>
            _error = 'Only JPEG, PNG or WebP images are supported.');
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() => _error = 'Images must be 5 MB or smaller.');
        return;
      }
      setState(() {
        _photoBytes = bytes;
        _photoName = picked.name;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the gallery. Please try again.');
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (!mounted || picked == null) return;
    if (isStart) {
      setState(() {
        _start = picked;
        if (_end.isBefore(_start)) {
          _end = picked.add(const Duration(days: 1));
        }
        _error = null;
      });
      return;
    }
    if (picked.isBefore(_start)) {
      setState(() =>
          _error = 'The end date cannot be earlier than the start date.');
      return;
    }
    setState(() {
      _end = picked;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final signedIn = await requireSignIn(
      context,
      ref,
      action: _isEvent ? 'submit an event' : 'submit a place',
    );
    if (!signedIn || !mounted) return;

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = _isEvent
          ? 'Add an event title.'
          : 'Add the place name.');
      return;
    }
    if (_municipalityId == null || _municipalityId!.isEmpty) {
      setState(() => _error = 'Select the municipality.');
      return;
    }
    if (_categoryId == null || _categoryId!.isEmpty) {
      setState(() => _error = 'Please select a category.');
      return;
    }
    if (_descriptionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Add a description.');
      return;
    }
    if (_venueCtrl.text.trim().isEmpty) {
      setState(() => _error = _isEvent ? 'Add a venue.' : 'Add an address.');
      return;
    }
    if (_isEvent && _end.isBefore(_start)) {
      setState(() =>
          _error = 'The end date cannot be earlier than the start date.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      String? imageUrl;
      if (AppConstants.isSupabaseConfigured && _photoBytes != null) {
        imageUrl = await ref.read(storageServiceProvider).uploadTourismImage(
              bytes: _photoBytes!,
              fileName: _photoName ?? 'photo.jpg',
              folder: _isEvent ? 'events' : 'pois',
            );
        if (!mounted) return;
      }

      if (AppConstants.isSupabaseConfigured) {
        final auth = ref.read(authServiceProvider);
        final verification = auth.unverifiedEmailMessage;
        if (verification != null) {
          await auth.signOutUnconfirmedEmailSession();
          throw Exception(verification);
        }
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user == null) throw Exception('Please sign in again.');

        if (_isEvent) {
          await client.from('events').insert({
            'municipality_id': _municipalityId,
            'category_id': _categoryId,
            'title': title,
            'description': _descriptionCtrl.text.trim().isEmpty
                ? null
                : _descriptionCtrl.text.trim(),
            'venue_name': _venueCtrl.text.trim().isEmpty
                ? null
                : _venueCtrl.text.trim(),
            'how_to_get_there': _directionsCtrl.text.trim().isEmpty
                ? null
                : _directionsCtrl.text.trim(),
            'start_date': _start.toIso8601String(),
            'end_date': _end.toIso8601String(),
            'image_url': imageUrl,
            'status': 'draft',
            'is_featured': false,
            'promotion_weight': 1.0,
            'created_by': user.id,
          });
        } else {
          await client.from('pois_logistics').insert({
            'municipality_id': _municipalityId,
            'category_id': _categoryId,
            'name': title,
            'description': _descriptionCtrl.text.trim().isEmpty
                ? null
                : _descriptionCtrl.text.trim(),
            'poi_type': 'destination',
            'address': _venueCtrl.text.trim().isEmpty
                ? null
                : _venueCtrl.text.trim(),
            'how_to_get_there': _directionsCtrl.text.trim().isEmpty
                ? null
                : _directionsCtrl.text.trim(),
            'operating_hours': _hoursCtrl.text.trim().isEmpty
                ? null
                : _hoursCtrl.text.trim(),
            'entrance_fee': _feeCtrl.text.trim().isEmpty
                ? null
                : _feeCtrl.text.trim(),
            'image_url': imageUrl,
            'is_promoted': false,
          });
        }
      }

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !AppConstants.isSupabaseConfigured
                ? 'Demo mode: your submission was not saved because the '
                    'backend is not configured.'
                : _isEvent
                    ? 'Event submitted! The Tourism Coordinator will review it.'
                    : 'Place submitted! The Tourism Coordinator will review it.',
          ),
          backgroundColor: AppConstants.isSupabaseConfigured
              ? const Color(0xFF033300)
              : Colors.orange,
        ),
      );
      if (context.canPop()) context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'Could not submit right now. Please check your connection and try again.';
      });
    }
  }
}
