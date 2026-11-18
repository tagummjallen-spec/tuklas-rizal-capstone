import { useMemo, useState } from 'react';
import type { FormEvent } from 'react';
import { Icon } from '../components/Icon';
import { Alert, Button, Field, Input, Select } from '../components/ui';
import { useAuth } from '../context/AuthContext';
import { describeError } from '../lib/supabase';
import { roleTitleFor } from '../lib/rbac';
import type { Barangay, Municipality } from '../types';

interface LoginPageProps {
  municipalities: Municipality[];
  barangays: Barangay[];
}

type Mode = 'signin' | 'register';

const REGISTRATION_TIERS = [1, 2, 3];

export default function LoginPage({ municipalities, barangays }: LoginPageProps) {
  const { signIn, signUp } = useAuth();
  const [mode, setMode] = useState<Mode>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [roleTier, setRoleTier] = useState(2);
  const [municipalityId, setMunicipalityId] = useState('');
  const [barangayId, setBarangayId] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const municipalityBarangays = useMemo(
    () => barangays.filter((barangay) => barangay.municipality_id === municipalityId),
    [barangays, municipalityId],
  );

  const resetMessages = () => {
    setError(null);
    setNotice(null);
  };

  const handleSignIn = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    resetMessages();
    setBusy(true);
    try {
      await signIn(email, password);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : describeError(caught));
    } finally {
      setBusy(false);
    }
  };

  const handleRegister = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    resetMessages();

    if (!fullName.trim()) return setError('Please enter your full name.');
    if (!municipalityId) return setError('Please select your municipality.');
    if (password.length < 6) {
      return setError('Password must be at least 6 characters.');
    }
    if (roleTier === 1 && !barangayId) {
      return setError('Barangay Officials must select their barangay.');
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
        setNotice(
          'LGU account requested. Confirm your email address, then sign in. A Provincial Admin must approve your account before portal access is granted.',
        );
      }
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : describeError(caught));
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
                  onClick={() => {
                    setMode(tab.key);
                    resetMessages();
                  }}
                  className={`rounded-md px-3 py-2 text-sm font-semibold transition ${
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
              <form className="space-y-4" onSubmit={handleSignIn}>
                <h2 className="text-lg font-bold text-forest">Welcome back</h2>
                <p className="-mt-2 text-sm text-slate-500">
                  Sign in with your TuklasRizal LGU account.
                </p>
                <Field label="Email" required>
                  <Input
                    type="email"
                    autoComplete="email"
                    required
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                    placeholder="coordinator@rizal.gov.ph"
                  />
                </Field>
                <Field label="Password" required>
                  <Input
                    type="password"
                    autoComplete="current-password"
                    required
                    value={password}
                    onChange={(event) => setPassword(event.target.value)}
                    placeholder="••••••••"
                  />
                </Field>
                <Button type="submit" className="w-full" disabled={busy}>
                  {busy ? 'Signing in…' : 'Sign in'}
                </Button>
                <p className="text-center text-xs text-slate-500">
                  New LGU staff? Use{' '}
                  <button
                    type="button"
                    className="font-semibold text-forest underline"
                    onClick={() => {
                      setMode('register');
                      resetMessages();
                    }}
                  >
                    LGU Registration
                  </button>
                  . Accounts require Provincial Admin approval.
                </p>
              </form>
            ) : (
              <form className="space-y-4" onSubmit={handleRegister}>
                <h2 className="text-lg font-bold text-forest">LGU Staff Registration</h2>
                <p className="-mt-2 text-sm text-slate-500">
                  Requests are created with <strong>pending</strong> status and reviewed
                  by the Governor / Provincial IT Admin.
                </p>

                <Field label="Full name" required>
                  <Input
                    required
                    value={fullName}
                    onChange={(event) => setFullName(event.target.value)}
                    placeholder="Juan Dela Cruz"
                  />
                </Field>

                <Field label="Official email" required>
                  <Input
                    type="email"
                    autoComplete="email"
                    required
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                    placeholder="coordinator@rizal.gov.ph"
                  />
                </Field>

                <Field label="Password" required hint="Minimum 6 characters.">
                  <Input
                    type="password"
                    autoComplete="new-password"
                    required
                    minLength={6}
                    value={password}
                    onChange={(event) => setPassword(event.target.value)}
                    placeholder="••••••••"
                  />
                </Field>

                <Field label="LGU role" required>
                  <Select
                    value={roleTier}
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
                      disabled={!municipalityId}
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
