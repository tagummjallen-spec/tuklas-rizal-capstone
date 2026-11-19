import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';

/// Guests may browse freely; actions that write user-owned rows (RSVP,
/// bookmark, coordinator inquiry) require a session.
///
/// Returns true when a user is signed in. Otherwise it explains why [action]
/// needs an account and routes to `/login` if the guest chooses to sign in.
Future<bool> requireSignIn(
  BuildContext context,
  WidgetRef ref, {
  required String action,
}) async {
  final auth = ref.read(authServiceProvider);

  // An unconfirmed email/password account may still have a live session.
  // Kill it and show the exact verification copy before any write can happen.
  final verification = auth.unverifiedEmailMessage;
  if (verification != null) {
    await auth.signOutUnconfirmedEmailSession();
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify your email'),
        content: Text(verification),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  final user = ref.read(verifiedAuthUserProvider);
  if (user != null) return true;

  final shouldSignIn = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sign in required'),
      content: Text(
        'Sign in to $action. Browsing events, places and the assistant stays '
        'free for guests.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sign in'),
        ),
      ],
    ),
  );

  if (shouldSignIn == true && context.mounted) {
    context.push('/login');
  }
  return false;
}
