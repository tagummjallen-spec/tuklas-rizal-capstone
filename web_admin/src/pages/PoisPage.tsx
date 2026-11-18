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
import { canManagePois, isProvincial, municipalityScope } from '../lib/rbac';
import { numOrNull, titleCase } from '../lib/format';
import type { Lookups } from '../hooks/useLookups';
import { POI_TYPES } from '../types';
import type { PoiRecord, UserProfile } from '../types';

interface PoisPageProps {
  profile: UserProfile;
  lookups: Lookups;
}

interface PoiFormState {
  id: string | null;
  name: string;
  description: string;
  poi_type: string;
  category_id: string;
  municipality_id: string;
  barangay_id: string;
  how_to_get_there: string;
  operating_hours: string;
  entrance_fee: string;
  latitude: string;
  longitude: string;
  is_promoted: boolean;
}

function buildEmptyForm(profile: UserProfile, lookups: Lookups): PoiFormState {
  return {
    id: null,
    name: '',
    description: '',
    poi_type: 'heritage_site',
    category_id: '',
    municipality_id:
      profile.municipality_id ?? lookups.municipalities[0]?.id ?? '',
    barangay_id: '',
    how_to_get_there: '',
    operating_hours: '',
    entrance_fee: '',
    latitude: '',
    longitude: '',
    is_promoted: false,
  };
}

export default function PoisPage({ profile, lookups }: PoisPageProps) {
  const canManage = canManagePois(profile);
  const provincial = isProvincial(profile);
  const scope = municipalityScope(profile);

  const [pois, setPois] = useState<PoiRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [typeFilter, setTypeFilter] = useState<string>('all');

  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<PoiFormState>(() => buildEmptyForm(profile, lookups));
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
      .from('pois_logistics')
      .select('*')
      .match(filters)
      .order('name', { ascending: true });

    if (loadError) setError(describeError(loadError));
    setPois((data ?? []) as PoiRecord[]);
    setLoading(false);
  }, [filters]);

  useEffect(() => {
    void load();
  }, [load]);

  const visiblePois =
    typeFilter === 'all' ? pois : pois.filter((poi) => poi.poi_type === typeFilter);

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

  const openEdit = (poi: PoiRecord) => {
    setForm({
      id: poi.id,
      name: poi.name,
      description: poi.description ?? '',
      poi_type: poi.poi_type ?? 'heritage_site',
      category_id: poi.category_id ?? '',
      municipality_id: poi.municipality_id,
      barangay_id: poi.barangay_id ?? '',
      how_to_get_there: poi.how_to_get_there ?? '',
      operating_hours: poi.operating_hours ?? '',
      entrance_fee: poi.entrance_fee ?? '',
      latitude: poi.latitude === null ? '' : String(poi.latitude),
      longitude: poi.longitude === null ? '' : String(poi.longitude),
      is_promoted: poi.is_promoted,
    });
    setFormError(null);
    setOpen(true);
  };

  const save = async () => {
    setFormError(null);
    if (!form.name.trim()) return setFormError('POI name is required.');
    if (!form.municipality_id) return setFormError('Select a municipality.');

    const payload = {
      municipality_id: form.municipality_id,
      barangay_id: form.barangay_id || null,
      category_id: form.category_id || null,
      name: form.name.trim(),
      description: form.description.trim() || null,
      poi_type: form.poi_type || null,
      how_to_get_there: form.how_to_get_there.trim() || null,
      operating_hours: form.operating_hours.trim() || null,
      entrance_fee: form.entrance_fee.trim() || null,
      latitude: numOrNull(form.latitude),
      longitude: numOrNull(form.longitude),
      is_promoted: form.is_promoted,
    };

    setSaving(true);
    const { error: saveError } = form.id
      ? await supabase.from('pois_logistics').update(payload).eq('id', form.id)
      : await supabase.from('pois_logistics').insert(payload);

    if (saveError) {
      setFormError(describeError(saveError));
    } else {
      setOpen(false);
      await load();
    }
    setSaving(false);
  };

  const remove = async (poi: PoiRecord) => {
    if (!canManage) return;
    if (!window.confirm(`Delete “${poi.name}” from tourism logistics?`)) return;
    setActionError(null);
    const { error: deleteError } = await supabase
      .from('pois_logistics')
      .delete()
      .eq('id', poi.id);
    if (deleteError) setActionError(describeError(deleteError));
    await load();
  };

  const togglePromoted = async (poi: PoiRecord) => {
    if (!canManage) return;
    setActionError(null);
    const { error: updateError } = await supabase
      .from('pois_logistics')
      .update({ is_promoted: !poi.is_promoted })
      .eq('id', poi.id);
    if (updateError) setActionError(describeError(updateError));
    await load();
  };

  return (
    <div>
      <PageHeader
        title="POIs, Unique Foods & Logistics"
        subtitle="Heritage sites, destinations, unique Rizal foods, restaurants and tourism logistics."
        actions={
          canManage ? (
            <Button onClick={openCreate}>
              <Icon name="plus" className="h-4 w-4" />
              Add POI
            </Button>
          ) : null
        }
      />

      {!canManage ? (
        <div className="mb-4">
          <Alert tone="info">
            POI and logistics management is handled by the Municipal Tourism
            Coordinator (Tier 2) and above. You have read-only access.
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
          <button
            type="button"
            onClick={() => setTypeFilter('all')}
            className={`rounded-full px-3 py-1.5 text-xs font-semibold uppercase tracking-wide transition ${
              typeFilter === 'all'
                ? 'bg-forest text-white'
                : 'bg-surface text-slate-500 hover:text-forest'
            }`}
          >
            All ({pois.length})
          </button>
          {POI_TYPES.map((type) => (
            <button
              key={type}
              type="button"
              onClick={() => setTypeFilter(type)}
              className={`rounded-full px-3 py-1.5 text-xs font-semibold uppercase tracking-wide transition ${
                typeFilter === type
                  ? 'bg-forest text-white'
                  : 'bg-surface text-slate-500 hover:text-forest'
              }`}
            >
              {titleCase(type)}
            </button>
          ))}
          <span className="ml-auto text-xs text-slate-400">
            {provincial ? 'Province-wide' : municipalityName(scope ?? '')} ·{' '}
            {visiblePois.length} shown
          </span>
        </div>

        {loading ? (
          <LoadingPanel label="Loading POIs and logistics…" />
        ) : visiblePois.length === 0 ? (
          <EmptyState
            title="No POIs in this view"
            description="Add heritage sites, destinations, unique foods or logistics records."
            action={
              canManage ? (
                <Button variant="outline" onClick={openCreate}>
                  Add POI
                </Button>
              ) : undefined
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead className="table-head">
                <tr>
                  <th className="px-4 py-3">Place</th>
                  <th className="px-4 py-3">Type</th>
                  <th className="px-4 py-3">Municipality</th>
                  <th className="px-4 py-3">Hours / Fee</th>
                  <th className="px-4 py-3">Promoted</th>
                  <th className="px-4 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 bg-white">
                {visiblePois.map((poi) => (
                  <tr key={poi.id} className="align-top hover:bg-surface/60">
                    <td className="px-4 py-3">
                      <p className="font-semibold text-slate-800">{poi.name}</p>
                      <p className="text-[11px] text-slate-400">
                        {categoryName(poi.category_id)} · {barangayName(poi.barangay_id)}
                      </p>
                    </td>
                    <td className="px-4 py-3">
                      <Badge tone="slate">{titleCase(poi.poi_type ?? 'logistics')}</Badge>
                    </td>
                    <td className="px-4 py-3 text-slate-600">
                      {municipalityName(poi.municipality_id)}
                    </td>
                    <td className="px-4 py-3 text-slate-600">
                      <p>{poi.operating_hours ?? '—'}</p>
                      <p className="text-[11px] text-slate-400">
                        {poi.entrance_fee ? `Fee: ${poi.entrance_fee}` : 'Fee not set'}
                      </p>
                    </td>
                    <td className="px-4 py-3">
                      {poi.is_promoted ? (
                        <Badge tone="gold">Promoted</Badge>
                      ) : (
                        <Badge tone="slate">Standard</Badge>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap justify-end gap-1.5">
                        {canManage ? (
                          <>
                            <Button
                              variant="ghost"
                              className="px-2 py-1 text-xs"
                              onClick={() => openEdit(poi)}
                            >
                              <Icon name="edit" className="h-3.5 w-3.5" />
                              Edit
                            </Button>
                            <Button
                              variant="ghost"
                              className="px-2 py-1 text-xs"
                              onClick={() => void togglePromoted(poi)}
                            >
                              {poi.is_promoted ? 'Unpromote' : 'Promote'}
                            </Button>
                            <Button
                              variant="danger"
                              className="px-2 py-1 text-xs"
                              onClick={() => void remove(poi)}
                            >
                              <Icon name="close" className="h-3.5 w-3.5" />
                              Delete
                            </Button>
                          </>
                        ) : (
                          <span className="text-xs text-slate-400">Read only</span>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <Modal
        open={open}
        title={form.id ? 'Edit POI / Logistics' : 'Add POI / Logistics'}
        subtitle="Heritage sites, destinations, unique foods, restaurants and tourism logistics."
        onClose={() => setOpen(false)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void save()} disabled={saving}>
              {saving ? 'Saving…' : form.id ? 'Save changes' : 'Create POI'}
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          {formError ? <Alert tone="error">{formError}</Alert> : null}

          <Field label="Name" required>
            <Input
              value={form.name}
              onChange={(event) => setForm({ ...form, name: event.target.value })}
              placeholder="Balaw-Balaw Specialty Restaurant & Art Gallery"
            />
          </Field>

          <Field label="Description">
            <Textarea
              rows={3}
              value={form.description}
              onChange={(event) =>
                setForm({ ...form, description: event.target.value })
              }
              placeholder="Iconic Angono art gallery and restaurant famous for traditional Rizal cuisine…"
            />
          </Field>

          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="POI type" required>
              <Select
                value={form.poi_type}
                onChange={(event) => setForm({ ...form, poi_type: event.target.value })}
              >
                {POI_TYPES.map((type) => (
                  <option key={type} value={type}>
                    {titleCase(type)}
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

            <Field label="Barangay" hint="Optional">
              <Select
                value={form.barangay_id}
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

            <Field label="Operating hours">
              <Input
                value={form.operating_hours}
                onChange={(event) =>
                  setForm({ ...form, operating_hours: event.target.value })
                }
                placeholder="8:00 AM - 4:00 PM (Tue-Sun)"
              />
            </Field>

            <Field label="Entrance fee">
              <Input
                value={form.entrance_fee}
                onChange={(event) =>
                  setForm({ ...form, entrance_fee: event.target.value })
                }
                placeholder="Free or PHP 50"
              />
            </Field>

            <Field label="Latitude" hint="Optional">
              <Input
                inputMode="decimal"
                value={form.latitude}
                onChange={(event) =>
                  setForm({ ...form, latitude: event.target.value })
                }
              />
            </Field>

            <Field label="Longitude" hint="Optional">
              <Input
                inputMode="decimal"
                value={form.longitude}
                onChange={(event) =>
                  setForm({ ...form, longitude: event.target.value })
                }
              />
            </Field>
          </div>

          <Field label="How to Get There" hint="Commute instructions for visitors.">
            <Textarea
              rows={3}
              value={form.how_to_get_there}
              onChange={(event) =>
                setForm({ ...form, how_to_get_there: event.target.value })
              }
              placeholder="Along Manila East Road in Brgy. San Vicente, Angono…"
            />
          </Field>

          <label className="flex items-center gap-2 rounded-lg border border-slate-200 px-3 py-2 text-sm text-slate-700">
            <input
              type="checkbox"
              className="h-4 w-4 rounded border-slate-300 text-forest focus:ring-forest"
              checked={form.is_promoted}
              onChange={(event) =>
                setForm({ ...form, is_promoted: event.target.checked })
              }
            />
            Promote this place in the TuklasRizal discovery feed
          </label>
        </div>
      </Modal>
    </div>
  );
}
