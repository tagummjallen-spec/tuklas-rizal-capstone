import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'Missing VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY. Copy .env.example to .env.local and restart the dev server.',
  );
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

/** Normalise Supabase / PostgREST errors into a readable sentence. */
export function describeError(error: unknown): string {
  if (!error) return '';
  if (typeof error === 'string') return error;
  if (typeof error === 'object') {
    const candidate = error as { message?: string; details?: string; hint?: string; code?: string };
    const parts = [candidate.message, candidate.details, candidate.hint].filter(Boolean);
    if (parts.length > 0) {
      return candidate.code ? `${parts.join(' — ')} (${candidate.code})` : parts.join(' — ');
    }
  }
  return 'Unexpected error. Please try again.';
}
