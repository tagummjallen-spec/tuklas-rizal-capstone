import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';
import type { ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { describeError, supabase } from '../lib/supabase';
import { roleTitleFor } from '../lib/rbac';
import type { UserProfile } from '../types';

/** Exact copy shown when an email/password account has not confirmed its address. */
export const EMAIL_VERIFICATION_REQUIRED =
  'Please verify your email address from the confirmation link sent to your inbox before signing in or rating places.';

/** True only for email/password sessions that still await verification. */
function isUnverifiedEmailSession(session: Session | null): boolean {
  const user = session?.user;
  if (!user) return false;
  if (user.app_metadata?.provider !== 'email') return false;
  return !user.email_confirmed_at;
}

export interface SignUpInput {
  email: string;
  password: string;
  fullName: string;
  roleTier: number;
  municipalityId: string;
  barangayId: string | null;
}

interface AuthContextValue {
  session: Session | null;
  profile: UserProfile | null;
  loading: boolean;
  error: string | null;
  signIn: (email: string, password: string) => Promise<void>;
  /** Sends a sign-in link / 6-digit code without creating unknown users. */
  sendLoginOtp: (email: string) => Promise<void>;
  verifyLoginOtp: (email: string, token: string) => Promise<void>;
  /** Google OAuth via Supabase; the redirect is handled by onAuthStateChange. */
  signInWithGoogle: () => Promise<void>;
  signUp: (input: SignUpInput) => Promise<{ needsConfirmation: boolean }>;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function metaString(meta: Record<string, unknown>, key: string): string | null {
  const value = meta[key];
  return typeof value === 'string' && value.trim() !== '' ? value : null;
}

/** True when the Supabase user authenticated with a Google account. */
function isGoogleUser(meta: Record<string, unknown>): boolean {
  if (meta.provider === 'google') return true;
  const providers = meta.providers;
  return Array.isArray(providers) && providers.includes('google');
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  /**
   * Load `public.users` for the signed-in auth user. If the row is missing
   * (email-confirmation signups have no session at registration time) it is
   * provisioned from the auth metadata with `is_approved = false`.
   */
  const loadProfile = useCallback(async (current: Session) => {
    setLoading(true);
    setError(null);
    try {
    // Email/password accounts without a confirmed address never get portal
    // access. Kill the session before any profile is loaded or cached.
    if (isUnverifiedEmailSession(current)) {
      await supabase.auth.signOut();
      setSession(null);
      setProfile(null);
      setError(EMAIL_VERIFICATION_REQUIRED);
      setLoading(false);
      return;
    }
    const { data, error: fetchError } = await supabase
      .from('users')
      .select('*')
      .eq('id', current.user.id)
      .maybeSingle();

    if (fetchError) {
      setError(describeError(fetchError));
      setProfile(null);
      setLoading(false);
      return;
    }

    const meta = (current.user.user_metadata ?? {}) as Record<string, unknown>;
    const googleName = metaString(meta, 'full_name') ?? metaString(meta, 'name');
    const googleAvatar = metaString(meta, 'avatar_url') ?? metaString(meta, 'picture');

    if (data) {
      // Google users who already have a public.users row get a best-effort
      // top-up of provider metadata (avatar / name). Never overwrite the
      // LGU-assigned role_tier or approval flags here.
      if (isGoogleUser(meta) && (googleAvatar || googleName)) {
        const topUp: Record<string, string> = {};
        const existing = data as UserProfile;
        if (googleAvatar && !existing.avatar_url) topUp.avatar_url = googleAvatar;
        if (googleName && (!existing.full_name || existing.full_name === 'LGU Staff')) {
          topUp.full_name = googleName;
        }
        if (Object.keys(topUp).length > 0) {
          await supabase.from('users').update(topUp).eq('id', current.user.id);
        }
      }

      const { data: refreshed } = await supabase
        .from('users')
        .select('*')
        .eq('id', current.user.id)
        .maybeSingle();
      setProfile((refreshed as UserProfile | null) ?? (data as UserProfile));
      setLoading(false);
      return;
    }

    const tier = Number(meta.role_tier ?? 1) || 1;

    const { error: insertError } = await supabase.from('users').insert({
      id: current.user.id,
      email: current.user.email ?? '',
      full_name: googleName ?? metaString(meta, 'full_name') ?? 'LGU Staff',
      avatar_url: googleAvatar,
      role_tier: tier,
      role_title: metaString(meta, 'role_title') ?? roleTitleFor(tier),
      municipality_id: metaString(meta, 'municipality_id'),
      barangay_id: metaString(meta, 'barangay_id'),
      is_approved: false,
    });

    if (insertError) {
      setError(
        `Signed in, but your LGU profile could not be created automatically. ${describeError(
          insertError,
        )}`,
      );
      setProfile(null);
      setLoading(false);
      return;
    }

    const { data: created } = await supabase
      .from('users')
      .select('*')
      .eq('id', current.user.id)
      .maybeSingle();

    setProfile((created as UserProfile | null) ?? null);
    } catch (caught) {
      setError(describeError(caught));
      setProfile(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;

    void supabase.auth
      .getSession()
      .then(({ data, error: sessionError }) => {
        if (cancelled) return;
        if (sessionError) {
          setError(describeError(sessionError));
          setLoading(false);
          return;
        }
        setSession(data.session);
        if (data.session) {
          void loadProfile(data.session);
        } else {
          setLoading(false);
        }
      })
      .catch((caught) => {
        if (cancelled) return;
        setError(describeError(caught));
        setLoading(false);
      });

    const { data: listener } = supabase.auth.onAuthStateChange((_event, next) => {
      if (cancelled) return;
      void (async () => {
        try {
          setSession(next);
          if (!next) {
            setProfile(null);
            // A verification-driven sign-out emits a `null` event right after
            // loadProfile sets the message. Keep that exact copy visible.
            setError((current) =>
              current === EMAIL_VERIFICATION_REQUIRED ? current : null,
            );
            setLoading(false);
          } else {
            // Google OAuth returns to window.location.origin with a session.
            // Re-verify public.users (role_tier + approval) after the redirect so
            // approved LGU admins enter the dashboard and unapproved see pending.
            await loadProfile(next);
          }
        } catch (caught) {
          if (cancelled) return;
          setError(describeError(caught));
        }
      })();
    });

    return () => {
      cancelled = true;
      listener.subscription.unsubscribe();
    };
  }, [loadProfile]);

  const signIn = useCallback(
    async (email: string, password: string) => {
      setError(null);
      const { data, error: signInError } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      });
      if (signInError) throw new Error(describeError(signInError));
      if (!data.session) throw new Error('Sign in failed. Please try again.');
      if (isUnverifiedEmailSession(data.session)) {
        await supabase.auth.signOut();
        throw new Error(EMAIL_VERIFICATION_REQUIRED);
      }
      setSession(data.session);
      await loadProfile(data.session);
    },
    [loadProfile],
  );

  const sendLoginOtp = useCallback(async (email: string) => {
    setError(null);
    const { error: otpError } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: {
        shouldCreateUser: false,
        emailRedirectTo: `${window.location.origin}/`,
      },
    });
    if (otpError) throw otpError;
  }, []);

  const verifyLoginOtp = useCallback(async (email: string, token: string) => {
    setError(null);
    const { data, error: verifyError } = await supabase.auth.verifyOtp({
      email: email.trim(),
      token: token.trim(),
      type: 'email',
    });
    if (verifyError) throw verifyError;
    if (!data.session) throw new Error('Sign in failed. Please try again.');
    setSession(data.session);
    await loadProfile(data.session);
  }, [loadProfile]);

  const signInWithGoogle = useCallback(async () => {
    setError(null);
    const { error: oauthError } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/`,
      },
    });
    if (oauthError) throw new Error(describeError(oauthError));
    // The browser is navigated to Google; on return, onAuthStateChange /
    // getSession load and verify the public.users profile.
  }, []);

  const signUp = useCallback(
    async (input: SignUpInput) => {
      setError(null);
      const roleTitle = roleTitleFor(input.roleTier);
      const { data, error: signUpError } = await supabase.auth.signUp({
        email: input.email.trim(),
        password: input.password,
        options: {
          emailRedirectTo: `${window.location.origin}/`,
          data: {
            full_name: input.fullName.trim(),
            role_tier: input.roleTier,
            role_title: roleTitle,
            municipality_id: input.municipalityId,
            barangay_id: input.barangayId,
          },
        },
      });

      if (signUpError) throw new Error(describeError(signUpError));
      if (!data.user) throw new Error('Registration failed. Please try again.');

      if (data.session) {
        const { error: profileError } = await supabase.from('users').insert({
          id: data.user.id,
          email: input.email.trim(),
          full_name: input.fullName.trim(),
          role_tier: input.roleTier,
          role_title: roleTitle,
          municipality_id: input.municipalityId,
          barangay_id: input.barangayId,
          is_approved: false,
        });

        if (profileError) {
          throw new Error(
            `Account created, but the LGU profile could not be saved. ${describeError(
              profileError,
            )}`,
          );
        }

        await loadProfile(data.session);
      }

      return { needsConfirmation: !data.session };
    },
    [loadProfile],
  );

  const signOut = useCallback(async () => {
    try {
      await supabase.auth.signOut();
      setError(null);
    } catch (caught) {
      setError(describeError(caught));
    } finally {
      setProfile(null);
      setSession(null);
    }
  }, []);

  const refreshProfile = useCallback(async () => {
    try {
      const { data, error: sessionError } = await supabase.auth.getSession();
      if (sessionError) {
        setError(describeError(sessionError));
        return;
      }
      if (data.session) await loadProfile(data.session);
    } catch (caught) {
      setError(describeError(caught));
    }
  }, [loadProfile]);

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      profile,
      loading,
      error,
      signIn,
      sendLoginOtp,
      verifyLoginOtp,
      signInWithGoogle,
      signUp,
      signOut,
      refreshProfile,
    }),
    [
      session, profile, loading, error, signIn, sendLoginOtp, verifyLoginOtp,
      signInWithGoogle, signUp, signOut, refreshProfile,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used inside <AuthProvider>');
  return context;
}
