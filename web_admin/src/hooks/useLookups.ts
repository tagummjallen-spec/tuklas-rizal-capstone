import { useCallback, useEffect, useState } from 'react';
import { describeError, supabase } from '../lib/supabase';
import type { Barangay, Category, Municipality } from '../types';

export interface Lookups {
  municipalities: Municipality[];
  barangays: Barangay[];
  categories: Category[];
  loading: boolean;
  error: string | null;
  reload: () => Promise<void>;
}

/** Public reference data used across the portal forms. */
export function useLookups(): Lookups {
  const [municipalities, setMunicipalities] = useState<Municipality[]>([]);
  const [barangays, setBarangays] = useState<Barangay[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    setLoading(true);
    try {
      const [municipalityResult, barangayResult, categoryResult] = await Promise.all([
        supabase.from('municipalities').select('*').order('name'),
        supabase.from('barangays').select('*').order('name'),
        supabase.from('categories').select('*').order('name'),
      ]);

      const firstError =
        municipalityResult.error ?? barangayResult.error ?? categoryResult.error;

      setError(firstError ? describeError(firstError) : null);
      setMunicipalities((municipalityResult.data ?? []) as Municipality[]);
      setBarangays((barangayResult.data ?? []) as Barangay[]);
      setCategories((categoryResult.data ?? []) as Category[]);
    } catch (caught) {
      setError(describeError(caught));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void reload();
  }, [reload]);

  return { municipalities, barangays, categories, loading, error, reload };
}
