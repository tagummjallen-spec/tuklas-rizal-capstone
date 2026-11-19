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

  /// Uploads an LGU verification document to the private
  /// `admin-verification-docs` bucket and returns its storage path.
  ///
  /// The bucket is not public: applicants can read their own files and Level 4
  /// admins can read every file (see `supabase/admin_user_approvals.sql`).
  Future<String> uploadVerificationDocument({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String userId,
  });
}

class SupabaseStorageService implements StorageService {
  static const String bucket = 'tourism-media';
  static const String verificationBucket = 'admin-verification-docs';

  @override
  Future<String> uploadTourismImage({
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    final client = Supabase.instance.client;
    final safeFolder = switch (folder) {
      'pois' => 'pois',
      'avatars' => 'avatars',
      _ => 'events',
    };
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

  @override
  Future<String> uploadVerificationDocument({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String userId,
  }) async {
    final client = Supabase.instance.client;
    final extension = _extensionFor(fileName);
    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}.$extension';
    await client.storage.from(verificationBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
            cacheControl: '3600',
          ),
        );
    return path;
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

  @override
  Future<String> uploadVerificationDocument({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String userId,
  }) async {
    return '$userId/demo-${fileName.replaceAll(RegExp(r'\s+'), '-')}';
  }
}
