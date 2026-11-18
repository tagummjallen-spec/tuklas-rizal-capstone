import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/tourism_images.dart';

/// Uploads tourism gallery photos to the public `tourism-media` bucket.
///
/// Bucket + policies: `supabase/storage_policies.sql`.
abstract class StorageService {
  /// Uploads [bytes] under `tourism-media/<folder>/…` and returns the public URL.
  Future<String> uploadTourismImage({
    required Uint8List bytes,
    required String fileName,
    required String folder,
  });
}

class SupabaseStorageService implements StorageService {
  static const String bucket = 'tourism-media';

  @override
  Future<String> uploadTourismImage({
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    final client = Supabase.instance.client;
    final safeFolder = folder == 'pois' ? 'pois' : 'events';
    final extension = _extensionFor(fileName);
    final path =
        '$safeFolder/${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}.$extension';

    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
            cacheControl: '3600',
          ),
        );

    return client.storage.from(bucket).getPublicUrl(path);
  }

  static String _extensionFor(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return 'jpg';
    final ext = parts.last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      'gif' => 'gif',
      _ => 'jpg',
    };
  }

  static String _randomSuffix() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return micros.toRadixString(36);
  }
}

/// Offline/demo fallback: no bucket is reachable, so the app keeps the bundled
/// Rizal photograph and lets the user continue.
class MockStorageService implements StorageService {
  @override
  Future<String> uploadTourismImage({
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    return TourismImages.higantes;
  }
}
