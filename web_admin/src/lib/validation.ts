import { describeError } from './supabase';

/** Shared client-side validation + friendly Supabase auth messages. */

export const EMAIL_REQUIRED = 'Email address is required';
export const EMAIL_INVALID =
  'Enter a complete, valid email address (e.g., name@gmail.com)';
export const EMAIL_DISPOSABLE =
  'Please use a real, active email address—disposable or example domains are not allowed.';
export const PASSWORD_INVALID =
  'Password must be at least 8 characters, with 1 uppercase letter, 1 lowercase letter and 1 number.';
export const PASSWORDS_MISMATCH = 'Passwords do not match.';

const BLOCKED_DOMAINS = new Set([
  'example.com',
  'test.com',
  'fake.com',
  'mailinator.com',
  'tempmail.com',
  'yopmail.com',
]);

const EMAIL_PATTERN =
  /^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$/;

export function validateEmail(value: string | null | undefined): string | null {
  const email = (value ?? '').trim();
  if (!email) return EMAIL_REQUIRED;
  if (/\s/.test(email)) return EMAIL_INVALID;
  if ((email.match(/@/g) ?? []).length !== 1) return EMAIL_INVALID;
  const [local, domain = ''] = email.split('@');
  if (!local || !domain || !domain.includes('.')) return EMAIL_INVALID;
  if (!EMAIL_PATTERN.test(email)) return EMAIL_INVALID;
  const tld = domain.split('.').pop() ?? '';
  if (!/^[A-Za-z]{2,}$/.test(tld)) return EMAIL_INVALID;
  if (BLOCKED_DOMAINS.has(domain.toLowerCase())) return EMAIL_DISPOSABLE;
  return null;
}

export interface PasswordRule {
  label: string;
  ok: boolean;
}

export function passwordRules(password: string): PasswordRule[] {
  return [
    { label: 'At least 8 characters', ok: password.length >= 8 },
    { label: '1 uppercase letter', ok: /[A-Z]/.test(password) },
    { label: '1 lowercase letter', ok: /[a-z]/.test(password) },
    { label: '1 number', ok: /[0-9]/.test(password) },
  ];
}

export function validatePassword(password: string): string | null {
  return passwordRules(password).every((rule) => rule.ok) ? null : PASSWORD_INVALID;
}

export function validateConfirmPassword(
  password: string,
  confirm: string,
): string | null {
  if (!confirm) return 'Please confirm your password.';
  return password === confirm ? null : PASSWORDS_MISMATCH;
}

/** HTTP(S) URL check for image / external links. Empty is allowed by default. */
export function validateUrl(value: string | null | undefined, required = false): string | null {
  const url = (value ?? '').trim();
  if (!url) return required ? 'A URL is required.' : null;
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return 'Enter a valid http(s) URL.';
    }
    return null;
  } catch {
    return 'Enter a valid URL (starting with https://).';
  }
}

/** Rizal province bounds, with both-or-neither coordinate pairing. */
export function validateRizalCoordinates(
  latitude: number | null | undefined,
  longitude: number | null | undefined,
): string | null {
  const hasLat = latitude !== null && latitude !== undefined && !Number.isNaN(latitude);
  const hasLng = longitude !== null && longitude !== undefined && !Number.isNaN(longitude);
  if (!hasLat && !hasLng) return null;
  if (!hasLat || !hasLng) return 'Enter both latitude and longitude.';
  if (latitude < 14.1 || latitude > 14.9) return 'Latitude must be within Rizal province (14.1–14.9).';
  if (longitude < 121.0 || longitude > 122.3) {
    return 'Longitude must be within Rizal province (121.0–122.3).';
  }
  return null;
}

export function validateDateRange(start: string, end: string): string | null {
  if (!start || !end) return 'Start date and end date are required.';
  const from = new Date(start);
  const to = new Date(end);
  if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) {
    return 'Enter valid start and end dates.';
  }
  if (to.getTime() < from.getTime()) return 'End date cannot be before start date.';
  return null;
}

/** Maps raw Supabase auth errors to short, actionable sentences. */
export function authErrorMessage(error: unknown): string {
  const code =
    typeof error === 'object' && error && 'code' in error
      ? String((error as { code?: unknown }).code ?? '').toLowerCase()
      : '';
  const message =
    typeof error === 'object' && error && 'message' in error
      ? String((error as { message?: unknown }).message ?? '').toLowerCase()
      : describeError(error).toLowerCase();
  const combined = `${code} ${message}`;

  if (
    combined.includes('over_email_send_rate_limit') ||
    combined.includes('email_send_rate') ||
    combined.includes('rate limit') ||
    combined.includes('too many requests') ||
    code === '429'
  ) {
    return 'Too many verification emails sent in a short time. Please wait a few minutes before trying again.';
  }
  if (combined.includes('email_not_confirmed') || combined.includes('not confirmed')) {
    return 'Please confirm your email address before signing in. Check your inbox for the verification link.';
  }
  if (combined.includes('invalid_credentials') || combined.includes('invalid login credentials')) {
    return 'That email or password is incorrect.';
  }
  if (
    combined.includes('user_already_exists') ||
    combined.includes('email_address_already_in_use') ||
    combined.includes('already registered')
  ) {
    return 'An account already exists with this email. Please sign in instead.';
  }
  if (combined.includes('weak_password')) return PASSWORD_INVALID;
  if (combined.includes('user not found') || combined.includes('signups not allowed')) {
    return 'No account found with this email. Please create an account first.';
  }
  if (
    combined.includes('network') ||
    combined.includes('fetch failed') ||
    combined.includes('timeout') ||
    combined.includes('timed out')
  ) {
    return 'A network problem interrupted the request. Check your connection and try again.';
  }
  return describeError(error);
}
