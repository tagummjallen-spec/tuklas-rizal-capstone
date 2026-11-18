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
  Textarea,
} from '../components/ui';
import { describeError, supabase } from '../lib/supabase';
import {
  canFeatureEvents,
  canReviewEvents,
  forcedEventStatus,
  isProvincial,
  municipalityScope,
} from '../lib/rbac';
import {
  fmtDate,
  fromDateTimeInput,
  numOr,
  numOrNull,
  toDateTimeInput,
} from '../lib/format';
import type { Lookups } from '../hooks/useLookups';
import type { EventRecord, EventStatus, UserProfile } from '../types';

interface EventsPageProps {
  profile: UserProfile;
  lookups: Lookups;
}

interface EventFormState {
  id: string | null;
  title: string;
  description: string;
  venue_name: string;
  how_to_get_there: string;
  municipality_id: string;
  barangay_id: string;
  category_id: string;
  start_date: string;
  end_date: string;
  latitude: string;
  longitude: string;
  status: EventStatus;
  is_featured: boolean;
  promotion_weight: string;
}

function buildEmptyForm(profile: UserProfile, lookups: Lookups): EventFormState {
  const now = new Date();
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  return {
    id: null,
    title: '',
    description: '',
    venue_name: '',
    how_to_get_there: '',
    municipality_id:
      profile.municipality_id ?? lookups.municipalities[0]?.id ?? '',
    barangay_id: profile.role_tier <= 1 ? profile.barangay_id ?? '' : '',
    category_id: '',
    start_date: toDateTimeInput(now.toISOString()),
    end_date: toDateTimeInput(tomorrow.toISOString()),
    latitude: '',
    longitude: '',
    status: forcedEventStatus(profile) ?? 'draft',
    is_featured: false,
    promotion_weight: '1.00',
  };
}

function statusTone(status: EventStatus): 'green' | 'gold' | 'red' {
  if (status === 'approved') return 'green';
  if (status === 'rejected') return 'red';
  return 'gold';
}

export default function EventsPage({ profile, lookups }: EventsPageProps) {
  const provincial = isProvincial(profile);
  const reviewer = canReviewEvents(profile);
  const canFeature = canFeatureEvents(profile);
  const scope = municipalityScope(profile);

  const [events, setEvents] = useState<EventRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<'all' | EventStatus>('all');

  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<EventFormState>(() =>
    buildEmptyForm(profile, lookups),
  );
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  const filters = useMemo(() => {
    const value: Record<string, string> = {};
    if (scope) value.municipality_id = scope;
    return value;
  }, [scope]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const { data, error: loadError } = await supabase
      .from('events')
      .select('*')
      .match(filters)
      .order('start_date', { ascending: true });

    if (loadError) setError(describeError(loadError));
    setEvents((data ?? []) as EventRecord[]);
    setLoading(false);
  }, [filters]);

  useEffect(() => {
    void load();
  }, [load]);

  const visibleEvents =
    statusFilter === 'all'
      ? events
      : events.filter((event) => event.status === statusFilter);

  const municipalityName = (id: string) =>
    lookups.municipalities.find((municipality) => municipality.id === id)?.name ??
    'Unassigned';
  const categoryName = (id: string | null) =>
    lookups.categories.find((category) => category.id === id)?.name ?? 'General';
  const barangayName = (id: string | null) =>
    lookups.barangays.find((barangay) => barangay.id === id)?.name ?? 'Municipality-wide';

  const formBarangays = lookups.barangays.filter(
    (barangay) => barangay.municipality_id === form.municipality_id,
  );

  const openCreate = () => {
    setForm(buildEmptyForm(profile, lookups));
    setFormError(null);
    setOpen(true);
  };

  const openEdit = (event: EventRecord) => {
    setForm({
      id: event.id,
      title: event.title,
      description: event.description ?? '',
      venue_name: event.venue_name ?? '',
      how_to_get_there: event.how_to_get_there ?? '',
      municipality_id: event.municipality_id,
      barangay_id: event.barangay_id ?? '',
      category_id: event.category_id ?? '',
      start_date: toDateTimeInput(event.start_date),
      end_date: toDateTimeInput(event.end_date),
      latitude: event.latitude === null ? '' : String(event.latitude),
      longitude: event.longitude === null ? '' : String(event.longitude),
      status: event.status,
      is_featured: event.is_featured,
      promotion_weight: String(event.promotion_weight ?? 1),
    });
    setFormError(null);
    setOpen(true);
  };

  const save = async () => {
    setFormError(null);

    if (!form.title.trim()) return setFormError('Event title is required.');
    if (!form.municipality_id) return setFormError('Select a municipality.');
    if (!form.start_date || !form.end_date) {
      return setFormError('Start and end date/time are required.');
    }

    const start = fromDateTimeInput(form.start_date);
    const end = fromDateTimeInput(form.end_date);
    if (!start || !end) return setFormError('Invalid date/time value.');
    if (new Date(end).getTime() < new Date(start).getTime()) {
      return setFormError('End date/time must be on or after the start.');
    }

    const payload = {
      municipality_id: form.municipality_id,
      barangay_id: form.barangay_id || null,
      category_id: form.category_id || null,
      title: form.title.trim(),
      description: form.description.trim() || null,
      venue_name: form.venue_name.trim() || null,
      how_to_get_there: form.how_to_get_there.trim() || null,
      start_date: start,
      end_date: end,
      latitude: numOrNull(form.latitude),
      longitude: numOrNull(form.longitude),
      status: forcedEventStatus(profile) ?? form.status,
      is_featured: form.is_featured,
      promotion_weight: numOr(form.promotion_weight, 1),
    };

    setSaving(true);
    const { error: saveError } = form.id
      ? await supabase.from('events').update(payload).eq('id', form.id)
      : await supabase.from('events').insert(payload);

    if (saveError) {
      setFormError(describeError(saveError));
    } else {
      setOpen(false);
      await load();
    }
    setSaving(false);
  };

  const setStatus = async (event: EventRecord, status: EventStatus) => {
    if (!reviewer) return;
    setActionError(null);
    const { error: updateError } = await supabase
      .from('events')
      .update({ status })
      .eq('id', event.id);
    if (updateError) setActionError(describeError(updateError));
    await load();
  };

  const toggleFeatured = async (event: EventRecord) => {
    if (!canFeature) return;
    setActionError(null);
    const { error: updateError } = await supabase
      .from('events')
      .update({ is_featured: !event.is_featured })
      .eq('id', event.id);
    if (updateError) setActionError(describeError(updateError));
    await load();
  };

  return (
    <div>
      <PageHeader
        title="Events Management"
        subtitle={
          reviewer
            ? 'Create cultural, festival and civic events, then approve or reject submissions.'
            : 'Barangay Officials create draft events; the Municipal Tourism Coordinator approves and publishes them.'
        }
        actions={
          <Button onClick={openCreate}>
            <Icon name="plus" className="h-4 w-4" />
            Create event
          </Button>
        }
      />

      {!reviewer ? (
        <div className="mb-4">
          <Alert tone="info">
            Tier 1 accounts create <strong>draft</strong> events only. A Tourism
            Coordinator (Tier 2) reviews and approves them before they appear in the
            TuklasRizal mobile app.
          </Alert>
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

      <Card>
        <div className="flex flex-wrap items-center gap-2 border-b border-slate-200 px-4 py-3">
          {(['all', 'draft', 'approved', 'rejected'] as const).map((value) => (
            <button
              key={value}
              type="button"
              onClick={() => setStatusFilter(value)}
              className={`rounded-full px-3 py-1.5 text-xs font-semibold uppercase tracking-wide transition ${
                statusFilter === value
                  ? 'bg-forest text-white'
                  : 'bg-surface text-slate-500 hover:text-forest'
              }`}
            >
              {value === 'all' ? `All (${events.length})` : value}
            </button>
          ))}
          <span className="ml-auto text-xs text-slate-400">
            {provincial ? 'Province-wide' : municipalityName(scope ?? '')} ·{' '}
            {visibleEvents.length} shown
          </span>
        </div>

        {loading ? (
          <LoadingPanel label="Loading events…" />
        ) : visibleEvents.length === 0 ? (
          <EmptyState
            title="No events in this view"
            description="Create an event or adjust the status filter."
            action={
              <Button variant="outline" onClick={openCreate}>
                Create event
              </Button>
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead className="table-head">
                <tr>
                  <th className="px-4 py-3">Event</th>
                  <th className="px-4 py-3">Municipality / Barangay</th>
                  <th className="px-4 py-3">Category</th>
                  <th className="px-4 py-3">Schedule</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 bg-white">
                {visibleEvents.map((event) => {
                  const editable = reviewer || event.status === 'draft';
                  return (
                    <tr key={event.id} className="align-top hover:bg-surface/60">
                      <td className="px-4 py-3">
                        <div className="flex items-start gap-2">
                          {event.is_featured ? (
                            <span className="mt-0.5 text-gold" title="Featured">
                              <Icon name="promote" className="h-4 w-4" />
                            </span>
                          ) : null}
                          <div>
                            <p className="font-semibold text-slate-800">{event.title}</p>
                            <p className="text-[11px] text-slate-400">
                              {event.venue_name ?? 'Venue to be announced'}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-slate-600">
                        <p>{municipalityName(event.municipality_id)}</p>
                        <p className="text-[11px] text-slate-400">
                          {barangayName(event.barangay_id)}
                        </p>
                      </td>
                      <td className="px-4 py-3 text-slate-600">
                        {categoryName(event.category_id)}
                      </td>
                      <td className="px-4 py-3 text-slate-600">
                        <p>{fmtDate(event.start_date)}</p>
                        <p className="text-[11px] text-slate-400">
                          to {fmtDate(event.end_date)}
                        </p>
                      </td>
                      <td className="px-4 py-3">
                        <Badge tone={statusTone(event.status)}>{event.status}</Badge>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex flex-wrap justify-end gap-1.5">
                          {editable ? (
                            <Button
                              variant="ghost"
                              className="px-2 py-1 text-xs"
                              onClick={() => openEdit(event)}
                            >
                              <Icon name="edit" className="h-3.5 w-3.5" />
                              Edit
                            </Button>
                          ) : null}
                          {reviewer && event.status !== 'approved' ? (
                            <Button
                              variant="outline"
                              className="px-2 py-1 text-xs"
                              onClick={() => void setStatus(event, 'approved')}
                            >
                              <Icon name="check" className="h-3.5 w-3.5" />
                              Approve
                            </Button>
                          ) : null}
                          {reviewer && event.status !== 'rejected' ? (
                            <Button
                              variant="danger"
                              className="px-2 py-1 text-xs"
                              onClick={() => void setStatus(event, 'rejected')}
                            >
                              <Icon name="close" className="h-3.5 w-3.5" />
                              Reject
                            </Button>
                          ) : null}
                          {canFeature ? (
                            <Button
                              variant="ghost"
                              className="px-2 py-1 text-xs"
                              onClick={() => void toggleFeatured(event)}
                            >
                              {event.is_featured ? 'Unfeature' : 'Feature'}
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
      </Card>

      <Modal
        open={open}
        title={form.id ? 'Edit Event' : 'Create Event'}
        subtitle={
          forcedEventStatus(profile)
            ? 'Saved as a draft for Tourism Coordinator approval.'
            : 'Publish cultural, festival and civic events across your municipality.'
        }
        onClose={() => setOpen(false)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void save()} disabled={saving}>
              {saving ? 'Saving…' : form.id ? 'Save changes' : 'Create event'}
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          {formError ? <Alert tone="error">{formError}</Alert> : null}

          <Field label="Event title" required>
            <Input
              value={form.title}
              onChange={(event) => setForm({ ...form, title: event.target.value })}
              placeholder="Higantes Festival Grand Parade"
            />
          </Field>

          <Field label="Description">
            <Textarea
              rows={3}
              value={form.description}
              onChange={(event) =>
                setForm({ ...form, description: event.target.value })
              }
              placeholder="Annual celebration honoring San Clemente…"
            />
          </Field>

          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Municipality" required>
              <Select
                value={form.municipality_id}
                disabled={!provincial}
                onChange={(event) =>
                  setForm({
                    ...form,
                    municipality_id: event.target.value,
                    barangay_id: '',
                  })
                }
              >
                <option value="">Select municipality</option>
                {lookups.municipalities.map((municipality) => (
                  <option key={municipality.id} value={municipality.id}>
                    {municipality.name}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label="Barangay" hint={provincial ? 'Optional' : 'Optional scope'}>
              <Select
                value={form.barangay_id}
                disabled={profile.role_tier <= 1}
                onChange={(event) =>
                  setForm({ ...form, barangay_id: event.target.value })
                }
              >
                <option value="">Municipality-wide</option>
                {formBarangays.map((barangay) => (
                  <option key={barangay.id} value={barangay.id}>
                    {barangay.name}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label="Category">
              <Select
                value={form.category_id}
                onChange={(event) =>
                  setForm({ ...form, category_id: event.target.value })
                }
              >
                <option value="">Uncategorised</option>
                {lookups.categories.map((category) => (
                  <option key={category.id} value={category.id}>
                    {category.name}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label="Venue">
              <Input
                value={form.venue_name}
                onChange={(event) =>
                  setForm({ ...form, venue_name: event.target.value })
                }
                placeholder="Angono Municipal Plaza"
              />
            </Field>

            <Field label="Start date & time" required>
              <Input
                type="datetime-local"
                value={form.start_date}
                onChange={(event) =>
                  setForm({ ...form, start_date: event.target.value })
                }
              />
            </Field>

            <Field label="End date & time" required>
              <Input
                type="datetime-local"
                value={form.end_date}
                onChange={(event) =>
                  setForm({ ...form, end_date: event.target.value })
                }
              />
            </Field>

            <Field label="Latitude" hint="Optional, e.g. 14.5266">
              <Input
                inputMode="decimal"
                value={form.latitude}
                onChange={(event) =>
                  setForm({ ...form, latitude: event.target.value })
                }
              />
            </Field>

            <Field label="Longitude" hint="Optional, e.g. 121.1536">
              <Input
                inputMode="decimal"
                value={form.longitude}
                onChange={(event) =>
                  setForm({ ...form, longitude: event.target.value })
                }
              />
            </Field>

            <Field
              label="Promotion weight"
              hint="Used by “Promote Towns and Events” (0.5 – 2.0)."
            >
              <Input
                type="number"
                min="0.5"
                max="2"
                step="0.05"
                value={form.promotion_weight}
                onChange={(event) =>
                  setForm({ ...form, promotion_weight: event.target.value })
                }
              />
            </Field>

            <Field
              label="Status"
              hint={
                reviewer
                  ? 'Approved events appear in the mobile app.'
                  : 'Tier 1 submissions are always drafts.'
              }
            >
              <Select
                value={forcedEventStatus(profile) ?? form.status}
                disabled={Boolean(forcedEventStatus(profile))}
                onChange={(event) =>
                  setForm({ ...form, status: event.target.value as EventStatus })
                }
              >
                <option value="draft">Draft</option>
                <option value="approved">Approved</option>
                <option value="rejected">Rejected</option>
              </Select>
            </Field>
          </div>

          <Field label="How to Get There" hint="Commute or driving instructions for tourists.">
            <Textarea
              rows={3}
              value={form.how_to_get_there}
              onChange={(event) =>
                setForm({ ...form, how_to_get_there: event.target.value })
              }
              placeholder="Ride a jeepney or UV Express bound for Angono from Shaw Blvd or Cubao…"
            />
          </Field>

          {canFeature ? (
            <label className="flex items-center gap-2 rounded-lg border border-slate-200 px-3 py-2 text-sm text-slate-700">
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-slate-300 text-forest focus:ring-forest"
                checked={form.is_featured}
                onChange={(event) =>
                  setForm({ ...form, is_featured: event.target.checked })
                }
              />
              Feature this event in the mobile app
            </label>
          ) : null}
        </div>
      </Modal>
    </div>
  );
}
