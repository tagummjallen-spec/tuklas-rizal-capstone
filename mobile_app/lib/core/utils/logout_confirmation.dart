import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';

const Color _forest = Color(0xFF033300);

/// Shows the "are you sure you want to log out?" dialog and signs out when
/// confirmed.
///
/// The sign-out call is wrapped so a network failure surfaces as a snackbar
/// rather than a silent no-op or an unhandled exception.
Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.logout, color: _forest, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Log out?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
        ],
      ),
      content: const Text(
        'Are you sure you want to log out? You can continue browsing as a '
        'guest, but saved sync and RSVPs require an account.',
        style: TextStyle(fontSize: 13.5, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _forest,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const StadiumBorder(),
          ),
          child: const Text('Log Out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(authServiceProvider).signOut();
    if (context.mounted) context.go('/login');
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Could not log out right now. Please check your connection and '
            'try again. ($error)',
          ),
        ),
      );
  }
}
