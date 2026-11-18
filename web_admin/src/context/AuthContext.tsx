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
  signUp: (input: SignUpInput) => Promise<{ needsConfirmation: boolean }>;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function metaString(meta: Record<string, unknown>, key: string): string | null {
  const value = meta[key];
  return typeof value === 'string' && value.trim() !== '' ? value : null;
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

    if (data) {
      setProfile(data as UserProfile);
      setLoading(false);
      return;
    }

    const meta = (current.user.user_metadata ?? {}) as Record<string, unknown>;
    const tier = Number(meta.role_tier ?? 1) || 1;

    const { error: insertError } = await supabase.from('users').insert({
      id: current.user.id,
      email: current.user.email ?? '',
      full_name: metaString(meta, 'full_name') ?? 'LGU Staff',
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
    setLoading(false);
  }, []);

  useEffect(() => {
    let cancelled = false;

    void supabase.auth.getSession().then(({ data }) => {
      if (cancelled) return;
      setSession(data.session);
      if (data.session) {
        void loadProfile(data.session);
      } else {
        setLoading(false);
      }
    });

    const { data: listener } = supabase.auth.onAuthStateChange((_event, next) => {
      setSession(next);
      if (!next) {
        setProfile(null);
        setError(null);
        setLoading(false);
      }
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
      setSession(data.session);
      await loadProfile(data.session);
    },
    [loadProfile],
  );

  const signUp = useCallback(
    async (input: SignUpInput) => {
      setError(null);
      const roleTitle = roleTitleFor(input.roleTier);
      const { data, error: signUpError } = await supabase.auth.signUp({
        email: input.email.trim(),
        password: input.password,
        options: {
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
    await supabase.auth.signOut();
    setProfile(null);
    setSession(null);
    setError(null);
  }, []);

  const refreshProfile = useCallback(async () => {
    const { data } = await supabase.auth.getSession();
    if (data.session) await loadProfile(data.session);
  }, [loadProfile]);

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      profile,
      loading,
      error,
      signIn,
      signUp,
      signOut,
      refreshProfile,
    }),
    [session, profile, loading, error, signIn, signUp, signOut, refreshProfile],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used inside <AuthProvider>');
  return context;
}
