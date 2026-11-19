import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

/**
 * Live pending-approval count for the sidebar badge.
 *
 * Only Level 4 admins can read every user row; for anyone else the query fails
 * closed and the badge stays hidden.
 */
export function usePendingApprovals(enabled: boolean, refreshKey?: unknown): number {
  const [count, setCount] = useState(0);

  useEffect(() => {
    if (!enabled) {
      setCount(0);
      return;
    }
    let cancelled = false;

    const load = async () => {
      try {
        const { count: pending, error } = await supabase
          .from('users')
          .select('id', { count: 'exact', head: true })
          .eq('is_approved', false);
        if (!cancelled && !error) setCount(pending ?? 0);
      } catch {
        // Offline or RLS denied — leave the last known count.
      }
    };

    void load();
    const timer = window.setInterval(load, 60_000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [enabled, refreshKey]);

  return count;
}
