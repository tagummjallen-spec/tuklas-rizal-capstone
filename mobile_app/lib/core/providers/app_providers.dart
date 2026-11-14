import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/discovery_service.dart';
import '../../services/geofence_service.dart';
import '../../services/rag_chat_service.dart';
import '../../services/coordinator_service.dart';

/// Central provider declarations so all feature screens share one service instance.
/// Swap mock implementations for Supabase-backed ones when keys are configured.

final authServiceProvider = Provider<AuthService>((ref) => MockAuthService());

final discoveryServiceProvider = Provider<DiscoveryService>((ref) =>
    MockDiscoveryService());

final geofenceServiceProvider = Provider<GeofenceService>((ref) =>
    MockGeofenceService());

final ragChatServiceProvider = Provider<RagChatService>((ref) =>
    MockRagChatService());

final coordinatorServiceProvider = Provider<CoordinatorService>((ref) =>
    MockCoordinatorService());
