import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/input_validation.dart';
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

  /// Google account picker via Supabase OAuth. Returns true when the platform
  /// successfully launched the authorization URL; on mobile the browser
  /// round-trip resolves through [authStateChanges] / [auth-callback].
  Future<bool> signInWithGoogle();

  /// Finishes a Google sign-in once the session is available: upserts the
  /// `public.users` row from Google metadata (email, full name, avatar) and
  /// syncs any interests chosen in the local 4-step welcome onboarding into
  /// `public.user_interests`. Returns null when no session exists yet.
  Future<UserProfile?> completeGoogleSignIn({
    List<String> onboardingInterests = const [],
  });

  /// Confirms the 6-digit signup code sent by email and activates the profile.
  Future<UserProfile> verifySignupOtp(String email, String token);

  /// Re-sends the 6-digit signup code.
  Future<void> resendSignupOtp(String email);

  /// Passwordless sign-in: emails a 6-digit code to an existing account.
  Future<void> sendLoginOtp(String email);

  /// Verifies the emailed sign-in code and returns the profile.
  Future<UserProfile> verifyLoginOtp(String email, String token);

  /// Short self-introduction. `public.users` has no `bio` column, so it lives
  /// in Supabase auth metadata.
  String? get currentBio;

  /// Saves [bio] to auth metadata.
  Future<void> updateBio(String bio);

  /// Creates the `public.users` row for an authenticated user who has none yet
  /// (OAuth first sign-in or a confirmed email signup). Safe to call repeatedly.
  Future<UserProfile?> ensureProfile();

  /// Whether the user already picked tourism interests (first-run onboarding).
  Future<bool> hasSavedInterests(String userId);

  /// The user's saved tourism category ids from `public.user_interests`.
  /// Used to prioritise matching events/POIs in the Home feed.
  Future<List<String>> loadUserInterestCategories(String userId);

  /// Persist the user's selected tourism category ids (USER_INTERESTS).
  Future<void> setUserInterests(String userId, List<String> categoryIds);

  /// Whether the last signUp requires email confirmation before signIn.
  bool get emailConfirmationRequired;

  /// The exact verification message when the active session belongs to an
  /// unconfirmed email/password account; null for guests, verified email
  /// accounts and OAuth accounts.
  String? get unverifiedEmailMessage;

  /// Signs out an unconfirmed email/password session and returns
  /// [unverifiedEmailMessage]. Returns null when no such session is active.
  Future<String?> signOutUnconfirmedEmailSession();
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

  /// Email/password accounts must have a confirmed address before they can
  /// hold a usable session. OAuth (Google) accounts are excluded — their email
  /// is verified by the provider and `app_metadata.provider` is 'google'.
  static String? _verificationMessageFor(User? user) {
    if (user == null) return null;
    if (user.appMetadata['provider'] != 'email') return null;
    if (user.emailConfirmedAt != null) return null;
    return emailVerificationRequiredMessage;
  }

  @override
  String? get unverifiedEmailMessage =>
      _verificationMessageFor(_client.auth.currentUser);

  @override
  Future<String?> signOutUnconfirmedEmailSession() async {
    final message = unverifiedEmailMessage;
    if (message == null) return null;
    await _client.auth.signOut();
    return message;
  }

  @override
  Stream<UserProfile?> get authStateChanges =>
      _client.auth.onAuthStateChange.asyncMap((data) async {
        final user = data.session?.user;
        if (user == null) return null;
        // Any session for an unconfirmed email account is invalid: kill it
        // before a profile can be created or cached anywhere in the app.
        if (_verificationMessageFor(user) != null) {
          await _client.auth.signOut();
          return null;
        }
        final existing = await _fetchProfile(user.id);
        if (existing != null) return existing;
        // First sign-in (usually Google OAuth): create the public.users row.
        return _createProfileFromAuthUser(user);
      });

  /// Creates `public.users` for a first-time OAuth user.
  ///
  /// Google sign-ins are auto-approved. The capstone spec pins
  /// `role_tier = 1`; the title stays "Resident & Tourist" so a tourist is not
  /// presented as barangay staff in the app.
  Future<UserProfile> _createProfileFromAuthUser(User user) async {
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final rawName = meta['full_name'] ?? meta['name'];
    final rawAvatar = meta['avatar_url'] ?? meta['picture'];
    final fullName = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : 'TuklasRizal Guest';
    final avatarUrl = rawAvatar is String && rawAvatar.isNotEmpty
        ? rawAvatar
        : null;
    const roleTier = 1;
    const roleTitle = 'Resident & Tourist';
    final email = user.email ?? '';

    await _upsertProfileRow(
      userId: user.id,
      email: email,
      fullName: fullName,
      avatarUrl: avatarUrl,
      roleTier: roleTier,
      roleTitle: roleTitle,
      isApproved: true,
    );

    return await _fetchProfile(user.id) ??
        UserProfile(
          id: user.id,
          email: email,
          fullName: fullName,
          avatarUrl: avatarUrl,
          roleTier: roleTier,
          roleTitle: roleTitle,
          isApproved: true,
        );
  }

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
      final verification = _verificationMessageFor(response.user);
      if (verification != null) {
        // Never leave a usable session behind for an unverified address.
        await _client.auth.signOut();
        throw Exception(verification);
      }
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
      emailRedirectTo: AppConstants.oauthRedirectUrl,
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
    // A missing session always means sign-in is gated behind confirmation.
    // Never fall through to the dashboard on an unconfirmed signup.
    if (!hasSession) {
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

  @override
  Future<bool> signInWithGoogle() async {
    _emailConfirmationRequired = false;
    // PKCE is configured explicitly in `main.dart` (AuthFlowType.pkce).
    // Web: the bare origin with a trailing slash — no `#/login` or other hash
    // fragment, which would not match the Supabase redirect allowlist.
    // Mobile: the registered deep link that returns to the app.
    // Google on mobile must open in an external browser so the deep link can
    // return to the app; on web stay in this tab for the code exchange.
    final redirectTo = AppConstants.oauthRedirectUrl;
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  @override
  Future<UserProfile?> completeGoogleSignIn({
    List<String> onboardingInterests = const [],
  }) async {
    final profile = await ensureProfile();
    if (profile == null) return null;

    // A guest may have picked interests in the 4-step welcome flow before
    // signing in. Persist them once, without wiping interests already stored.
    if (onboardingInterests.isNotEmpty) {
      final existing = await loadUserInterestCategories(profile.id);
      if (existing.isEmpty) {
        await setUserInterests(profile.id, onboardingInterests);
      }
    }
    return await _fetchProfile(profile.id) ?? profile;
  }

  @override
  Future<UserProfile> verifySignupOtp(String email, String token) async {
    final response = await _client.auth.verifyOTP(
      type: OtpType.signup,
      email: email.trim(),
      token: token.trim(),
    );
    final user = response.user;
    if (user == null) {
      throw Exception(
        'That code is invalid or has expired. Request a new code and try again.',
      );
    }

    final existing = await _fetchProfile(user.id);
    if (existing != null) return existing;

    final meta = user.userMetadata ?? const <String, dynamic>{};
    final rawName = meta['full_name'];
    final fullName = rawName is String && rawName.isNotEmpty ? rawName : 'User';
    final roleTier = UserProfile.parseRoleTier(meta['role_tier']);
    await _upsertProfileRow(
      userId: user.id,
      email: user.email ?? email,
      fullName: fullName,
      roleTier: roleTier,
      isApproved: roleTier < 1,
    );

    return await _fetchProfile(user.id) ??
        UserProfile(
          id: user.id,
          email: user.email ?? email,
          fullName: fullName,
          roleTier: roleTier,
        );
  }

  @override
  Future<void> resendSignupOtp(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: AppConstants.oauthRedirectUrl,
    );
  }

  @override
  Future<void> sendLoginOtp(String email) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      // Never create a half-baked auth user for an unregistered email.
      shouldCreateUser: false,
      emailRedirectTo: AppConstants.oauthRedirectUrl,
    );
  }

  @override
  Future<UserProfile> verifyLoginOtp(String email, String token) async {
    final response = await _client.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim(),
      token: token.trim(),
    );
    final user = response.user;
    if (user == null) {
      throw Exception(
        'That code is invalid or has expired. Request a new code and try again.',
      );
    }
    final existing = await _fetchProfile(user.id);
    if (existing != null) return existing;
    return _createProfileFromAuthUser(user);
  }

  @override
  String? get currentBio {
    final meta = _client.auth.currentUser?.userMetadata;
    final bio = meta?['bio'];
    return bio is String && bio.trim().isNotEmpty ? bio.trim() : null;
  }

  @override
  Future<void> updateBio(String bio) async {
    await _client.auth.updateUser(UserAttributes(data: {'bio': bio.trim()}));
  }

  @override
  Future<bool> hasSavedInterests(String userId) async {
    try {
      final rows = await _client
          .from('user_interests')
          .select('category_id')
          .eq('user_id', userId);
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> loadUserInterestCategories(String userId) async {
    try {
      final rows = await _client
          .from('user_interests')
          .select('category_id')
          .eq('user_id', userId);
      return rows
          .map((row) => row['category_id'] as String?)
          .whereType<String>()
          .toList(growable: false);
    } catch (_) {
      // Offline / schema drift: recommendations fall back to local interests.
      return const [];
    }
  }

  /// True when the current Supabase auth user signed in with Google.
  static bool _isGoogleUser(User user) {
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final appMeta = user.appMetadata;
    final providers = meta['providers'];
    return meta['provider'] == 'google' ||
        appMeta['provider'] == 'google' ||
        (providers is List && providers.contains('google'));
  }

  /// Creates the `public.users` row for a confirmed signup that had no session
  /// at signUp time (email-confirmation flow). For Google OAuth sign-ins the
  /// existing row is topped up with any missing email / full name / avatar so
  /// the profile reflects the provider metadata. Safe to call repeatedly.
  @override
  Future<UserProfile?> ensureProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final existing = await _fetchProfile(user.id);
    final meta = user.userMetadata ?? const <String, dynamic>{};

    final rawAvatar = meta['avatar_url'] ?? meta['picture'];
    final googleAvatar = rawAvatar is String && rawAvatar.isNotEmpty
        ? rawAvatar
        : null;
    final rawName = meta['full_name'] ?? meta['name'];
    final googleName = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : null;

    if (existing != null) {
      final needsSync =
          _isGoogleUser(user) &&
          ((googleAvatar != null && existing.avatarUrl == null) ||
              (googleName != null && existing.fullName == 'User') ||
              (user.email != null && existing.email.isEmpty));
      if (!needsSync) return existing;

      await _upsertProfileRow(
        userId: existing.id,
        email: existing.email.isNotEmpty ? existing.email : user.email ?? '',
        fullName: existing.fullName == 'User'
            ? googleName ?? existing.fullName
            : existing.fullName,
        avatarUrl: existing.avatarUrl ?? googleAvatar,
        roleTier: existing.roleTier,
        roleTitle: existing.roleTitle,
        municipalityId: existing.municipalityId,
        barangayId: existing.barangayId,
        isApproved: existing.isApproved,
      );
      return await _fetchProfile(user.id) ?? existing;
    }

    final roleTier = UserProfile.parseRoleTier(meta['role_tier']);
    final isApproved = roleTier < 1;
    await _upsertProfileRow(
      userId: user.id,
      email: user.email ?? '',
      fullName: googleName ?? 'User',
      avatarUrl: googleAvatar,
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

    await _client
        .from('user_interests')
        .insert(
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
        final mismatch =
            _categorySlugAliases[lowered] ?? _categorySlugAliases[_key(token)];
        final id =
            byKey[lowered] ??
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
    await _client.from('users').upsert({
      'id': userId,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'role_tier': roleTier,
      'role_title': roleTitle ?? UserProfile.roleTitleFor(roleTier),
      'municipality_id': municipalityId,
      'barangay_id': barangayId,
      'is_approved': isApproved,
    }, onConflict: 'id');
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

  // Demo mode never has a real Supabase session, so there is nothing to verify.
  @override
  String? get unverifiedEmailMessage => null;

  @override
  Future<String?> signOutUnconfirmedEmailSession() async => null;

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
    _interests = List<String>.from(categoryIds);
    _interestsSaved = categoryIds.isNotEmpty;
  }

  @override
  Future<bool> signInWithGoogle() async {
    await signIn('demo@tuklasrizal.app', 'google-demo');
    return true;
  }

  @override
  Future<UserProfile?> completeGoogleSignIn({
    List<String> onboardingInterests = const [],
  }) async {
    if (_user == null) await signInWithGoogle();
    if (onboardingInterests.isNotEmpty) {
      await setUserInterests(_user!.id, onboardingInterests);
    }
    return _user;
  }

  @override
  Future<UserProfile> verifySignupOtp(String email, String token) async {
    if (token.trim().length != 6) {
      throw Exception('Enter the 6-digit code from your email.');
    }
    return signUp(email, 'otp-demo', 'Demo Resident');
  }

  @override
  Future<void> resendSignupOtp(String email) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<void> sendLoginOtp(String email) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  String? get currentBio => null;

  @override
  Future<void> updateBio(String bio) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<UserProfile> verifyLoginOtp(String email, String token) async {
    if (token.trim().length != 6) {
      throw Exception('Enter the 6-digit code from your email.');
    }
    return signIn(email, 'otp-demo');
  }

  @override
  Future<UserProfile?> ensureProfile() async => _user;

  @override
  Future<bool> hasSavedInterests(String userId) async => _interestsSaved;

  @override
  Future<List<String>> loadUserInterestCategories(String userId) async =>
      List<String>.from(_interests);

  List<String> _interests = const [];

  bool _interestsSaved = false;
}

/// Converts raw Supabase / platform auth errors into a short, user-friendly
/// sentence suitable for a SnackBar. Used by both Google OAuth and email/OTP
/// screens so cancelled popups and offline errors never surface as stack traces.
String friendlyAuthMessage(Object error) => friendlyAuthError(error);
