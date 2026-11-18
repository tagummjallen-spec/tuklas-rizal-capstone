import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

/// Interface for authentication — mockable for offline UI testing.
abstract class AuthService {
  Stream<UserProfile?> get authStateChanges;
  UserProfile? get currentUser;
  Future<UserProfile> signIn(String email, String password);

  /// [categoryIds] are the selected tourism category ids (USER_INTERESTS) saved
  /// during onboarding. Slugs are resolved to real `categories.id` UUIDs when
  /// Supabase is configured. Ignored when Supabase is not configured.
  ///
  /// Regular residents/tourists are auto-approved (`is_approved = true`).
  /// LGU staff accounts ([isLguStaff] = true) start unapproved
  /// (`is_approved = false`) until their Tourism Coordinator/IT Admin approves.
  Future<UserProfile> signUp(
    String email,
    String password,
    String fullName, {
    List<String> categoryIds = const [],
    bool isLguStaff = false,
    String? municipalityId,
  });
  Future<void> signOut();
  Future<void> updateProfile(UserProfile profile);

  /// Persist the user's selected tourism category ids (USER_INTERESTS).
  Future<void> setUserInterests(String userId, List<String> categoryIds);

  /// Whether the last signUp requires email confirmation before signIn.
  bool get emailConfirmationRequired;
}

/// ---------------------------------------------------------------------------
/// Production Supabase-backed implementation, aligned with the live
/// `public.users` table:
///   id, email, full_name, avatar_url, role_tier, role_title,
///   municipality_id, barangay_id, is_approved.
/// Never write `is_active`, `phone`, `profile_image_url` or `auth_user_id` —
/// those columns do not exist and cause PGRST204.
/// ---------------------------------------------------------------------------
class SupabaseAuthService implements AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Tracks whether the most recent signUp created an unconfirmed user
  /// (email confirmation enabled in the Supabase project).
  bool _emailConfirmationRequired = false;

  /// Old onboarding slugs -> live `categories.slug` values.
  static const Map<String, String> _categorySlugAliases = {
    'cultural': 'cultural-arts',
    'culture': 'cultural-arts',
    'arts': 'cultural-arts',
    'civic': 'civic-community',
    'community': 'civic-community',
    'sports': 'sports-recreation',
    'recreation': 'sports-recreation',
    'eco_tourism': 'eco-tourism',
    'nature': 'eco-tourism',
    'food_heritage': 'food-heritage',
  };

  @override
  bool get emailConfirmationRequired => _emailConfirmationRequired;

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
    // Synchronous getter — lightweight profile from auth metadata. The stream
    // (authStateChanges) provides the full DB-backed profile.
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final fullName = meta['full_name'];
    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      fullName: fullName is String && fullName.isNotEmpty ? fullName : 'User',
      roleTier: UserProfile.parseRoleTier(meta['role_tier']),
      roleTitle: meta['role_title'] as String?,
    );
  }

  @override
  Future<UserProfile> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) throw Exception('Login failed');
      final profile = await _fetchProfile(response.user!.id);
      if (profile == null) {
        throw Exception(
          'Your TuklasRizal profile is missing. Please contact the Provincial '
          'IT Admin or sign up again.',
        );
      }
      return profile;
    } on AuthException catch (e) {
      // Supabase throws AuthException when email is not confirmed.
      if (e.message.toLowerCase().contains('not confirmed') ||
          e.message.toLowerCase().contains('email not confirmed')) {
        throw Exception(
          'Email not confirmed. Please check your inbox for the confirmation link, then sign in.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<UserProfile> signUp(
    String email,
    String password,
    String fullName, {
    List<String> categoryIds = const [],
    bool isLguStaff = false,
    String? municipalityId,
  }) async {
    // Reset the confirmation flag before each signup attempt.
    _emailConfirmationRequired = false;

    // Mobile residents/tourists default to role_tier 0; LGU staff to tier 2
    // (Tourism Coordinator / Department Head). role_tier is an integer column.
    final roleTier = isLguStaff ? 2 : 0;
    final roleTitle = UserProfile.roleTitleFor(roleTier);
    final isApproved = !isLguStaff;

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role_tier': roleTier,
        'role_title': roleTitle,
      },
    );
    if (response.user == null) throw Exception('Signup failed');

    final authUser = response.user!;
    final hasSession = response.session != null;

    // Supabase email confirmation:
    // - ENABLED: the user exists but has no session yet, so the profile row
    //   cannot be written under RLS until they confirm and sign in.
    // - DISABLED: a session exists and the profile is written immediately.
    if (!hasSession && authUser.emailConfirmedAt == null) {
      _emailConfirmationRequired = true;
    }

    if (hasSession) {
      // Upsert the profile row into public.users (exact live columns only).
      await _upsertProfileRow(
        userId: authUser.id,
        email: email,
        fullName: fullName,
        roleTier: roleTier,
        roleTitle: roleTitle,
        municipalityId: municipalityId,
        isApproved: isApproved,
      );

      // Save selected tourism category ids into public.user_interests.
      if (categoryIds.isNotEmpty) {
        await setUserInterests(authUser.id, categoryIds);
      }

      final profile = await _fetchProfile(authUser.id);
      if (profile != null) return profile;
    }

    // Unconfirmed signup: return the local profile; the DB row is created on
    // the first authenticated session (see ensureProfile).
    return UserProfile(
      id: authUser.id,
      email: email,
      fullName: fullName,
      roleTier: roleTier,
      roleTitle: roleTitle,
      municipalityId: municipalityId,
      isApproved: isApproved,
    );
  }

  /// Creates the `public.users` row for a confirmed signup that had no session
  /// at signUp time (email-confirmation flow). Safe to call repeatedly.
  Future<UserProfile?> ensureProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final existing = await _fetchProfile(user.id);
    if (existing != null) return existing;

    final meta = user.userMetadata ?? const <String, dynamic>{};
    final fullName = meta['full_name'];
    final roleTier = UserProfile.parseRoleTier(meta['role_tier']);
    final isApproved = roleTier < 1;
    await _upsertProfileRow(
      userId: user.id,
      email: user.email ?? '',
      fullName: fullName is String && fullName.isNotEmpty ? fullName : 'User',
      roleTier: roleTier,
      isApproved: isApproved,
    );
    return _fetchProfile(user.id);
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
      avatarUrl: profile.avatarUrl,
      roleTier: profile.roleTier,
      roleTitle: profile.roleTitle,
      municipalityId: profile.municipalityId,
      barangayId: profile.barangayId,
      isApproved: profile.isApproved,
    );
  }

  @override
  Future<void> setUserInterests(String userId, List<String> categoryIds) async {
    // Remove existing interests then re-insert (idempotent upsert behavior).
    await _client.from('user_interests').delete().eq('user_id', userId);
    if (categoryIds.isEmpty) return;

    final ids = await _resolveCategoryIds(categoryIds);
    if (ids.isEmpty) return;

    await _client.from('user_interests').insert(
          ids.map((id) => {'user_id': userId, 'category_id': id}).toList(),
        );
  }

  /// Map onboarding slugs/names to real `public.categories.id` UUIDs so
  /// `user_interests.category_id` satisfies its foreign key.
  Future<List<String>> _resolveCategoryIds(List<String> raw) async {
    try {
      final rows = await _client.from('categories').select('id,slug,name');
      final byKey = <String, String>{};
      final validIds = <String>{};
      for (final row in rows) {
        final id = row['id'] as String;
        validIds.add(id);
        final slug = (row['slug'] as String? ?? '');
        final name = (row['name'] as String? ?? '');
        if (slug.isNotEmpty) byKey[slug.toLowerCase()] = id;
        if (name.isNotEmpty) byKey[name.toLowerCase()] = id;
        byKey[_key(slug)] = id;
        byKey[_key(name)] = id;
      }

      final resolved = <String>[];
      for (final token in raw) {
        final lowered = token.toLowerCase();
        final mismatch = _categorySlugAliases[lowered] ?? _categorySlugAliases[_key(token)];
        final id = byKey[lowered] ??
            byKey[_key(token)] ??
            (mismatch != null ? byKey[mismatch] : null) ??
            (validIds.contains(token) ? token : null);
        if (id != null && !resolved.contains(id)) resolved.add(id);
      }
      return resolved;
    } catch (_) {
      // Offline / schema drift: never block signup on interest persistence.
      return const [];
    }
  }

  static String _key(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Fetch a full DB-backed [UserProfile] from public.users by id.
  /// `public.users.id` is the auth user UUID on the live project.
  Future<UserProfile?> _fetchProfile(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (response == null) return null;
    return UserProfile.fromJson(response);
  }

  /// Insert or update a profile row in public.users using only live columns.
  Future<void> _upsertProfileRow({
    required String userId,
    required String email,
    required String fullName,
    String? avatarUrl,
    int roleTier = 0,
    String? roleTitle,
    String? municipalityId,
    String? barangayId,
    bool isApproved = true,
  }) async {
    await _client.from('users').upsert(
      {
        'id': userId,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'role_tier': roleTier,
        'role_title': roleTitle ?? UserProfile.roleTitleFor(roleTier),
        'municipality_id': municipalityId,
        'barangay_id': barangayId,
        'is_approved': isApproved,
      },
      onConflict: 'id',
    );
  }
}

/// ---------------------------------------------------------------------------
/// Mock/stub implementation — automatic fallback when Supabase is NOT configured.
/// ---------------------------------------------------------------------------
class MockAuthService implements AuthService {
  final _controller = StreamController<UserProfile?>.broadcast();
  UserProfile? _user;

  @override
  bool get emailConfirmationRequired => false;

  @override
  Stream<UserProfile?> get authStateChanges => _controller.stream;

  @override
  UserProfile? get currentUser => _user;

  @override
  Future<UserProfile> signIn(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    _user = UserProfile(
      id: 'mock-user-1',
      email: email,
      fullName: 'Demo Resident',
      roleTier: 0,
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
    bool isLguStaff = false,
    String? municipalityId,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    _user = UserProfile(
      id: 'mock-user-1',
      email: email,
      fullName: fullName,
      roleTier: isLguStaff ? 2 : 0,
      municipalityId: municipalityId ?? 'taytay',
      isApproved: !isLguStaff,
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
