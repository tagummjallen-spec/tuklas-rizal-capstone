import { useCallback, useEffect, useMemo, useState } from 'react';
import { Icon } from '../components/Icon';
import {
  Alert,
  Badge,
  Button,
  Card,
  EmptyState,
  Field,
  Input,
  LoadingPanel,
  Modal,
  PageHeader,
  Select,
  Spinner,
  Textarea,
} from '../components/ui';
import { describeError, supabase } from '../lib/supabase';
import {
  TIER_LABELS,
  accessLevelLabel,
  canApproveUsers,
  roleTitleFor,
} from '../lib/rbac';
import { docFileName, isPdfPath, resolveVerificationDoc } from '../lib/verification';
import { fmtDateTime } from '../lib/format';
import type { Lookups } from '../hooks/useLookups';
import type { ApprovalStatus, UserProfile } from '../types';

interface UserApprovalsPageProps {
  profile: UserProfile;
  lookups: Lookups;
  /** Notifies the shell so the sidebar pending badge refreshes. */
  onReviewed?: () => void;
}

type StatusFilter = 'all' | 'pending' | 'approved';

const STATUS_FILTERS: { key: StatusFilter; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'pending', label: 'Pending Approval' },
  { key: 'approved', label: 'Approved Admins' },
];

/** Levels a Provincial Super Admin can hand out from this screen. */
const ASSIGNABLE_TIERS = [2, 3, 4];

interface ToastState {
  tone: 'success' | 'error' | 'info';
  message: string;
}

type ConfirmAction = 'approve' | 'reject' | 'revoke';

function statusOf(user: UserProfile): ApprovalStatus {
  const stored = user.approval_status;
  if (stored === 'pending' || stored === 'approved' || stored === 'rejected') {
    return stored;
  }
  return user.is_approved ? 'approved' : 'pending';
}

/** True once `supabase/admin_user_approvals.sql` has provisioned the columns. */
function hasApprovalColumns(user: UserProfile): boolean {
  return Object.prototype.hasOwnProperty.call(user, 'approval_status');
}

function requestedTierOf(user: UserProfile): number {
  const requested = user.requested_role_tier;
  if (typeof requested === 'number' && requested >= 1 && requested <= 4) {
    return requested;
  }
  return user.role_tier >= 1 ? user.role_tier : 2;
}

export default function UserApprovalsPage({
  profile,
  lookups,
  onReviewed,
}: UserApprovalsPageProps) {
  const [users, setUsers] = useState<UserProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<StatusFilter>('all');
  const [query, setQuery] = useState('');
  const [toast, setToast] = useState<ToastState | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const [assignTarget, setAssignTarget] = useState<UserProfile | null>(null);
  const [assignTier, setAssignTier] = useState(2);
  const [assignMunicipality, setAssignMunicipality] = useState('');

  const [inspectTarget, setInspectTarget] = useState<UserProfile | null>(null);
  const [inspectTier, setInspectTier] = useState(2);
  const [inspectMunicipality, setInspectMunicipality] = useState('');
  const [inspectNotes, setInspectNotes] = useState('');
  const [verifiedLguId, setVerifiedLguId] = useState(false);
  const [verifiedEndorsement, setVerifiedEndorsement] = useState(false);

  const [confirm, setConfirm] = useState<{
    action: ConfirmAction;
    user: UserProfile;
  } | null>(null);

  const allowed = canApproveUsers(profile);

  const loadUsers = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const { data, error: fetchError } = await supabase
        .from('users')
        .select('*')
        .order('created_at', { ascending: false });

      if (fetchError) {
        setError(describeError(fetchError));
        setUsers([]);
      } else {
        setUsers((data ?? []) as UserProfile[]);
      }
    } catch (loadError) {
      setError(
        `Could not reach Supabase. Check your connection and try again. ${describeError(
          loadError,
        )}`,
      );
      setUsers([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadUsers();
  }, [loadUsers]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), 4500);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const municipalityName = useCallback(
    (id: string | null | undefined) =>
      lookups.municipalities.find((item) => item.id === id)?.name ??
      'Not assigned',
    [lookups.municipalities],
  );

  const counts = useMemo(() => {
    let pending = 0;
    let approvedAdmins = 0;
    let rejected = 0;
    for (const user of users) {
      const status = statusOf(user);
      if (status === 'rejected') rejected += 1;
      if (!user.is_approved) pending += 1;
      if (status === 'approved' && user.role_tier >= 2) approvedAdmins += 1;
    }
    return { pending, approvedAdmins, rejected, total: users.length };
  }, [users]);

  const visibleUsers = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return users.filter((user) => {
      const status = statusOf(user);
      if (filter === 'pending' && user.is_approved) return false;
      if (filter === 'approved' && !(status === 'approved' && user.role_tier >= 2)) {
        return false;
      }
      if (!needle) return true;
      const haystack = [
        user.full_name,
        user.email,
        municipalityName(user.municipality_id),
        user.requested_municipality ?? '',
        user.department_office ?? '',
        roleTitleFor(user.role_tier),
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(needle);
    });
  }, [users, filter, query, municipalityName]);

  const patchUser = async (
    user: UserProfile,
    changes: Record<string, unknown>,
  ): Promise<boolean> => {
    setBusyId(user.id);
    setError(null);
    try {
      const { error: updateError } = await supabase
        .from('users')
        .update(changes)
        .eq('id', user.id);

      if (updateError) {
        const message = describeError(updateError);
        setError(message);
        setToast({ tone: 'error', message });
        return false;
      }
      await loadUsers();
      onReviewed?.();
      return true;
    } catch (updateFailure) {
      const message = `Could not save the change. ${describeError(updateFailure)}`;
      setError(message);
      setToast({ tone: 'error', message });
      return false;
    } finally {
      setBusyId(null);
    }
  };

  const reviewPayload = (user: UserProfile): Record<string, unknown> => {
    const payload: Record<string, unknown> = {};
    if (hasApprovalColumns(user)) {
      payload.review_notes = inspectNotes.trim() || null;
      payload.verified_lgu_id = verifiedLguId;
      payload.verified_endorsement = verifiedEndorsement;
    }
    return payload;
  };

  const approve = async (user: UserProfile) => {
    const payload: Record<string, unknown> = {
      is_approved: true,
      ...reviewPayload(user),
    };
    if (hasApprovalColumns(user)) payload.approval_status = 'approved';
    const ok = await patchUser(user, payload);
    if (ok) {
      setToast({
        tone: 'success',
        message: `${user.full_name} approved as ${roleTitleFor(user.role_tier)}.`,
      });
      setInspectTarget(null);
    }
    setConfirm(null);
  };

  const reject = async (user: UserProfile) => {
    const payload: Record<string, unknown> = {
      is_approved: false,
      role_tier: 1,
      role_title: roleTitleFor(1),
      ...reviewPayload(user),
    };
    if (hasApprovalColumns(user)) payload.approval_status = 'rejected';
    const ok = await patchUser(user, payload);
    if (ok) {
      setToast({
        tone: 'info',
        message: `Access rejected for ${user.full_name}.`,
      });
      setInspectTarget(null);
    }
    setConfirm(null);
  };

  const revoke = async (user: UserProfile) => {
    const payload: Record<string, unknown> = {
      is_approved: false,
      role_tier: 1,
      role_title: roleTitleFor(1),
      ...reviewPayload(user),
    };
    if (hasApprovalColumns(user)) payload.approval_status = 'rejected';
    const ok = await patchUser(user, payload);
    if (ok) {
      setToast({
        tone: 'info',
        message: `Administrative access revoked for ${user.full_name}.`,
      });
      setInspectTarget(null);
    }
    setConfirm(null);
  };

  const openAssign = (user: UserProfile) => {
    setAssignTarget(user);
    setAssignTier(requestedTierOf(user));
    setAssignMunicipality(user.municipality_id ?? '');
  };

  const saveAssignment = async () => {
    if (!assignTarget) return;
    const user = assignTarget;
    const payload: Record<string, unknown> = {
      role_tier: assignTier,
      role_title: roleTitleFor(assignTier),
      municipality_id: assignMunicipality || null,
      is_approved: true,
    };
    if (hasApprovalColumns(user)) payload.approval_status = 'approved';
    const ok = await patchUser(user, payload);
    if (ok) {
      setToast({
        tone: 'success',
        message: `${user.full_name} set to ${accessLevelLabel(assignTier)}${
          assignMunicipality ? ` · ${municipalityName(assignMunicipality)}` : ''
        }.`,
      });
      setAssignTarget(null);
    }
  };

  const openInspection = (user: UserProfile) => {
    setInspectTarget(user);
    setInspectTier(requestedTierOf(user));
    setInspectMunicipality(user.municipality_id ?? '');
    setInspectNotes(user.review_notes ?? '');
    setVerifiedLguId(user.verified_lgu_id === true);
    setVerifiedEndorsement(user.verified_endorsement === true);
  };

  const approveInspected = async () => {
    if (!inspectTarget) return;
    const payload: Record<string, unknown> = {
      is_approved: true,
      role_tier: inspectTier,
      role_title: roleTitleFor(inspectTier),
      municipality_id: inspectMunicipality || null,
      ...reviewPayload(inspectTarget),
    };
    if (hasApprovalColumns(inspectTarget)) payload.approval_status = 'approved';
    const ok = await patchUser(inspectTarget, payload);
    if (ok) {
      setToast({
        tone: 'success',
        message: `${inspectTarget.full_name} approved as ${accessLevelLabel(
          inspectTier,
        )}${inspectMunicipality ? ` · ${municipalityName(inspectMunicipality)}` : ''}.`,
      });
      setInspectTarget(null);
    }
  };

  const rejectInspected = async () => {
    if (!inspectTarget) return;
    if (inspectNotes.trim().length < 5) {
      setToast({
        tone: 'error',
        message: 'Add a short rejection reason in the review note before rejecting.',
      });
      return;
    }
    const payload: Record<string, unknown> = {
      is_approved: false,
      role_tier: 1,
      role_title: roleTitleFor(1),
      ...reviewPayload(inspectTarget),
    };
    if (hasApprovalColumns(inspectTarget)) payload.approval_status = 'rejected';
    const ok = await patchUser(inspectTarget, payload);
    if (ok) {
      setToast({
        tone: 'info',
        message: `Access rejected for ${inspectTarget.full_name}.`,
      });
      setInspectTarget(null);
    }
  };

  const revokeInspected = async () => {
    if (!inspectTarget) return;
    const payload: Record<string, unknown> = {
      is_approved: false,
      role_tier: 1,
      role_title: roleTitleFor(1),
      ...reviewPayload(inspectTarget),
    };
    if (hasApprovalColumns(inspectTarget)) payload.approval_status = 'rejected';
    const ok = await patchUser(inspectTarget, payload);
    if (ok) {
      setToast({
        tone: 'info',
        message: `Administrative access revoked for ${inspectTarget.full_name}.`,
      });
      setInspectTarget(null);
    }
  };

  if (!allowed) {
    return (
      <div>
        <PageHeader
          title="Admin & User Approvals"
          subtitle="Province-wide access management for LGU accounts."
        />
        <Alert tone="error" title="Level 4 access required">
          Only the Provincial Super Admin (Level 4) can approve, assign or
          revoke administrative access.
        </Alert>
      </div>
    );
  }

  const confirmCopy = confirm
    ? {
        approve: {
          title: 'Approve this account?',
          body: `${confirm.user.full_name} will be able to sign in to the LGU portal as ${roleTitleFor(
            confirm.user.role_tier,
          )}.`,
          cta: 'Approve account',
          variant: 'primary' as const,
        },
        reject: {
          title: 'Reject this request?',
          body: `${confirm.user.full_name} keeps a resident account but loses administrative access. This is recorded in the approval audit trail.`,
          cta: 'Reject request',
          variant: 'danger' as const,
        },
        revoke: {
          title: 'Revoke administrative access?',
          body: `${confirm.user.full_name} will drop to Level 1 access. Their events and listings stay in the portal, but they can no longer review or publish.`,
          cta: 'Revoke access',
          variant: 'danger' as const,
        },
      }[confirm.action]
    : null;

  const docPaths = (inspectTarget?.verification_doc_urls ?? []).filter(
    (path): path is string => typeof path === 'string' && path.length > 0,
  );

  return (
    <div>
      <PageHeader
        title="Admin & User Approvals"
        subtitle="Inspect every applicant's profile and verification documents, then approve, assign a municipality and access level (2–4), or reject/revoke. Every change is audit-friendly."
        actions={
          <>
            <Badge tone="gold">{counts.pending} pending</Badge>
            <Badge tone="green">{counts.approvedAdmins} approved admins</Badge>
            <Button variant="outline" onClick={() => void loadUsers()}>
              Refresh
            </Button>
          </>
        }
      />

      <div className="space-y-6">
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <StatCard label="Registered users" value={counts.total} />
          <StatCard label="Pending approval" value={counts.pending} tone="gold" />
          <StatCard
            label="Approved admins"
            value={counts.approvedAdmins}
            tone="green"
          />
          <StatCard label="Rejected / revoked" value={counts.rejected} tone="red" />
        </div>

        <Card className="p-5">
          <div className="flex flex-wrap items-end justify-between gap-4">
            <div>
              <h2 className="text-sm font-bold uppercase tracking-wider text-forest">
                Accounts & role requests
              </h2>
              <p className="mt-1 max-w-2xl text-xs text-slate-500">
                Open <strong>Inspect &amp; Review</strong> to see the applicant's
                submitted documents, requested tier, office and justification
                before deciding. Apply{' '}
                <code>supabase/admin_user_approvals.sql</code> to enable the
                level-4 RLS policies, audit columns and the private
                verification-docs bucket.
              </p>
            </div>
            <div className="w-full sm:w-72">
              <Input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Search name, email or municipality"
                aria-label="Search accounts"
              />
            </div>
          </div>

          <div className="mt-4 flex flex-wrap gap-2">
            {STATUS_FILTERS.map((item) => {
              const active = filter === item.key;
              return (
                <button
                  key={item.key}
                  type="button"
                  onClick={() => setFilter(item.key)}
                  className={`rounded-full px-3.5 py-1.5 text-xs font-semibold transition ${
                    active
                      ? 'bg-forest text-white shadow-sm'
                      : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                  }`}
                  aria-pressed={active}
                >
                  {item.label}
                </button>
              );
            })}
          </div>

          {error ? (
            <div className="mt-4">
              <Alert tone="error">{error}</Alert>
            </div>
          ) : null}

          <div className="mt-4">
            {loading ? (
              <LoadingPanel label="Loading registered users…" />
            ) : visibleUsers.length === 0 ? (
              <EmptyState
                title="No accounts match this view"
                description="Try another status filter or clear the search. New LGU registrations appear here as Pending Approval."
                action={
                  <Button
                    variant="outline"
                    onClick={() => {
                      setFilter('all');
                      setQuery('');
                    }}
                  >
                    Reset filters
                  </Button>
                }
              />
            ) : (
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-slate-200 text-sm">
                  <thead className="table-head">
                    <tr>
                      <th className="px-4 py-3">User</th>
                      <th className="px-4 py-3">Current access</th>
                      <th className="px-4 py-3">Requested</th>
                      <th className="px-4 py-3">Municipality</th>
                      <th className="px-4 py-3">Status</th>
                      <th className="px-4 py-3 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 bg-white">
                    {visibleUsers.map((user) => {
                      const status = statusOf(user);
                      const busy = busyId === user.id;
                      const isAdmin = user.role_tier >= 2;
                      const hasRequest =
                        typeof user.requested_role_tier === 'number' ||
                        Boolean(user.request_reason);
                      const docs = (user.verification_doc_urls ?? []).filter(Boolean);
                      return (
                        <tr key={user.id} className="hover:bg-surface/60">
                          <td className="px-4 py-3">
                            <p className="font-semibold text-slate-800">
                              {user.full_name}
                            </p>
                            <p className="text-[11px] text-slate-500">
                              {user.email}
                            </p>
                            <p className="text-[11px] text-slate-400">
                              Registered {fmtDateTime(user.created_at)}
                            </p>
                          </td>
                          <td className="px-4 py-3">
                            <p className="font-medium text-slate-700">
                              {user.role_tier <= 1
                                ? 'Level 1'
                                : `Level ${user.role_tier}`}
                            </p>
                            <p className="text-[11px] text-slate-500">
                              {TIER_LABELS[user.role_tier] ?? TIER_LABELS[0]}
                            </p>
                          </td>
                          <td className="px-4 py-3">
                            {hasRequest ? (
                              <>
                                <p className="text-xs font-semibold text-forest">
                                  {accessLevelLabel(requestedTierOf(user))}
                                </p>
                                <p className="text-[11px] text-slate-500">
                                  {user.requested_municipality ?? '—'}
                                </p>
                                <p className="text-[10px] text-slate-400">
                                  {docs.length} document{docs.length === 1 ? '' : 's'}
                                </p>
                              </>
                            ) : (
                              <span className="text-xs text-slate-400">
                                No request on file
                              </span>
                            )}
                          </td>
                          <td className="px-4 py-3 text-slate-600">
                            {municipalityName(user.municipality_id)}
                          </td>
                          <td className="px-4 py-3">
                            <StatusBadge status={status} />
                            {user.approved_at ? (
                              <p className="mt-1 text-[10px] text-slate-400">
                                Audited {fmtDateTime(user.approved_at)}
                              </p>
                            ) : null}
                          </td>
                          <td className="px-4 py-3">
                            <div className="flex flex-wrap items-center justify-end gap-2">
                              <Button
                                variant="outline"
                                className="!px-2.5 !py-1 text-xs"
                                disabled={busy}
                                onClick={() => openInspection(user)}
                              >
                                <Icon name="shield" className="h-3.5 w-3.5" />
                                Inspect &amp; Review
                              </Button>
                              {!user.is_approved ? (
                                <Button
                                  className="!px-2.5 !py-1 text-xs"
                                  disabled={busy || user.id === profile.id}
                                  onClick={() =>
                                    setConfirm({ action: 'approve', user })
                                  }
                                >
                                  Approve
                                </Button>
                              ) : null}
                              <Button
                                variant="outline"
                                className="!px-2.5 !py-1 text-xs"
                                disabled={busy}
                                onClick={() => openAssign(user)}
                              >
                                <Icon name="edit" className="h-3.5 w-3.5" />
                                {isAdmin ? 'Change access' : 'Assign'}
                              </Button>
                              {user.is_approved && isAdmin ? (
                                <Button
                                  variant="danger"
                                  className="!px-2.5 !py-1 text-xs"
                                  disabled={busy || user.id === profile.id}
                                  onClick={() =>
                                    setConfirm({ action: 'revoke', user })
                                  }
                                >
                                  Revoke
                                </Button>
                              ) : null}
                              {!user.is_approved && status !== 'rejected' ? (
                                <Button
                                  variant="danger"
                                  className="!px-2.5 !py-1 text-xs"
                                  disabled={busy}
                                  onClick={() =>
                                    setConfirm({ action: 'reject', user })
                                  }
                                >
                                  Reject
                                </Button>
                              ) : null}
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </Card>
      </div>

      {/* Inspect & review drawer ------------------------------------------- */}
      <Modal
        open={inspectTarget !== null}
        title="Inspect & review applicant"
        subtitle={
          inspectTarget
            ? `${inspectTarget.full_name} · ${inspectTarget.email}`
            : undefined
        }
        onClose={() => setInspectTarget(null)}
        width="max-w-4xl"
        footer={
          inspectTarget ? (
            <>
              <Button variant="ghost" onClick={() => setInspectTarget(null)}>
                Close
              </Button>
              {inspectTarget.is_approved && inspectTarget.role_tier >= 2 ? (
                <Button
                  variant="danger"
                  disabled={busyId !== null}
                  onClick={() => void revokeInspected()}
                >
                  Revoke Access
                </Button>
              ) : null}
              <Button
                variant="danger"
                disabled={busyId !== null}
                onClick={() => void rejectInspected()}
              >
                Reject with Reason
              </Button>
              <Button
                disabled={busyId !== null}
                onClick={() => void approveInspected()}
              >
                {busyId !== null ? (
                  <Spinner className="h-4 w-4 border-white/40 border-t-white" />
                ) : null}
                Approve &amp; Assign Tier
              </Button>
            </>
          ) : null
        }
      >
        {inspectTarget ? (
          <div className="space-y-6">
            {/* Profile ---------------------------------------------------- */}
            <section>
              <h3 className="text-xs font-bold uppercase tracking-wider text-forest">
                Applicant profile
              </h3>
              <dl className="mt-2 grid gap-3 rounded-lg border border-slate-200 bg-surface/60 p-4 text-sm sm:grid-cols-2">
                <Info label="Full legal name" value={inspectTarget.full_name} />
                <Info label="Email" value={inspectTarget.email} />
                <Info
                  label="Account created"
                  value={fmtDateTime(inspectTarget.created_at)}
                />
                <Info
                  label="Current role tier"
                  value={`Level ${inspectTarget.role_tier} — ${
                    TIER_LABELS[inspectTarget.role_tier] ?? TIER_LABELS[0]
                  }`}
                />
                <Info
                  label="Requested role tier"
                  value={accessLevelLabel(requestedTierOf(inspectTarget))}
                />
                <Info
                  label="Target municipality"
                  value={
                    inspectTarget.requested_municipality ??
                    municipalityName(inspectTarget.municipality_id)
                  }
                />
                <Info
                  label="Department / office"
                  value={inspectTarget.department_office || 'Not provided'}
                />
                <Info
                  label="Official position"
                  value={inspectTarget.official_position || 'Not provided'}
                />
                <Info
                  label="Government / LGU contact"
                  value={inspectTarget.contact_number || 'Not provided'}
                />
                <Info
                  label="Requested at"
                  value={fmtDateTime(inspectTarget.requested_at)}
                />
              </dl>
              <div className="mt-3 rounded-lg border border-slate-200 p-4">
                <p className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                  Justification / purpose
                </p>
                <p className="mt-1 text-sm leading-relaxed text-slate-700">
                  {inspectTarget.request_reason?.trim() ||
                    'The applicant did not submit a written justification.'}
                </p>
              </div>
            </section>

            {/* Documents -------------------------------------------------- */}
            <section>
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h3 className="text-xs font-bold uppercase tracking-wider text-forest">
                  Verification documents
                </h3>
                <Badge tone={docPaths.length > 0 ? 'green' : 'gold'}>
                  {docPaths.length} file{docPaths.length === 1 ? '' : 's'}
                </Badge>
              </div>
              {docPaths.length === 0 ? (
                <div className="mt-2 rounded-lg border border-dashed border-amber-300 bg-amber-50 px-4 py-6 text-center text-sm text-amber-800">
                  No verification documents uploaded yet. Ask the applicant to
                  attach an Official LGU ID or endorsement letter before
                  approving.
                </div>
              ) : (
                <div className="mt-2 space-y-4">
                  {docPaths.map((path, index) => (
                    <DocumentViewer
                      key={`${path}-${index}`}
                      path={path}
                      index={index}
                    />
                  ))}
                </div>
              )}
            </section>

            {/* Checklist + decision --------------------------------------- */}
            <section className="grid gap-4 lg:grid-cols-2">
              <div className="rounded-lg border border-slate-200 p-4">
                <h3 className="text-xs font-bold uppercase tracking-wider text-forest">
                  Verification checklist
                </h3>
                <label className="mt-3 flex items-start gap-2 text-sm text-slate-700">
                  <input
                    type="checkbox"
                    className="mt-0.5 h-4 w-4 accent-[#033300]"
                    checked={verifiedLguId}
                    onChange={(event) => setVerifiedLguId(event.target.checked)}
                  />
                  Valid LGU / Government ID confirmed
                </label>
                <label className="mt-2 flex items-start gap-2 text-sm text-slate-700">
                  <input
                    type="checkbox"
                    className="mt-0.5 h-4 w-4 accent-[#033300]"
                    checked={verifiedEndorsement}
                    onChange={(event) =>
                      setVerifiedEndorsement(event.target.checked)
                    }
                  />
                  Official endorsement / municipality verified
                </label>
                <p className="mt-3 text-[11px] text-slate-400">
                  Checklist results and notes are stored with the approval
                  decision.
                </p>
              </div>

              <div className="rounded-lg border border-slate-200 p-4">
                <h3 className="text-xs font-bold uppercase tracking-wider text-forest">
                  Decision
                </h3>
                <div className="mt-3 grid gap-3 sm:grid-cols-2">
                  <Field label="Assign access level" required>
                    <Select
                      value={String(inspectTier)}
                      onChange={(event) =>
                        setInspectTier(Number(event.target.value))
                      }
                    >
                      {ASSIGNABLE_TIERS.map((tier) => (
                        <option key={tier} value={tier}>
                          {accessLevelLabel(tier)}
                        </option>
                      ))}
                    </Select>
                  </Field>
                  <Field label="Assign municipality">
                    <Select
                      value={inspectMunicipality}
                      onChange={(event) =>
                        setInspectMunicipality(event.target.value)
                      }
                    >
                      <option value="">Province-wide (none)</option>
                      {lookups.municipalities.map((municipality) => (
                        <option key={municipality.id} value={municipality.id}>
                          {municipality.name}
                        </option>
                      ))}
                    </Select>
                  </Field>
                </div>
                <div className="mt-3">
                  <Field
                    label="Admin review note / rejection reason"
                    hint="Required before rejecting; stored with the audit trail."
                  >
                    <Textarea
                      rows={3}
                      maxLength={500}
                      value={inspectNotes}
                      onChange={(event) => setInspectNotes(event.target.value)}
                      placeholder="Verified endorsement letter from the Municipal Tourism Office…"
                    />
                  </Field>
                </div>
              </div>
            </section>
          </div>
        ) : null}
      </Modal>

      {/* Assign municipality + level --------------------------------------- */}
      <Modal
        open={assignTarget !== null}
        title="Assign municipality & access level"
        subtitle={
          assignTarget
            ? `${assignTarget.full_name} · ${assignTarget.email}`
            : undefined
        }
        onClose={() => setAssignTarget(null)}
        width="max-w-xl"
        footer={
          <>
            <Button variant="ghost" onClick={() => setAssignTarget(null)}>
              Cancel
            </Button>
            <Button
              onClick={() => void saveAssignment()}
              disabled={busyId !== null}
            >
              Save assignment
            </Button>
          </>
        }
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Access level" required>
            <Select
              value={String(assignTier)}
              onChange={(event) => setAssignTier(Number(event.target.value))}
            >
              {ASSIGNABLE_TIERS.map((tier) => (
                <option key={tier} value={tier}>
                  {accessLevelLabel(tier)}
                </option>
              ))}
            </Select>
          </Field>
          <Field
            label="Assigned municipality"
            hint="Leave blank for province-wide scope."
          >
            <Select
              value={assignMunicipality}
              onChange={(event) => setAssignMunicipality(event.target.value)}
            >
              <option value="">Province-wide (no municipality)</option>
              {lookups.municipalities.map((municipality) => (
                <option key={municipality.id} value={municipality.id}>
                  {municipality.name}
                </option>
              ))}
            </Select>
          </Field>
        </div>
        <div className="mt-4">
          <Alert tone="info">
            Saving also marks the account approved and records the approval in the
            audit columns when the approvals migration is applied.
          </Alert>
        </div>
      </Modal>

      {/* Confirmation ------------------------------------------------------- */}
      <Modal
        open={confirm !== null}
        title={confirmCopy?.title ?? ''}
        onClose={() => setConfirm(null)}
        width="max-w-lg"
        footer={
          <>
            <Button variant="ghost" onClick={() => setConfirm(null)}>
              Cancel
            </Button>
            <Button
              variant={confirmCopy?.variant ?? 'primary'}
              disabled={busyId !== null}
              onClick={() => {
                if (!confirm) return;
                if (confirm.action === 'approve') void approve(confirm.user);
                if (confirm.action === 'reject') void reject(confirm.user);
                if (confirm.action === 'revoke') void revoke(confirm.user);
              }}
            >
              {confirmCopy?.cta ?? 'Confirm'}
            </Button>
          </>
        }
      >
        <p className="text-sm text-slate-600">{confirmCopy?.body}</p>
        {confirm ? (
          <div className="mt-4 rounded-lg bg-surface px-4 py-3 text-xs text-slate-500">
            <p>
              <span className="font-semibold text-slate-700">Current access:</span>{' '}
              {TIER_LABELS[confirm.user.role_tier] ?? TIER_LABELS[0]}
            </p>
            <p className="mt-1">
              <span className="font-semibold text-slate-700">Municipality:</span>{' '}
              {municipalityName(confirm.user.municipality_id)}
            </p>
          </div>
        ) : null}
      </Modal>

      {/* Toast -------------------------------------------------------------- */}
      {toast ? (
        <div className="fixed bottom-6 right-6 z-[60] w-full max-w-sm">
          <Alert tone={toast.tone}>
            <div className="flex items-start justify-between gap-3">
              <span>{toast.message}</span>
              <button
                type="button"
                className="text-xs font-semibold opacity-60 hover:opacity-100"
                onClick={() => setToast(null)}
              >
                Dismiss
              </button>
            </div>
          </Alert>
        </div>
      ) : null}
    </div>
  );
}

function Info({ label, value }: { label: string; value: string | null | undefined }) {
  return (
    <div>
      <dt className="text-[10px] font-semibold uppercase tracking-wider text-slate-400">
        {label}
      </dt>
      <dd className="mt-0.5 break-words text-slate-700">{value || '—'}</dd>
    </div>
  );
}

/** Shows an inline image or embedded PDF plus a download/open link. */
function DocumentViewer({ path, index }: { path: string; index: number }) {
  const [state, setState] = useState<{
    loading: boolean;
    url?: string;
    error?: string;
  }>({ loading: true });

  useEffect(() => {
    let cancelled = false;
    setState({ loading: true });
    void resolveVerificationDoc(path).then((result) => {
      if (cancelled) return;
      setState({
        loading: false,
        url: result.url ?? undefined,
        error: result.error ?? undefined,
      });
    });
    return () => {
      cancelled = true;
    };
  }, [path]);

  const pdf = isPdfPath(path);

  return (
    <div className="rounded-lg border border-slate-200 p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-xs font-semibold text-slate-700">
          Document {index + 1} · {docFileName(path)}
        </p>
        {state.url ? (
          <a
            href={state.url}
            target="_blank"
            rel="noreferrer"
            className="text-xs font-semibold text-forest underline"
          >
            Open full document / Download
          </a>
        ) : null}
      </div>
      <div className="mt-2">
        {state.loading ? (
          <div className="flex items-center gap-2 rounded bg-surface px-3 py-6 text-xs text-slate-500">
            <Spinner className="h-4 w-4" /> Preparing secure preview…
          </div>
        ) : state.error ? (
          <div className="rounded border border-amber-300 bg-amber-50 px-3 py-3 text-xs text-amber-800">
            This file could not be previewed ({state.error}). It may still be
            uploading, or the storage policy has not been applied. Ask the
            applicant to re-upload it.
          </div>
        ) : pdf ? (
          <iframe
            title={`Verification document ${index + 1}`}
            src={state.url}
            className="h-80 w-full rounded border border-slate-200"
          />
        ) : (
          <img
            src={state.url}
            alt={`Verification document ${index + 1}`}
            className="max-h-80 w-auto rounded border border-slate-200 object-contain"
          />
        )}
      </div>
    </div>
  );
}

function StatCard({
  label,
  value,
  tone = 'slate',
}: {
  label: string;
  value: number;
  tone?: 'slate' | 'gold' | 'green' | 'red';
}) {
  const accent =
    tone === 'gold'
      ? 'text-[#7a5a00]'
      : tone === 'green'
        ? 'text-forest'
        : tone === 'red'
          ? 'text-red-700'
          : 'text-slate-700';
  return (
    <Card className="px-4 py-3">
      <p className="text-[10px] font-bold uppercase tracking-widest text-slate-400">
        {label}
      </p>
      <p className={`mt-1 text-2xl font-bold ${accent}`}>{value}</p>
    </Card>
  );
}

function StatusBadge({ status }: { status: ApprovalStatus }) {
  if (status === 'approved') return <Badge tone="green">Approved</Badge>;
  if (status === 'rejected') return <Badge tone="red">Rejected</Badge>;
  return <Badge tone="gold">Pending</Badge>;
}
