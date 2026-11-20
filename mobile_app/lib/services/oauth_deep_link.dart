import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';

/// Scheme/host registered in `AndroidManifest.xml` (and Info.plist on iOS) for
/// the Google OAuth return leg.
const String oauthDeepLinkScheme = 'io.supabase.tuklasrizal';
const String oauthDeepLinkHost = 'login-callback';
const String oauthDeepLinkUrl = '$oauthDeepLinkScheme://$oauthDeepLinkHost';

StreamSubscription<Uri>? _subscription;

/// True when [uri] is the app's OAuth callback rather than an unrelated link.
bool isOAuthCallbackUri(Uri uri) =>
    uri.scheme == oauthDeepLinkScheme && uri.host == oauthDeepLinkHost;

/// Exchanges the authorization code carried by the deep link for a session.
///
/// PKCE is enabled globally (see `main.dart`), so `getSessionFromUrl` completes
/// the code exchange with the verifier stored on device. Once the session is
/// live, `Supabase.auth.onAuthStateChange` emits `signedIn`, the auth service
/// loads or creates the `public.users` row (defaulting to `resident`), and the
/// router leaves the sign-in screen — no Web Admin hop.
Future<void> handleOAuthDeepLink(Uri uri) async {
  if (!isOAuthCallbackUri(uri)) return;
  final auth = Supabase.instance.client.auth;
  // Replays (e.g. the link is opened twice) must not overwrite a live session.
  if (auth.currentSession != null) return;
  try {
    await auth.getSessionFromUrl(uri);
  } on AuthException catch (error) {
    // Expired/reused codes and cancelled consents are expected; stay signed out.
    debugPrint('Google sign-in deep link rejected: ${error.message}');
  } catch (error) {
    debugPrint('Google sign-in deep link could not be completed: $error');
  }
}

/// Starts listening for the OAuth deep link, including the cold-start link that
/// launched the app. No-op on web (the browser returns to the origin instead)
/// and in mock/demo mode where Supabase is not configured.
Future<void> listenForOAuthDeepLinks() async {
  if (kIsWeb || !AppConstants.isSupabaseConfigured) return;
  if (_subscription != null) return;

  final links = AppLinks();
  try {
    final initial = await links.getInitialLink();
    if (initial != null) unawaited(handleOAuthDeepLink(initial));
  } catch (error) {
    debugPrint('Could not read initial deep link: $error');
  }
  _subscription = links.uriLinkStream.listen(
    (uri) => unawaited(handleOAuthDeepLink(uri)),
    onError: (Object error) => debugPrint('Deep link stream error: $error'),
  );
}

/// Stops listening (used by tests and hot restarts).
Future<void> stopOAuthDeepLinkListener() async {
  await _subscription?.cancel();
  _subscription = null;
}
