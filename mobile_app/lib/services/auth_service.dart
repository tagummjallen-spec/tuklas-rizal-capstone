import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

/// Interface for authentication — mockable for offline UI testing.
abstract class AuthService {
  Stream<UserProfile?> get authStateChanges;
  UserProfile? get currentUser;
  Future<UserProfile> signIn(String email, String password);
  Future<UserProfile> signUp(String email, String password, String fullName);
  Future<void> signOut();
  Future<void> updateProfile(UserProfile profile);
}

/// Production Supabase-backed implementation.
class SupabaseAuthService implements AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Stream<UserProfile?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((data) {
        final user = data.session?.user;
        if (user == null) return null;
        return _profileFromUser(user);
      });

  @override
  UserProfile? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _profileFromUser(user);
  }

  @override
  Future<UserProfile> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) throw Exception('Login failed');
    return _profileFromUser(response.user!);
  }

  @override
  Future<UserProfile> signUp(
    String email,
    String password,
    String fullName,
  ) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role_tier': '1'},
    );
    if (response.user == null) throw Exception('Signup failed');
    return _profileFromUser(response.user!);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    await _client.from('users').update(profile.toJson()).eq('id', profile.id);
  }

  UserProfile _profileFromUser(User user) {
    return UserProfile(
      id: user.id.toString(),
      authUserId: user.id.toString(),
      email: user.email ?? '',
      fullName: (user.userMetadata?['full_name'] ?? 'User') as String,
      roleTier: (user.userMetadata?['role_tier'] ?? '1') as String,
    );
  }
}

/// Mock/stub implementation for offline UI testing before Supabase keys are plugged in.
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
      roleTier: '1',
      municipalityId: 'taytay',
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<UserProfile> signUp(
    String email,
    String password,
    String fullName,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    _user = UserProfile(
      id: 'mock-user-1',
      authUserId: 'mock-user-1',
      email: email,
      fullName: fullName,
      roleTier: '1',
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
}
