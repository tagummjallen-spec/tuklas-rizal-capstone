import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/discovery_service.dart';
import '../../services/geofence_service.dart';
import '../../services/rag_chat_service.dart';
import '../../services/coordinator_service.dart';
import '../../core/constants/app_constants.dart';

/// Central provider declarations.
///
/// Automatically selects Supabase-backed implementations when
/// `AppConstants.isSupabaseConfigured` is true; otherwise falls back to
/// mock/demo implementations so the app launches immediately without
/// requiring real Supabase credentials.

final authServiceProvider = Provider<AuthService>((ref) {
  if (AppConstants.isSupabaseConfigured) {
    return SupabaseAuthService();
  }
  return MockAuthService();
});

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  if (AppConstants.isSupabaseConfigured) {
    return SupabaseDiscoveryService();
  }
  return MockDiscoveryService();
});

final geofenceServiceProvider = Provider<GeofenceService>((ref) =>
    MockGeofenceService());

final ragChatServiceProvider = Provider<RagChatService>((ref) {
  if (AppConstants.isSupabaseConfigured) {
    // Live retrieval from municipalities / approved events / pois_logistics.
    // Flip `useRemoteLlm` to true once the Llama endpoint is wired up.
    return SupabaseRagChatService(useRemoteLlm: false);
  }
  return MockRagChatService();
});

final coordinatorServiceProvider = Provider<CoordinatorService>((ref) {
  if (AppConstants.isSupabaseConfigured) {
    return SupabaseCoordinatorService();
  }
  return MockCoordinatorService();
});
