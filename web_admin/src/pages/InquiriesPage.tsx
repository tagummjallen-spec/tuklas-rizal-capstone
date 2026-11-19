import { useCallback, useEffect, useMemo, useState } from 'react';
import { Icon } from '../components/Icon';
import {
  Alert,
  Badge,
  Button,
  Card,
  EmptyState,
  LoadingPanel,
  PageHeader,
  Textarea,
} from '../components/ui';
import { describeError, supabase } from '../lib/supabase';
import { isProvincial, municipalityScope } from '../lib/rbac';
import { fmtDateTime } from '../lib/format';
import type { Lookups } from '../hooks/useLookups';
import type { CoordinatorInquiry, InquiryStatus, UserProfile } from '../types';

interface InquiriesPageProps {
  profile: UserProfile;
  lookups: Lookups;
}

function statusTone(status: InquiryStatus): 'gold' | 'blue' | 'green' {
  if (status === 'resolved') return 'green';
  if (status === 'in_progress') return 'blue';
  return 'gold';
}

const REPLY_MAX = 1000;

export default function InquiriesPage({ profile, lookups }: InquiriesPageProps) {
  const provincial = isProvincial(profile);
  const scope = municipalityScope(profile);

  const [inquiries, setInquiries] = useState<CoordinatorInquiry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<'all' | InquiryStatus>('all');
  const [replies, setReplies] = useState<Record<string, string>>({});
  const [busyId, setBusyId] = useState<string | null>(null);

  const filters = useMemo(() => {
    const value: Record<string, string> = {};
    if (scope) value.municipality_id = scope;
    return value;
  }, [scope]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const { data, error: loadError } = await supabase
        .from('coordinator_inquiries')
        .select('*')
        .match(filters)
        .order('created_at', { ascending: false });

      if (loadError) setError(describeError(loadError));
      const records = (data ?? []) as CoordinatorInquiry[];
      setInquiries(records);
      setReplies(
        Object.fromEntries(
          records.map((inquiry) => [inquiry.id, inquiry.coordinator_reply ?? '']),
        ),
      );
    } catch (caught) {
      setError(describeError(caught));
    } finally {
      setLoading(false);
    }
  }, [filters]);

  useEffect(() => {
    void load();
  }, [load]);

  const visible =
    statusFilter === 'all'
      ? inquiries
      : inquiries.filter((inquiry) => inquiry.status === statusFilter);

  const municipalityName = (id: string) =>
    lookups.municipalities.find((municipality) => municipality.id === id)?.name ??
    'Unassigned';

  const updateInquiry = async (
    inquiry: CoordinatorInquiry,
    changes: { coordinator_reply?: string; status: InquiryStatus },
    successMessage: string,
  ) => {
    setBusyId(inquiry.id);
    setActionError(null);
    setNotice(null);
    try {
      const reply = (changes.coordinator_reply ?? '').trim();
      if (changes.coordinator_reply !== undefined && !reply) {
        setActionError('Write a reply before saving.');
        return;
      }
      if (reply.length > REPLY_MAX) {
        setActionError(`Keep the reply under ${REPLY_MAX} characters.`);
        return;
      }

      const cleanChanges = {
        ...changes,
        ...(changes.coordinator_reply !== undefined
          ? { coordinator_reply: reply }
          : {}),
      };
      const { error: updateError } = await supabase
        .from('coordinator_inquiries')
        .update(cleanChanges)
        .eq('id', inquiry.id);

      if (updateError) {
        setActionError(describeError(updateError));
      } else {
        setNotice(successMessage);
        await load();
      }
    } catch (caught) {
      setActionError(describeError(caught));
    } finally {
      setBusyId(null);
    }
  };

  const saveReply = async (inquiry: CoordinatorInquiry) => {
    const reply = (replies[inquiry.id] ?? '').trim();
    if (!reply) {
      setActionError('Write a reply before saving.');
      return;
    }
    if (reply.length > REPLY_MAX) {
      setActionError(`Keep the reply under ${REPLY_MAX} characters.`);
      return;
    }
    await updateInquiry(
      inquiry,
      {
        coordinator_reply: reply,
        status: inquiry.status === 'open' ? 'in_progress' : inquiry.status,
      },
      'Reply saved and sent to the tourist.',
    );
  };

  return (
    <div>
      <PageHeader
        title="Tourism Coordinator Inquiries"
        subtitle={
          provincial
            ? 'Province-wide inbox of tourist messages routed to municipal Tourism Coordinators.'
            : `Messages routed to the ${municipalityName(scope ?? '')} Tourism Coordinator.`
        }
        actions={
          <>
            <Badge tone="gold">
              {inquiries.filter((inquiry) => inquiry.status === 'open').length} open
            </Badge>
            <Badge tone="blue">
              {inquiries.filter((inquiry) => inquiry.status === 'in_progress').length} in
              progress
            </Badge>
            <Badge tone="green">
              {inquiries.filter((inquiry) => inquiry.status === 'resolved').length} resolved
            </Badge>
          </>
        }
      />

      {notice ? (
        <div className="mb-4">
          <Alert tone="success">{notice}</Alert>
        </div>
      ) : null}
      {actionError ? (
        <div className="mb-4">
          <Alert tone="error">{actionError}</Alert>
        </div>
      ) : null}
      {error ? (
        <div className="mb-4">
          <Alert tone="error">{error}</Alert>
        </div>
      ) : null}

      <div className="mb-4 flex flex-wrap items-center gap-2">
        {(['all', 'open', 'in_progress', 'resolved'] as const).map((value) => (
          <button
            key={value}
            type="button"
            onClick={() => setStatusFilter(value)}
            className={`rounded-full px-3 py-1.5 text-xs font-semibold uppercase tracking-wide transition ${
              statusFilter === value
                ? 'bg-forest text-white'
                : 'bg-white text-slate-500 shadow-sm ring-1 ring-slate-200 hover:text-forest'
            }`}
          >
            {value === 'all' ? `All (${inquiries.length})` : value.replace('_', ' ')}
          </button>
        ))}
      </div>

      {loading ? (
        <LoadingPanel label="Loading coordinator inbox…" />
      ) : visible.length === 0 ? (
        <Card>
          <EmptyState
            title="No inquiries in this view"
            description="Tourist messages submitted from the mobile app will appear here."
          />
        </Card>
      ) : (
        <div className="space-y-4">
          {visible.map((inquiry) => {
            const busy = busyId === inquiry.id;
            return (
              <Card key={inquiry.id} className="overflow-hidden">
                <div className="flex flex-wrap items-start justify-between gap-3 border-b border-slate-100 px-5 py-4">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-base font-bold text-slate-800">
                        {inquiry.subject}
                      </h2>
                      <Badge tone={statusTone(inquiry.status)}>
                        {inquiry.status.replace('_', ' ')}
                      </Badge>
                    </div>
                    <p className="mt-1 text-xs text-slate-400">
                      {municipalityName(inquiry.municipality_id)} ·{' '}
                      {fmtDateTime(inquiry.created_at)} · Tourist{' '}
                      {inquiry.user_id.slice(0, 8)}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-1.5">
                    {inquiry.status !== 'in_progress' ? (
                      <Button
                        variant="outline"
                        className="px-2 py-1 text-xs"
                        disabled={busy}
                        onClick={() =>
                          void updateInquiry(
                            inquiry,
                            { status: 'in_progress' },
                            'Inquiry marked in progress.',
                          )
                        }
                      >
                        In progress
                      </Button>
                    ) : null}
                    {inquiry.status !== 'resolved' ? (
                      <Button
                        variant="primary"
                        className="px-2 py-1 text-xs"
                        disabled={busy}
                        onClick={() =>
                          void updateInquiry(
                            inquiry,
                            { status: 'resolved' },
                            'Inquiry marked resolved.',
                          )
                        }
                      >
                        <Icon name="check" className="h-3.5 w-3.5" />
                        Resolve
                      </Button>
                    ) : (
                      <Button
                        variant="ghost"
                        className="px-2 py-1 text-xs"
                        disabled={busy}
                        onClick={() =>
                          void updateInquiry(
                            inquiry,
                            { status: 'open' },
                            'Inquiry reopened.',
                          )
                        }
                      >
                        Reopen
                      </Button>
                    )}
                  </div>
                </div>

                <div className="space-y-4 px-5 py-4">
                  <div className="rounded-lg bg-surface/80 px-4 py-3 text-sm text-slate-700">
                    {inquiry.message}
                  </div>

                  <div>
                    <p className="mb-1 text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                      Tourism Coordinator reply
                    </p>
                    <Textarea
                      rows={3}
                      value={replies[inquiry.id] ?? ''}
                      maxLength={REPLY_MAX}
                      onChange={(event) =>
                        setReplies({ ...replies, [inquiry.id]: event.target.value })
                      }
                      placeholder="Respond to the tourist with schedules, directions or contact details…"
                    />
                    <div className="mt-2 flex justify-end">
                      <Button
                        variant="gold"
                        className="px-3 py-1.5 text-xs"
                        disabled={busy}
                        onClick={() => void saveReply(inquiry)}
                      >
                        {busy ? 'Saving…' : 'Save reply'}
                      </Button>
                    </div>
                  </div>

                  {inquiry.coordinator_reply ? (
                    <p className="text-[11px] text-slate-400">
                      Last reply saved: {inquiry.coordinator_reply}
                    </p>
                  ) : null}
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
