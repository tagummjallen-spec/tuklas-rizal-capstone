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
  Textarea,
} from '../components/ui';
import { describeError, supabase } from '../lib/supabase';
import {
  canBroadcast,
  canHandleInquiries,
  canReviewEvents,
  isProvincial,
  municipalityScope,
  type ViewKey,
} from '../lib/rbac';
import { fmtDate } from '../lib/format';
import type { Lookups } from '../hooks/useLookups';
import type {
  CoordinatorInquiry,
  EventRecord,
  PoiRecord,
  UserProfile,
} from '../types';

interface DashboardPageProps {
  profile: UserProfile;
  lookups: Lookups;
  onNavigate: (view: ViewKey) => void;
}

const BROADCAST_TITLE_MAX = 120;
const BROADCAST_MESSAGE_MAX = 1000;

interface KpiProps {
  label: string;
  value: number | string;
  hint: string;
  tone?: 'forest' | 'gold' | 'slate';
}

function KpiCard({ label, value, hint, tone = 'forest' }: KpiProps) {
  const valueColor =
    tone === 'gold' ? 'text-[#a67f00]' : tone === 'slate' ? 'text-slate-700' : 'text-forest';
  return (
    <Card className="p-5">
      <p className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
        {label}
      </p>
      <p className={`mt-2 text-3xl font-bold ${valueColor}`}>{value}</p>
      <p className="mt-1 text-xs text-slate-500">{hint}</p>
    </Card>
  );
}

export default function DashboardPage({
  profile,
  lookups,
  onNavigate,
}: DashboardPageProps) {
  const scope = municipalityScope(profile);
  const provincial = isProvincial(profile);

  const [events, setEvents] = useState<EventRecord[]>([]);
  const [pois, setPois] = useState<PoiRecord[]>([]);
  const [inquiries, setInquiries] = useState<CoordinatorInquiry[]>([]);
  const [rsvpCount, setRsvpCount] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [broadcastOpen, setBroadcastOpen] = useState(false);
  const [broadcastTitle, setBroadcastTitle] = useState('');
  const [broadcastMessage, setBroadcastMessage] = useState('');
  const [broadcastVenue, setBroadcastVenue] = useState('');
  const [broadcasting, setBroadcasting] = useState(false);
  const [broadcastError, setBroadcastError] = useState<string | null>(null);
  const [broadcastDone, setBroadcastDone] = useState<string | null>(null);
  const [reviewNotice, setReviewNotice] = useState<string | null>(null);
  const [reviewError, setReviewError] = useState<string | null>(null);
  const [reviewingId, setReviewingId] = useState<string | null>(null);

  const filters = useMemo(() => {
    const value: Record<string, string> = {};
    if (scope) value.municipality_id = scope;
    return value;
  }, [scope]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const eventsRequest = supabase
        .from('events')
        .select('*')
        .match(filters)
        .order('created_at', { ascending: false });
      const poisRequest = supabase.from('pois_logistics').select('*').match(filters);

      const inquiriesRequest = canHandleInquiries(profile)
        ? supabase
            .from('coordinator_inquiries')
            .select('*')
            .match(filters)
            .order('created_at', { ascending: false })
        : Promise.resolve({ data: [] as CoordinatorInquiry[], error: null });

      const [eventsResult, poisResult, inquiriesResult] = await Promise.all([
        eventsRequest,
        poisRequest,
        inquiriesRequest,
      ]);

      const firstError =
        eventsResult.error ?? poisResult.error ?? inquiriesResult.error ?? null;
      setError(firstError ? describeError(firstError) : null);
      setEvents((eventsResult.data ?? []) as EventRecord[]);
      setPois((poisResult.data ?? []) as PoiRecord[]);
      setInquiries((inquiriesResult.data ?? []) as CoordinatorInquiry[]);

      if (provincial) {
        const { count, error: participationError } = await supabase
          .from('event_participation')
          .select('*', { count: 'exact', head: true });
        setRsvpCount(participationError ? null : count ?? 0);
      } else {
        setRsvpCount(null);
      }
    } catch (caught) {
      setError(describeError(caught));
    } finally {
      setLoading(false);
    }
  }, [filters, profile, provincial]);

  useEffect(() => {
    void load();
  }, [load]);

  const reviewer = canReviewEvents(profile);

  const reviewEvent = async (
    event: EventRecord,
    status: 'approved' | 'rejected',
  ) => {
    setReviewingId(event.id);
    setReviewError(null);
    setReviewNotice(null);
    try {
      const { error: updateError } = await supabase
        .from('events')
        .update({ status })
        .eq('id', event.id);

      if (updateError) {
        setReviewError(describeError(updateError));
      } else {
        setReviewNotice(
          status === 'approved'
            ? `“${event.title}” approved and published to the mobile app.`
            : `“${event.title}” rejected. The submitting barangay can revise and resubmit.`,
        );
        await load();
      }
    } catch (caught) {
      setReviewError(describeError(caught));
    } finally {
      setReviewingId(null);
    }
  };

  const approvedEvents = events.filter((event) => event.status === 'approved');
  const pendingEvents = events.filter((event) => event.status === 'draft');
  const openInquiries = inquiries.filter((inquiry) => inquiry.status === 'open');

  const distribution = lookups.municipalities
    .map((municipality) => ({
      name: municipality.name,
      count: approvedEvents.filter((event) => event.municipality_id === municipality.id)
        .length,
    }))
    .filter((row) => row.count > 0)
    .sort((a, b) => b.count - a.count);

  const maxCount = Math.max(1, ...distribution.map((row) => row.count));

  const submitBroadcast = async () => {
    setBroadcastError(null);
    setBroadcastDone(null);

    try {
      if (!profile.municipality_id) {
        setBroadcastError('Your account has no municipality assigned.');
        return;
      }
      const title = broadcastTitle.trim();
      const message = broadcastMessage.trim();
      if (!title || !message) {
        setBroadcastError('Add a broadcast title and message.');
        return;
      }
      if (title.length > BROADCAST_TITLE_MAX || message.length > BROADCAST_MESSAGE_MAX) {
        setBroadcastError(
          `Keep the title under ${BROADCAST_TITLE_MAX} characters and the message under ${BROADCAST_MESSAGE_MAX} characters.`,
        );
        return;
      }

      setBroadcasting(true);
      const civicCategory =
        lookups.categories.find((category) => category.slug === 'civic-community') ??
        lookups.categories.find((category) => category.slug?.includes('civic'));

      const now = new Date();
      const end = new Date(now.getTime() + 24 * 60 * 60 * 1000);

      const { error: insertError } = await supabase.from('events').insert({
        municipality_id: profile.municipality_id,
        barangay_id: profile.barangay_id,
        category_id: civicCategory?.id ?? null,
        title: `Civic Broadcast: ${title}`,
        description: message,
        venue_name: broadcastVenue.trim() || null,
        how_to_get_there: null,
        start_date: now.toISOString(),
        end_date: end.toISOString(),
        latitude: null,
        longitude: null,
        status: 'approved',
        is_featured: true,
        promotion_weight: 1.2,
      });

      if (insertError) {
        setBroadcastError(describeError(insertError));
      } else {
        setBroadcastDone(
          'Civic broadcast published as an approved, featured civic event for your municipality.',
        );
        setBroadcastTitle('');
        setBroadcastMessage('');
        setBroadcastVenue('');
        await load();
      }
    } catch (caught) {
      setBroadcastError(describeError(caught));
    } finally {
      setBroadcasting(false);
    }
  };

  return (
    <div>
      <PageHeader
        title={`Welcome, ${profile.full_name.split(' ')[0]}`}
        subtitle={
          provincial
            ? 'Province-wide tourism overview across the 14 municipalities of Rizal.'
            : `Municipal overview for ${lookups.municipalities.find((m) => m.id === profile.municipality_id)?.name ?? 'your municipality'}.`
        }
        actions={
          <>
            <Button variant="outline" onClick={() => onNavigate('events')}>
              <Icon name="events" className="h-4 w-4" />
              Manage events
            </Button>
            {canBroadcast(profile) ? (
              <Button variant="gold" onClick={() => setBroadcastOpen(true)}>
                <Icon name="broadcast" className="h-4 w-4" />
                Civic broadcast
              </Button>
            ) : null}
          </>
        }
      />

      {error ? (
        <div className="mb-4">
          <Alert tone="error">{error}</Alert>
        </div>
      ) : null}
      {reviewNotice ? (
        <div className="mb-4">
          <Alert tone="success">{reviewNotice}</Alert>
        </div>
      ) : null}
      {reviewError ? (
        <div className="mb-4">
          <Alert tone="error">{reviewError}</Alert>
        </div>
      ) : null}

      {loading ? (
        <LoadingPanel label="Loading municipal metrics…" />
      ) : (
        <div className="space-y-6">
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <KpiCard
              label="Total Approved Events"
              value={approvedEvents.length}
              hint={provincial ? 'Across all municipalities' : 'In your municipality'}
            />
            <KpiCard
              label="Pending Approvals"
              value={pendingEvents.length}
              hint="Draft events awaiting Tourism Coordinator review"
              tone="gold"
            />
            <KpiCard
              label="Open Coordinator Inquiries"
              value={canHandleInquiries(profile) ? openInquiries.length : '—'}
              hint="Tourist messages awaiting a first response"
              tone="slate"
            />
            <KpiCard
              label="Active POIs"
              value={pois.length}
              hint="Heritage sites, foods, destinations and logistics"
            />
            {provincial && rsvpCount !== null ? (
              <KpiCard
                label="Province-wide RSVPs"
                value={rsvpCount}
                hint="Event participation records"
                tone="slate"
              />
            ) : null}
          </div>

          <div className="grid gap-6 xl:grid-cols-[1.4fr_1fr]">
            <Card className="p-5">
              <div className="mb-4 flex items-center justify-between">
                <div>
                  <h2 className="text-sm font-bold uppercase tracking-wider text-forest">
                    Municipal Event Distribution
                  </h2>
                  <p className="mt-1 text-xs text-slate-500">
                    Approved cultural, festival and civic events per municipality.
                  </p>
                </div>
                <Badge tone="green">{approvedEvents.length} approved</Badge>
              </div>

              {distribution.length === 0 ? (
                <EmptyState
                  title="No approved events yet"
                  description="Approved events will be charted here by municipality."
                  action={
                    <Button variant="outline" onClick={() => onNavigate('events')}>
                      Create an event
                    </Button>
                  }
                />
              ) : (
                <ul className="space-y-3">
                  {distribution.map((row) => (
                    <li key={row.name}>
                      <div className="mb-1 flex items-center justify-between text-xs font-medium text-slate-600">
                        <span>{row.name}</span>
                        <span className="font-semibold text-forest">{row.count}</span>
                      </div>
                      <div className="h-2.5 w-full overflow-hidden rounded-full bg-surface">
                        <div
                          className="h-full rounded-full bg-forest"
                          style={{ width: `${(row.count / maxCount) * 100}%` }}
                        />
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </Card>

            <Card className="p-5">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <h2 className="text-sm font-bold uppercase tracking-wider text-forest">
                    {reviewer ? 'Pending Approvals' : 'Latest Events'}
                  </h2>
                  <p className="mt-1 text-xs text-slate-500">
                    {reviewer
                      ? 'One-click approve or reject Tier 1 barangay drafts.'
                      : 'Most recently created records in your scope.'}
                  </p>
                </div>
                {reviewer && pendingEvents.length > 0 ? (
                  <Badge tone="gold">{pendingEvents.length} waiting</Badge>
                ) : null}
              </div>
              <ul className="mt-4 space-y-3">
                {(reviewer ? pendingEvents : events).slice(0, 5).map((event) => (
                  <li
                    key={event.id}
                    className="flex items-start justify-between gap-3 rounded-lg border border-slate-100 px-3 py-2"
                  >
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium text-slate-700">
                        {event.title}
                      </p>
                      <p className="text-[11px] text-slate-400">
                        {fmtDate(event.start_date)} ·{' '}
                        {lookups.municipalities.find((m) => m.id === event.municipality_id)
                          ?.name ?? 'Rizal'}
                      </p>
                    </div>
                    <div className="flex shrink-0 flex-col items-end gap-1.5">
                      <Badge
                        tone={
                          event.status === 'approved'
                            ? 'green'
                            : event.status === 'rejected'
                              ? 'red'
                              : 'gold'
                        }
                      >
                        {event.status}
                      </Badge>
                      {reviewer && event.status === 'draft' ? (
                        <div className="flex gap-1">
                          <Button
                            className="px-2 py-1 text-[11px]"
                            disabled={reviewingId === event.id}
                            onClick={() => void reviewEvent(event, 'approved')}
                          >
                            <Icon name="check" className="h-3 w-3" />
                            Approve
                          </Button>
                          <Button
                            variant="danger"
                            className="px-2 py-1 text-[11px]"
                            disabled={reviewingId === event.id}
                            onClick={() => void reviewEvent(event, 'rejected')}
                          >
                            <Icon name="close" className="h-3 w-3" />
                            Reject
                          </Button>
                        </div>
                      ) : null}
                    </div>
                  </li>
                ))}
                {(reviewer ? pendingEvents : events).length === 0 ? (
                  <li className="rounded-lg border border-dashed border-slate-200 px-3 py-6 text-center text-xs text-slate-400">
                    {reviewer
                      ? 'No draft events awaiting review.'
                      : 'No events yet.'}
                  </li>
                ) : null}
              </ul>
            </Card>
          </div>

          {canHandleInquiries(profile) ? (
            <Card className="p-5">
              <div className="mb-4 flex items-center justify-between">
                <div>
                  <h2 className="text-sm font-bold uppercase tracking-wider text-forest">
                    Coordinator Inbox
                  </h2>
                  <p className="mt-1 text-xs text-slate-500">
                    Tourist inquiries routed to your Tourism Coordinator office.
                  </p>
                </div>
                <Button variant="outline" onClick={() => onNavigate('inquiries')}>
                  Open inbox
                </Button>
              </div>
              {openInquiries.length === 0 ? (
                <p className="rounded-lg border border-dashed border-slate-200 px-3 py-6 text-center text-xs text-slate-400">
                  No open inquiries.
                </p>
              ) : (
                <ul className="space-y-2">
                  {openInquiries.slice(0, 4).map((inquiry) => (
                    <li
                      key={inquiry.id}
                      className="flex items-center justify-between gap-3 rounded-lg bg-surface/70 px-3 py-2"
                    >
                      <div className="min-w-0">
                        <p className="truncate text-sm font-medium text-slate-700">
                          {inquiry.subject}
                        </p>
                        <p className="text-[11px] text-slate-400">
                          {fmtDate(inquiry.created_at)} ·{' '}
                          {lookups.municipalities.find(
                            (m) => m.id === inquiry.municipality_id,
                          )?.name ?? 'Rizal'}
                        </p>
                      </div>
                      <Badge tone="gold">open</Badge>
                    </li>
                  ))}
                </ul>
              )}
            </Card>
          ) : null}
        </div>
      )}

      <Modal
        open={broadcastOpen}
        title="Municipal Civic Broadcast"
        subtitle="Publishes an approved, featured civic event to the TuklasRizal mobile feed for your municipality."
        onClose={() => {
          setBroadcastOpen(false);
          setBroadcastError(null);
          setBroadcastDone(null);
        }}
        width="max-w-xl"
        footer={
          <>
            <Button variant="ghost" onClick={() => setBroadcastOpen(false)}>
              Cancel
            </Button>
            <Button variant="gold" onClick={() => void submitBroadcast()} disabled={broadcasting}>
              {broadcasting ? 'Publishing…' : 'Publish broadcast'}
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          {broadcastError ? <Alert tone="error">{broadcastError}</Alert> : null}
          {broadcastDone ? <Alert tone="success">{broadcastDone}</Alert> : null}
          <Field label="Broadcast title" required hint={`Maximum ${BROADCAST_TITLE_MAX} characters.`}>
            <Input
              value={broadcastTitle}
              maxLength={BROADCAST_TITLE_MAX}
              onChange={(event) => setBroadcastTitle(event.target.value)}
              placeholder="Road closure for the Higantes parade"
            />
          </Field>
          <Field
            label="Message to residents and tourists"
            required
            hint={`Maximum ${BROADCAST_MESSAGE_MAX} characters.`}
          >
            <Textarea
              rows={4}
              value={broadcastMessage}
              maxLength={BROADCAST_MESSAGE_MAX}
              onChange={(event) => setBroadcastMessage(event.target.value)}
              placeholder="Poblacion streets will be closed from 6:00 AM to 12:00 NN…"
            />
          </Field>
          <Field label="Venue or affected area" hint="Optional. Shown as the event venue.">
            <Input
              value={broadcastVenue}
              onChange={(event) => setBroadcastVenue(event.target.value)}
              placeholder="Angono Municipal Plaza"
            />
          </Field>
        </div>
      </Modal>
    </div>
  );
}
