import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared input validation + human-readable Supabase auth errors.
///
/// Used by every sign-in, sign-up and profile form so the same rules and the
/// same wording apply on all screens.

const String emailRequiredMessage = 'Email address is required';
const String emailInvalidMessage =
    'Enter a complete, valid email address (e.g., name@gmail.com)';
const String emailDisposableMessage =
    'Please use a real, active email address—disposable or example domains are not allowed.';
const String passwordInvalidMessage =
    'Password must be at least 8 characters, with 1 uppercase letter, '
    '1 lowercase letter and 1 number.';
const String passwordMismatchMessage = 'Passwords do not match.';

/// Shown whenever an email/password session is still awaiting confirmation.
const String emailVerificationRequiredMessage =
    'Please verify your email address from the confirmation link sent to your '
    'inbox before signing in or rating places.';

const Set<String> _blockedEmailDomains = <String>{
  'example.com',
  'test.com',
  'fake.com',
  'mailinator.com',
  'tempmail.com',
  'yopmail.com',
};

final RegExp _emailPattern = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
  r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
  r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
);

/// Returns null when [value] is a usable, non-disposable email address.
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return emailRequiredMessage;
  if (email.contains(RegExp(r'\s'))) return emailInvalidMessage;
  final atCount = '@'.allMatches(email).length;
  if (atCount != 1) return emailInvalidMessage;

  final parts = email.split('@');
  final local = parts[0];
  final domain = parts.length > 1 ? parts[1] : '';
  if (local.isEmpty || domain.isEmpty || !domain.contains('.')) {
    return emailInvalidMessage;
  }
  if (!_emailPattern.hasMatch(email)) return emailInvalidMessage;

  final tld = domain.split('.').last;
  if (!RegExp(r'^[A-Za-z]{2,}$').hasMatch(tld)) return emailInvalidMessage;
  if (_blockedEmailDomains.contains(domain.toLowerCase())) {
    return emailDisposableMessage;
  }
  return null;
}

class PasswordRule {
  final String label;
  final bool satisfied;

  const PasswordRule(this.label, this.satisfied);
}

List<PasswordRule> passwordChecklist(String password) => <PasswordRule>[
      PasswordRule('At least 8 characters', password.length >= 8),
      PasswordRule('1 uppercase letter', password.contains(RegExp(r'[A-Z]'))),
      PasswordRule('1 lowercase letter', password.contains(RegExp(r'[a-z]'))),
      PasswordRule('1 number', password.contains(RegExp(r'[0-9]'))),
    ];

bool isStrongPassword(String password) =>
    passwordChecklist(password).every((rule) => rule.satisfied);

String? validatePassword(String password) =>
    isStrongPassword(password) ? null : passwordInvalidMessage;

String? validateConfirmPassword(String password, String confirm) {
  if (confirm.isEmpty) return 'Please confirm your password.';
  return password == confirm ? null : passwordMismatchMessage;
}

/// Maps raw Supabase / platform errors to short, actionable sentences.
String friendlyAuthError(Object error) {
  final text = error.toString().toLowerCase();
  final code = error is AuthException ? error.statusCode?.toString() ?? '' : '';
  final rawCode = error is AuthException ? error.code?.toLowerCase() ?? '' : '';
  final combined = '$rawCode $text';

  // Preserve the exact verification copy when the service signs out an
  // unconfirmed email session and surfaces this message to the login screen.
  if (combined.contains('verify your email address from the confirmation link')) {
    return emailVerificationRequiredMessage;
  }
  if (combined.contains('over_email_send_rate_limit') ||
      combined.contains('email_send_rate') ||
      combined.contains('rate limit') ||
      combined.contains('too many requests') ||
      code == '429') {
    return 'Too many verification emails sent in a short time. Please wait a '
        'few minutes before trying again.';
  }
  if (combined.contains('email_not_confirmed') ||
      combined.contains('not confirmed') ||
      combined.contains('confirmation')) {
    return 'Please confirm your email address before signing in. Check your '
        'inbox for the verification link.';
  }
  if (combined.contains('invalid_credentials') ||
      combined.contains('invalid login credentials') ||
      combined.contains('invalid email or password')) {
    return 'That email or password is incorrect.';
  }
  if (combined.contains('user_already_exists') ||
      combined.contains('email_address_already_in_use') ||
      combined.contains('already registered') ||
      combined.contains('already exists')) {
    return 'An account already exists with this email. Please sign in instead.';
  }
  if (combined.contains('weak_password') || combined.contains('password should be')) {
    return passwordInvalidMessage;
  }
  if (combined.contains('user not found') ||
      combined.contains('signups not allowed') ||
      combined.contains('no account found')) {
    return 'No account found with this email. Please create an account first.';
  }
  if (combined.contains('network') ||
      combined.contains('socket') ||
      combined.contains('connection') ||
      combined.contains('timed out') ||
      combined.contains('timeout') ||
      combined.contains('failed host')) {
    return 'A network problem interrupted the request. Check your connection '
        'and try again.';
  }
  if (combined.contains('cancel') ||
      combined.contains('popup') ||
      combined.contains('closed') ||
      combined.contains('aborted')) {
    return 'Google sign-in was cancelled. Please try again.';
  }
  if (error is AuthException && error.message.isNotEmpty) return error.message;
  return 'Something went wrong. Please try again.';
}
