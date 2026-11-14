import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

/// Interface for authentication — mockable for offline UI testing.
abstract class AuthService {
  Stream<UserProfile?> get authStateChanges;
  UserProfile? get currentUser;
  Future<UserProfile> signIn(String email, String password);
  /// [categoryIds] are the selected tourism category ids (USER_INTERESTS) saved
  /// during onboarding. Ignored when Supabase is not configured.
  Future<UserProfile> signUp(
    String email,
    String password,
    String fullName, {
    List<String> categoryIds = const [],
  });
  Future<void> signOut();
  Future<void> updateProfile(UserProfile profile);
  /// Persist the user's selected tourism category ids (USER_INTERESTS).
  Future<void> setUserInterests(String userId, List<String> categoryIds);
}

/// ---------------------------------------------------------------------------
/// Production Supabase-backed implementation.
/// Used when AppConstants.isSupabaseConfigured is true.
/// ---------------------------------------------------------------------------
class SupabaseAuthService implements AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Stream<UserProfile?> get authStateChanges =>
      _client.auth.onAuthStateChange.asyncMap((data) async {
        final user = data.session?.user;
        if (user == null) return null;
        return _fetchProfile(user.id);
      });

  @override
  UserProfile? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    // Synchronous getter — return a lightweight profile from auth metadata.
    // The stream (authStateChanges) provides the full DB-backed profile.
    return UserProfile(
      id: user.id.toString(),
      authUserId: user.id.toString(),
      email: user.email ?? '',
      fullName: (user.userMetadata?['full_name'] ?? 'User') as String,
      roleTier: (user.userMetadata?['role_tier'] ?? '0') as String,
    );
  }

  @override
  Future<UserProfile> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) throw Exception('Login failed');
    final profile = await _fetchProfile(response.user!.id);
    if (profile == null) throw Exception('Profile not found');
    return profile;
  }

  @override
  Future<UserProfile> signUp(
    String email,
    String password,
    String fullName, {
    List<String> categoryIds = const [],
  }) async {
    // Mobile residents/tourists default to role_tier '0' (Resident & Tourist).
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role_tier': '0',
      },
    );
    if (response.user == null) throw Exception('Signup failed');

    final userId = response.user!.id;
    // Upsert the profile row into public.users.
    await _upsertProfileRow(
      userId: userId,
      email: email,
      fullName: fullName,
      roleTier: '0',
    );

    // Save selected tourism category ids (USER_INTERESTS) into public.user_interests.
    if (categoryIds.isNotEmpty) {
      await setUserInterests(userId, categoryIds);
    }

    final profile = await _fetchProfile(userId);
    if (profile == null) throw Exception('Profile not found');
    return profile;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    await _upsertProfileRow(
      userId: profile.id,
      email: profile.email,
      fullName: profile.fullName,
      roleTier: profile.roleTier,
      municipalityId: profile.municipalityId,
      barangayId: profile.barangayId,
      phone: profile.phone,
      profileImageUrl: profile.profileImageUrl,
    );
  }

  @override
  Future<void> setUserInterests(String userId, List<String> categoryIds) async {
    // Remove existing interests then re-insert (idempotent upsert behavior).
    await _client.from('user_interests').delete().eq('user_id', userId);
    if (categoryIds.isNotEmpty) {
      await _client.from('user_interests').insert(
        categoryIds
            .map((cid) => {
                  'user_id': userId,
                  'category_id': cid,
                  'created_at': DateTime.now().toIso8601String(),
                })
            .toList(),
      );
    }
  }

  /// Fetch a full DB-backed [UserProfile] from public.users by auth_user_id.
  Future<UserProfile?> _fetchProfile(String authUserId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('auth_user_id', authUserId)
        .maybeSingle();
    if (response == null) return null;
    return UserProfile.fromJson(response);
  }

  /// Insert or update a profile row in public.users.
  Future<void> _upsertProfileRow({
    required String userId,
    required String email,
    required String fullName,
    required String roleTier,
    String? municipalityId,
    String? barangayId,
    String? phone,
    String? profileImageUrl,
  }) async {
    await _client.from('users').upsert({
      'id': userId,
      'auth_user_id': userId,
      'email': email,
      'full_name': fullName,
      'role_tier': roleTier,
      'municipality_id': municipalityId,
      'barangay_id': barangayId,
      'phone': phone,
      'profile_image_url': profileImageUrl,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}

/// ---------------------------------------------------------------------------
/// Mock/stub implementation — automatic fallback when Supabase is NOT configured.
/// ---------------------------------------------------------------------------
class MockAuthService implements AuthService {
  final _controller = StreamController<UserProfile?>.broadcast();
  UserProfile? _user;

  @override
  Stream<UserProfile?> get authStateChanges => _controller.stream;

  @override
  UserProfile? get currentUser => _user;

  @override
  Future<UserProfile> signIn(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    _user = UserProfile(
      id: 'mock-user-1',
      authUserId: 'mock-user-1',
      email: email,
      fullName: 'Demo Resident',
      roleTier: '0',
      municipalityId: 'taytay',
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<UserProfile> signUp(
    String email,
    String password,
    String fullName, {
    List<String> categoryIds = const [],
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    _user = UserProfile(
      id: 'mock-user-1',
      authUserId: 'mock-user-1',
      email: email,
      fullName: fullName,
      roleTier: '0',
      municipalityId: 'taytay',
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    _user = profile;
    _controller.add(profile);
  }

  @override
  Future<void> setUserInterests(String userId, List<String> categoryIds) async {
    // No-op in mock mode.
  }
}
