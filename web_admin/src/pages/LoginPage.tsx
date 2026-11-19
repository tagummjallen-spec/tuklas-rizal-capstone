import { useMemo, useState } from 'react';
import type { FormEvent } from 'react';
import { Icon } from '../components/Icon';
import { Alert, Button, Field, Input, Select } from '../components/ui';
import { useAuth } from '../context/AuthContext';
import { roleTitleFor } from '../lib/rbac';
import {
  authErrorMessage,
  passwordRules,
  validateConfirmPassword,
  validateEmail,
  validatePassword,
} from '../lib/validation';
import type { Barangay, Municipality } from '../types';

interface LoginPageProps {
  municipalities: Municipality[];
  barangays: Barangay[];
}

type Mode = 'signin' | 'register';
type SignInMode = 'password' | 'otp';

const REGISTRATION_TIERS = [1, 2, 3];

/** Live password-requirements list; each satisfied rule turns green. */
function PasswordChecklist({ password }: { password: string }) {
  return (
    <ul className="mt-1 space-y-0.5">
      {passwordRules(password).map((rule) => (
        <li
          key={rule.label}
          className={`flex items-center gap-1.5 text-[11px] ${
            rule.ok ? 'font-semibold text-green-700' : 'text-slate-400'
          }`}
        >
          {rule.ok ? (
            <Icon name="check" className="h-3 w-3" />
          ) : (
            <span className="inline-block h-2 w-2 rounded-full border border-slate-300" />
          )}
          {rule.label}
        </li>
      ))}
    </ul>
  );
}

/** Standard four-colour Google mark, used on the OAuth sign-in button. */
function GoogleGlyph() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
      <path
        fill="#4285F4"
        d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.27-4.74 3.27-8.1Z"
      />
      <path
        fill="#34A853"
        d="M12 23c2.97 0 5.46-.98 7.28-2.65l-3.57-2.77c-.99.66-2.26 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84A11 11 0 0 0 12 23Z"
      />
      <path
        fill="#FBBC05"
        d="M5.84 14.11a6.6 6.6 0 0 1 0-4.22V7.05H2.18a11 11 0 0 0 0 9.9l3.66-2.84Z"
      />
      <path
        fill="#EA4335"
        d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1A11 11 0 0 0 2.18 7.05l3.66 2.84c.87-2.6 3.3-4.51 6.16-4.51Z"
      />
    </svg>
  );
}

export default function LoginPage({ municipalities, barangays }: LoginPageProps) {
  const { signIn, sendLoginOtp, verifyLoginOtp, signInWithGoogle, signUp } = useAuth();
  const [mode, setMode] = useState<Mode>('signin');
  // Email & Password is shown immediately by default.
  const [signInMode, setSignInMode] = useState<SignInMode>('password');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [otpToken, setOtpToken] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [fullName, setFullName] = useState('');
  const [roleTier, setRoleTier] = useState(2);
  const [municipalityId, setMunicipalityId] = useState('');
  const [barangayId, setBarangayId] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [emailError, setEmailError] = useState<string | null>(null);
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [confirmError, setConfirmError] = useState<string | null>(null);
  const [nameError, setNameError] = useState<string | null>(null);
  const [otpError, setOtpError] = useState<string | null>(null);

  const municipalityBarangays = useMemo(
    () => barangays.filter((barangay) => barangay.municipality_id === municipalityId),
    [barangays, municipalityId],
  );

  const resetMessages = () => {
    setError(null);
    setNotice(null);
  };

  const changeEmail = (value: string) => {
    setEmail(value);
    if (emailError || value) setEmailError(validateEmail(value));
  };

  const handleSignIn = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (busy) return;
    resetMessages();

    const emailProblem = validateEmail(email);
    const passwordProblem = password ? null : 'Password is required';
    setEmailError(emailProblem);
    setPasswordError(passwordProblem);
    if (emailProblem || passwordProblem) return;

    setBusy(true);
    try {
      await signIn(email.trim(), password);
    } catch (caught) {
      setError(authErrorMessage(caught));
    } finally {
      setBusy(false);
    }
  };

  const handleSendOtp = async (event?: FormEvent<HTMLFormElement>) => {
    event?.preventDefault();
    if (busy) return;
    resetMessages();

    const emailProblem = validateEmail(email);
    setEmailError(emailProblem);
    if (emailProblem) return;

    setBusy(true);
    try {
      await sendLoginOtp(email.trim());
      setOtpSent(true);
      setOtpToken('');
      setNotice(
        'If an account exists for this email, a sign-in link / 6-digit code is on its way. Check your real inbox.',
      );
    } catch (caught) {
      setError(authErrorMessage(caught));
    } finally {
      setBusy(false);
    }
  };

  const handleVerifyOtp = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (busy) return;
    resetMessages();

    const code = otpToken.trim();
    if (!/^\d{6}$/.test(code)) {
      setOtpError('Enter the 6-digit code from your email.');
      return;
    }
    setOtpError(null);

    setBusy(true);
    try {
      // A successful verification establishes a session; AuthContext then
      // loads the LGU profile and the app routes to the correct gate.
      await verifyLoginOtp(email.trim(), code);
    } catch (caught) {
      setError(authErrorMessage(caught));
    } finally {
      setBusy(false);
    }
  };

  const switchSignInMode = (next: SignInMode) => {
    setSignInMode(next);
    setOtpSent(false);
    setOtpToken('');
    setOtpError(null);
    setPasswordError(null);
    resetMessages();
  };

  const handleGoogleSignIn = async () => {
    if (busy) return;
    resetMessages();
    setBusy(true);
    try {
      // Supabase redirects back to ${window.location.origin}/. On return,
      // AuthContext verifies public.users role_tier + approval before the
      // dashboard / pending-access gate is applied.
      await signInWithGoogle();
    } catch (caught) {
      setError(authErrorMessage(caught));
      setBusy(false);
    }
  };

  const handleRegister = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (busy) return;
    resetMessages();

    const nameProblem = fullName.trim() ? null : 'Please enter your full name.';
    const emailProblem = validateEmail(email);
    const passwordProblem = validatePassword(password);
    const confirmProblem = validateConfirmPassword(password, confirmPassword);
    setNameError(nameProblem);
    setEmailError(emailProblem);
    setPasswordError(passwordProblem);
    setConfirmError(confirmProblem);

    if (nameProblem || emailProblem || passwordProblem || confirmProblem) return;
    if (!municipalityId) return setError('Please select your municipality.');
    if (roleTier === 1 && !barangayId) {
      return setError('Barangay Officials must select their barangay.');
    }
    if (!REGISTRATION_TIERS.includes(roleTier)) {
      return setError('Please select a valid LGU role.');
    }

    setBusy(true);
    try {
      const { needsConfirmation } = await signUp({
        email,
        password,
        fullName,
        roleTier,
        municipalityId,
        barangayId: barangayId || null,
      });

      if (needsConfirmation) {
        setMode('signin');
        setPassword('');
        setConfirmPassword('');
        setNotice(
          'Check your real inbox and follow the verification link to confirm your email address before signing in. A Provincial Admin must then approve your LGU account before portal access is granted.',
        );
      }
    } catch (caught) {
      setError(authErrorMessage(caught));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="grid min-h-screen lg:grid-cols-[1.05fr_1fr]">
      <section className="relative hidden flex-col justify-between bg-forest px-12 py-14 text-white lg:flex">
        <div>
          <div className="flex items-center gap-3">
            <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gold text-forest">
              <Icon name="pois" className="h-6 w-6" />
            </span>
            <div>
              <p className="text-xl font-bold leading-tight">TuklasRizal</p>
              <p className="text-[11px] uppercase tracking-[0.2em] text-white/60">
                LGU Web Admin Portal
              </p>
            </div>
          </div>

          <h1 className="mt-14 max-w-lg text-4xl font-bold leading-tight">
            Promote Towns and Events across the Province of Rizal.
          </h1>
          <p className="mt-4 max-w-md text-sm leading-relaxed text-white/70">
            One portal for Barangay Officials, Tourism Coordinators, Mayors and the
            Provincial IT Admin to publish cultural events, manage heritage sites and
            local foods, and respond to tourist inquiries.
          </p>

          <ul className="mt-10 space-y-4 text-sm text-white/80">
            {[
              '4-tier LGU access control scoped to your barangay or municipality',
              'Approve and promote cultural, festival and civic events',
              'Manage POIs, unique Rizal foods and tourism logistics',
              'Province-wide tourism engagement for the Governor’s office',
            ].map((item) => (
              <li key={item} className="flex items-start gap-3">
                <span className="mt-0.5 rounded-full bg-gold/20 p-1 text-gold">
                  <Icon name="check" className="h-4 w-4" />
                </span>
                {item}
              </li>
            ))}
          </ul>
        </div>

        <p className="text-[11px] uppercase tracking-[0.2em] text-white/40">
          Discover Culture, Arts &amp; Tourism in Rizal
        </p>
      </section>

      <section className="flex items-center justify-center bg-surface px-4 py-10 sm:px-8">
        <div className="w-full max-w-md">
          <div className="mb-6 flex items-center gap-3 lg:hidden">
            <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-forest text-gold">
              <Icon name="pois" className="h-5 w-5" />
            </span>
            <div>
              <p className="text-lg font-bold text-forest">TuklasRizal</p>
              <p className="text-[10px] uppercase tracking-widest text-slate-400">
                LGU Web Admin Portal
              </p>
            </div>
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
            <div className="mb-6 grid grid-cols-2 gap-1 rounded-lg bg-surface p-1">
              {(
                [
                  { key: 'signin', label: 'Sign in' },
                  { key: 'register', label: 'LGU Registration' },
                ] as const
              ).map((tab) => (
                <button
                  key={tab.key}
                  type="button"
                  disabled={busy}
                  onClick={() => {
                    setMode(tab.key);
                    resetMessages();
                  }}
                  className={`rounded-md px-3 py-2 text-sm font-semibold transition disabled:opacity-60 ${
                    mode === tab.key
                      ? 'bg-white text-forest shadow-sm'
                      : 'text-slate-500 hover:text-forest'
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            {notice ? (
              <div className="mb-4">
                <Alert tone="success">{notice}</Alert>
              </div>
            ) : null}
            {error ? (
              <div className="mb-4">
                <Alert tone="error">{error}</Alert>
              </div>
            ) : null}

            {mode === 'signin' ? (
              <div className="space-y-4">
                <div>
                  <h2 className="text-lg font-bold text-forest">Welcome back</h2>
                  <p className="mt-1 text-sm text-slate-500">
                    Sign in with your TuklasRizal LGU account.
                  </p>
                </div>

                <button
                  type="button"
                  onClick={() => void handleGoogleSignIn()}
                  disabled={busy}
                  className="flex w-full items-center justify-center gap-3 rounded-lg border border-slate-300 bg-white px-4 py-2.5 text-sm font-semibold text-slate-700 shadow-sm transition hover:border-forest hover:bg-slate-50 focus-visible:ring-2 focus-visible:ring-forest/30 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  <GoogleGlyph />
                  Continue with Google
                </button>

                <div className="flex items-center gap-3">
                  <span className="h-px flex-1 bg-slate-200" />
                  <span className="text-[11px] uppercase tracking-wider text-slate-400">
                    or sign in with email
                  </span>
                  <span className="h-px flex-1 bg-slate-200" />
                </div>

                {signInMode === 'password' ? (
                  <form className="space-y-4" onSubmit={handleSignIn}>
                    <Field label="Email" required error={emailError}>
                      <Input
                        type="email"
                        autoComplete="email"
                        value={email}
                        disabled={busy}
                        onChange={(event) => changeEmail(event.target.value)}
                        placeholder="name@gmail.com"
                      />
                    </Field>
                    <Field label="Password" required error={passwordError}>
                      <Input
                        type="password"
                        autoComplete="current-password"
                        value={password}
                        disabled={busy}
                        onChange={(event) => {
                          setPassword(event.target.value);
                          if (passwordError) setPasswordError(null);
                        }}
                        placeholder="••••••••"
                      />
                    </Field>
                    <Button type="submit" className="w-full" disabled={busy}>
                      {busy ? 'Signing in…' : 'Sign In'}
                    </Button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => switchSignInMode('otp')}
                      className="w-full text-center text-xs font-semibold text-forest underline disabled:opacity-60"
                    >
                      Use Sign-In Link / OTP instead
                    </button>
                  </form>
                ) : (
                  <form
                    className="space-y-4"
                    onSubmit={otpSent ? handleVerifyOtp : handleSendOtp}
                  >
                    <Field label="Email" required error={emailError}>
                      <Input
                        type="email"
                        autoComplete="email"
                        value={email}
                        disabled={busy || otpSent}
                        onChange={(event) => changeEmail(event.target.value)}
                        placeholder="name@gmail.com"
                      />
                    </Field>
                    {otpSent ? (
                      <Field label="6-digit code" required error={otpError}>
                        <Input
                          inputMode="numeric"
                          autoComplete="one-time-code"
                          maxLength={6}
                          value={otpToken}
                          disabled={busy}
                          onChange={(event) => {
                            setOtpToken(event.target.value.replace(/\D/g, ''));
                            if (otpError) setOtpError(null);
                          }}
                          placeholder="123456"
                        />
                      </Field>
                    ) : null}
                    <Button type="submit" className="w-full" disabled={busy}>
                      {busy
                        ? 'Please wait…'
                        : otpSent
                          ? 'Verify & Sign In'
                          : 'Send Sign-In Link / OTP'}
                    </Button>
                    <div className="flex items-center justify-between gap-3">
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => switchSignInMode('password')}
                        className="text-xs font-semibold text-forest underline disabled:opacity-60"
                      >
                        Use Email &amp; Password instead
                      </button>
                      {otpSent ? (
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => void handleSendOtp()}
                          className="text-xs font-semibold text-slate-500 underline disabled:opacity-60"
                        >
                          Resend code
                        </button>
                      ) : null}
                    </div>
                  </form>
                )}

                <p className="text-center text-xs text-slate-500">
                  New LGU staff? Use{' '}
                  <button
                    type="button"
                    className="font-semibold text-forest underline"
                    disabled={busy}
                    onClick={() => {
                      setMode('register');
                      resetMessages();
                    }}
                  >
                    LGU Registration
                  </button>
                  . Accounts require Provincial Admin approval.
                </p>
              </div>
            ) : (
              <form className="space-y-4" onSubmit={handleRegister}>
                <h2 className="text-lg font-bold text-forest">LGU Staff Registration</h2>
                <p className="-mt-2 text-sm text-slate-500">
                  Requests are created with <strong>pending</strong> status and reviewed
                  by the Governor / Provincial IT Admin.
                </p>

                <Field label="Full name" required error={nameError}>
                  <Input
                    value={fullName}
                    disabled={busy}
                    onChange={(event) => {
                      setFullName(event.target.value);
                      if (nameError) setNameError(null);
                    }}
                    placeholder="Juan Dela Cruz"
                  />
                </Field>

                <Field label="Official email" required error={emailError}>
                  <Input
                    type="email"
                    autoComplete="email"
                    value={email}
                    disabled={busy}
                    onChange={(event) => changeEmail(event.target.value)}
                    placeholder="name@gmail.com"
                  />
                </Field>

                <Field label="Password" required error={passwordError}>
                  <Input
                    type="password"
                    autoComplete="new-password"
                    value={password}
                    disabled={busy}
                    onChange={(event) => {
                      setPassword(event.target.value);
                      if (passwordError || event.target.value) {
                        setPasswordError(validatePassword(event.target.value));
                      }
                      if (confirmPassword) {
                        setConfirmError(
                          validateConfirmPassword(event.target.value, confirmPassword),
                        );
                      }
                    }}
                    placeholder="••••••••"
                  />
                  <PasswordChecklist password={password} />
                </Field>

                <Field label="Confirm Password" required error={confirmError}>
                  <Input
                    type="password"
                    autoComplete="new-password"
                    value={confirmPassword}
                    disabled={busy}
                    onChange={(event) => {
                      setConfirmPassword(event.target.value);
                      if (confirmError || event.target.value) {
                        setConfirmError(
                          validateConfirmPassword(password, event.target.value),
                        );
                      }
                    }}
                    placeholder="••••••••"
                  />
                </Field>

                <Field label="LGU role" required>
                  <Select
                    value={roleTier}
                    disabled={busy}
                    onChange={(event) => {
                      setRoleTier(Number(event.target.value));
                      setBarangayId('');
                    }}
                  >
                    {REGISTRATION_TIERS.map((tier) => (
                      <option key={tier} value={tier}>
                        Tier {tier} — {roleTitleFor(tier)}
                      </option>
                    ))}
                  </Select>
                </Field>

                <div className="grid gap-4 sm:grid-cols-2">
                  <Field label="Municipality" required>
                    <Select
                      required
                      value={municipalityId}
                      disabled={busy}
                      onChange={(event) => {
                        setMunicipalityId(event.target.value);
                        setBarangayId('');
                      }}
                    >
                      <option value="">Select municipality</option>
                      {municipalities.map((municipality) => (
                        <option key={municipality.id} value={municipality.id}>
                          {municipality.name}
                        </option>
                      ))}
                    </Select>
                  </Field>

                  <Field
                    label="Barangay"
                    required={roleTier === 1}
                    hint={roleTier === 1 ? 'Required for Tier 1.' : 'Optional.'}
                  >
                    <Select
                      value={barangayId}
                      disabled={!municipalityId || busy}
                      onChange={(event) => setBarangayId(event.target.value)}
                    >
                      <option value="">Select barangay</option>
                      {municipalityBarangays.map((barangay) => (
                        <option key={barangay.id} value={barangay.id}>
                          {barangay.name}
                        </option>
                      ))}
                    </Select>
                  </Field>
                </div>

                <div className="rounded-lg border border-gold/60 bg-gold-soft px-3 py-2.5 text-xs text-[#6b4f00]">
                  Tier 1 creates draft events only. Tier 2 Tourism Coordinators approve
                  events, manage POIs and reply to inquiries. Tier 3 adds municipal civic
                  broadcasts.
                </div>

                <Button type="submit" className="w-full" disabled={busy}>
                  {busy ? 'Submitting…' : 'Request LGU account'}
                </Button>
              </form>
            )}
          </div>

          <p className="mt-6 text-center text-[11px] text-slate-400">
            TuklasRizal · Province of Rizal · Tourism Coordinator access
          </p>
        </div>
      </section>
    </div>
  );
}
