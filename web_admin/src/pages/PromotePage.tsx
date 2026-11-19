import { useCallback, useEffect, useState } from 'react';
import { Icon } from '../components/Icon';
import {
  Alert,
  Badge,
  Button,
  Card,
  EmptyState,
  Input,
  LoadingPanel,
  PageHeader,
} from '../components/ui';
import { describeError, supabase } from '../lib/supabase';
import { TIER_LABELS } from '../lib/rbac';
import { fmtDateTime, numOrNull } from '../lib/format';
import type { Lookups } from '../hooks/useLookups';
import type { UserProfile } from '../types';

interface PromotePageProps {
  profile: UserProfile;
  lookups: Lookups;
}

export default function PromotePage({ profile, lookups }: PromotePageProps) {
  const [boostDrafts, setBoostDrafts] = useState<Record<string, string>>({});
  const [savingId, setSavingId] = useState<string | null>(null);
  const [boostError, setBoostError] = useState<string | null>(null);
  const [boostNotice, setBoostNotice] = useState<string | null>(null);

  const [pendingUsers, setPendingUsers] = useState<UserProfile[]>([]);
  const [loadingUsers, setLoadingUsers] = useState(true);
  const [userError, setUserError] = useState<string | null>(null);
  const [userNotice, setUserNotice] = useState<string | null>(null);
  const [approvingId, setApprovingId] = useState<string | null>(null);

  useEffect(() => {
    setBoostDrafts(
      Object.fromEntries(
        lookups.municipalities.map((municipality) => [
          municipality.id,
          String(municipality.visitor_priority_boost ?? 1),
        ]),
      ),
    );
  }, [lookups.municipalities]);

  const loadPendingUsers = useCallback(async () => {
    setLoadingUsers(true);
    setUserError(null);
    try {
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('is_approved', false)
        .order('created_at', { ascending: true });

      if (error) setUserError(describeError(error));
      setPendingUsers((data ?? []) as UserProfile[]);
    } catch (caught) {
      setUserError(describeError(caught));
    } finally {
      setLoadingUsers(false);
    }
  }, []);

  useEffect(() => {
    void loadPendingUsers();
  }, [loadPendingUsers]);

  const municipalityName = (id: string | null) =>
    lookups.municipalities.find((municipality) => municipality.id === id)?.name ??
    'Not assigned';

  const saveBoost = async (municipalityId: string) => {
    setSavingId(municipalityId);
    setBoostError(null);
    setBoostNotice(null);

    try {
      const boost = numOrNull((boostDrafts[municipalityId] ?? '').trim());
      if (boost === null || !Number.isFinite(boost) || boost < 0.5 || boost > 2) {
        setBoostError('Enter a numeric weight between 0.5 and 2.0.');
        return;
      }

      const { error } = await supabase
        .from('municipalities')
        .update({ visitor_priority_boost: boost })
        .eq('id', municipalityId);

      if (error) {
        setBoostError(describeError(error));
      } else {
        setBoostNotice(
          `Promotion weight updated for ${municipalityName(municipalityId)}.`,
        );
        await lookups.reload();
      }
    } catch (caught) {
      setBoostError(describeError(caught));
    } finally {
      setSavingId(null);
    }
  };

  const approveUser = async (user: UserProfile) => {
    setApprovingId(user.id);
    setUserError(null);
    setUserNotice(null);
    try {
      const { error } = await supabase
        .from('users')
        .update({ is_approved: true })
        .eq('id', user.id);

      if (error) {
        setUserError(describeError(error));
      } else {
        setPendingUsers((current) => current.filter((item) => item.id !== user.id));
        setUserNotice(`${user.full_name} can now access the admin portal.`);
      }
    } catch (caught) {
      setUserError(describeError(caught));
    } finally {
      setApprovingId(null);
    }
  };

  return (
    <div>
      <PageHeader
        title="Promote Towns and Events"
        subtitle="Province-wide levers: tourism promotion weights per municipality and approval of LGU staff accounts."
        actions={
          <>
            <Badge tone="green">Province-wide · {lookups.municipalities.length}</Badge>
            <Badge tone="gold">{pendingUsers.length} pending LGU accounts</Badge>
          </>
        }
      />

      <div className="space-y-6">
        <Card className="p-5">
          <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
            <div>
              <h2 className="text-sm font-bold uppercase tracking-wider text-forest">
                Visitor Priority Boost
              </h2>
              <p className="mt-1 max-w-xl text-xs text-slate-500">
                Multipliers feed the Rule-Based AI “Promote Towns and Events” ranking in
                the mobile app. 1.00 is neutral; higher values surface lesser-visited
                towns more often.
              </p>
            </div>
            <Badge tone="slate">0.50 – 2.00</Badge>
          </div>

          {boostError ? (
            <div className="mb-3">
              <Alert tone="error">{boostError}</Alert>
            </div>
          ) : null}
          {boostNotice ? (
            <div className="mb-3">
              <Alert tone="success">{boostNotice}</Alert>
            </div>
          ) : null}

          {lookups.loading ? (
            <LoadingPanel label="Loading municipalities…" />
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-slate-200 text-sm">
                <thead className="table-head">
                  <tr>
                    <th className="px-4 py-3">Municipality</th>
                    <th className="px-4 py-3">Tourism Office</th>
                    <th className="px-4 py-3">Coordinator contact</th>
                    <th className="px-4 py-3">Weight</th>
                    <th className="px-4 py-3 text-right">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 bg-white">
                  {lookups.municipalities.map((municipality) => (
                    <tr key={municipality.id} className="hover:bg-surface/60">
                      <td className="px-4 py-3 font-semibold text-slate-800">
                        {municipality.name}
                      </td>
                      <td className="px-4 py-3 text-slate-600">
                        {municipality.tourism_office_name ?? '—'}
                      </td>
                      <td className="px-4 py-3 text-slate-600">
                        <p>{municipality.coordinator_contact_email ?? '—'}</p>
                        <p className="text-[11px] text-slate-400">
                          {municipality.coordinator_contact_phone ?? 'No phone on record'}
                        </p>
                      </td>
                      <td className="px-4 py-3">
                        <Input
                          type="number"
                          min="0.5"
                          max="2"
                          step="0.05"
                          className="w-24"
                          value={boostDrafts[municipality.id] ?? ''}
                          onChange={(event) =>
                            setBoostDrafts({
                              ...boostDrafts,
                              [municipality.id]: event.target.value,
                            })
                          }
                        />
                      </td>
                      <td className="px-4 py-3 text-right">
                        <Button
                          variant="outline"
                          className="px-2 py-1 text-xs"
                          disabled={savingId === municipality.id}
                          onClick={() => void saveBoost(municipality.id)}
                        >
                          {savingId === municipality.id ? 'Saving…' : 'Save weight'}
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>

        <Card className="p-5">
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-sm font-bold uppercase tracking-wider text-forest">
                LGU User Approvals
              </h2>
              <p className="mt-1 text-xs text-slate-500">
                Accounts registered from the web portal start unapproved. Granting access
                activates their tier and municipal scope.
              </p>
            </div>
            <Button
              variant="ghost"
              className="text-xs"
              onClick={() => void loadPendingUsers()}
            >
              Refresh
            </Button>
          </div>

          {userError ? (
            <div className="mb-3">
              <Alert tone="error">{userError}</Alert>
            </div>
          ) : null}
          {userNotice ? (
            <div className="mb-3">
              <Alert tone="success">{userNotice}</Alert>
            </div>
          ) : null}

          {loadingUsers ? (
            <LoadingPanel label="Loading pending accounts…" />
          ) : pendingUsers.length === 0 ? (
            <EmptyState
              title="No pending LGU accounts"
              description="New Coordinator, Barangay Official and Mayor registrations will appear here for approval."
            />
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-slate-200 text-sm">
                <thead className="table-head">
                  <tr>
                    <th className="px-4 py-3">Name</th>
                    <th className="px-4 py-3">Requested role</th>
                    <th className="px-4 py-3">Municipality</th>
                    <th className="px-4 py-3">Registered</th>
                    <th className="px-4 py-3 text-right">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 bg-white">
                  {pendingUsers.map((user) => (
                    <tr key={user.id} className="hover:bg-surface/60">
                      <td className="px-4 py-3">
                        <p className="font-semibold text-slate-800">{user.full_name}</p>
                        <p className="text-[11px] text-slate-400">{user.email}</p>
                      </td>
                      <td className="px-4 py-3">
                        <Badge tone="slate">
                          Tier {user.role_tier} —{' '}
                          {user.role_title ?? TIER_LABELS[user.role_tier] ?? 'LGU Staff'}
                        </Badge>
                      </td>
                      <td className="px-4 py-3 text-slate-600">
                        {municipalityName(user.municipality_id)}
                      </td>
                      <td className="px-4 py-3 text-slate-600">
                        {fmtDateTime(user.created_at)}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <Button
                          className="px-2 py-1 text-xs"
                          disabled={approvingId === user.id}
                          onClick={() => void approveUser(user)}
                        >
                          <Icon name="check" className="h-3.5 w-3.5" />
                          {approvingId === user.id ? 'Approving…' : 'Approve'}
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>

        <Card className="border-gold/50 bg-gold-soft/50 p-5">
          <p className="text-xs leading-relaxed text-[#6b4f00]">
            <strong>Signed in as {profile.full_name}</strong> —{' '}
            {TIER_LABELS[profile.role_tier] ?? 'Provincial IT Admin'}. Only the Governor /
            Provincial IT Admin can change promotion weights or approve LGU accounts.
          </p>
        </Card>
      </div>
    </div>
  );
}
