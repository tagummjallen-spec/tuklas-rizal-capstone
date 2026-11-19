import { useEffect, useRef, useState } from 'react';
import { Alert, Button, Field, Input, Modal, Select, Spinner, Textarea } from './ui';
import { describeError, supabase } from '../lib/supabase';
import {
  MAX_VERIFICATION_BYTES,
  docFileName,
  uploadVerificationFile,
} from '../lib/verification';
import { accessLevelLabel } from '../lib/rbac';
import type { Municipality, UserProfile } from '../types';

interface AccessRequestModalProps {
  open: boolean;
  onClose: () => void;
  profile: UserProfile;
  municipalities: Municipality[];
  onSubmitted?: () => void;
}

/**
 * "Request Higher Access" form for Tier 1–3 accounts.
 *
 * Uploads verification documents to the private `admin-verification-docs`
 * bucket and writes the request fields on `public.users`, where the Level 4
 * reviewer inspects them in Admin & User Approvals.
 */
export function AccessRequestModal({
  open,
  onClose,
  profile,
  municipalities,
  onSubmitted,
}: AccessRequestModalProps) {
  const [fullName, setFullName] = useState(profile.full_name);
  const [tier, setTier] = useState(Math.min(Math.max(profile.role_tier + 1, 2), 4));
  const [municipalityId, setMunicipalityId] = useState(profile.municipality_id ?? '');
  const [department, setDepartment] = useState(profile.department_office ?? '');
  const [position, setPosition] = useState(profile.official_position ?? '');
  const [contact, setContact] = useState(profile.contact_number ?? '');
  const [reason, setReason] = useState('');
  const [files, setFiles] = useState<File[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    if (!open) return;
    setFullName(profile.full_name);
    setTier(Math.min(Math.max(profile.role_tier + 1, 2), 4));
    setMunicipalityId(profile.municipality_id ?? '');
    setDepartment(profile.department_office ?? '');
    setPosition(profile.official_position ?? '');
    setContact(profile.contact_number ?? '');
    setReason('');
    setFiles([]);
    setError(null);
    setDone(false);
    setBusy(false);
  }, [open, profile]);

  const addFiles = (list: FileList | null) => {
    if (!list) return;
    const next = [...files];
    for (const file of Array.from(list)) {
      if (file.size > MAX_VERIFICATION_BYTES) {
        setError(`${file.name} is larger than 10 MB.`);
        continue;
      }
      if (!/\.(jpe?g|png|webp|pdf)$/i.test(file.name)) {
        setError(`${file.name} must be a JPG, PNG, WEBP or PDF.`);
        continue;
      }
      if (next.length >= 3) {
        setError('Attach at most 3 verification documents.');
        break;
      }
      if (!next.some((item) => item.name === file.name && item.size === file.size)) {
        next.push(file);
      }
    }
    setFiles(next);
  };

  const submit = async () => {
    setError(null);
    if (fullName.trim().split(/\s+/).length < 2) {
      setError('Enter your full legal name (first and last name).');
      return;
    }
    if (!municipalityId) {
      setError('Select the municipality you represent.');
      return;
    }
    if (department.trim().length < 3) {
      setError('Enter your department or office name.');
      return;
    }
    if (position.trim().length < 2) {
      setError('Enter your official position or designation.');
      return;
    }
    if (contact.replace(/\D/g, '').length < 7) {
      setError('Enter a reachable government / LGU contact number.');
      return;
    }
    if (reason.trim().length < 20) {
      setError('Please write at least 20 characters of justification.');
      return;
    }
    if (files.length === 0) {
      setError('Attach at least one verification document (LGU ID or endorsement).');
      return;
    }

    setBusy(true);
    try {
      const paths: string[] = [];
      for (const file of files) {
        paths.push(await uploadVerificationFile(file, profile.id));
      }
      const municipality =
        municipalities.find((item) => item.id === municipalityId)?.name ?? municipalityId;

      const { error: updateError } = await supabase
        .from('users')
        .update({
          full_name: fullName.trim(),
          requested_role_tier: tier,
          requested_municipality: municipality,
          department_office: department.trim(),
          official_position: position.trim(),
          contact_number: contact.trim(),
          request_reason: reason.trim(),
          verification_doc_urls: paths,
          approval_status: 'pending',
          requested_at: new Date().toISOString(),
        })
        .eq('id', profile.id);

      if (updateError) throw new Error(describeError(updateError));

      setDone(true);
      onSubmitted?.();
    } catch (submitError) {
      setError(describeError(submitError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal
      open={open}
      title="Request higher access"
      subtitle={`${profile.full_name} · currently ${accessLevelLabel(profile.role_tier)}`}
      onClose={busy ? () => undefined : onClose}
      width="max-w-2xl"
      footer={
        done ? (
          <Button onClick={onClose}>Close</Button>
        ) : (
          <>
            <Button variant="ghost" onClick={onClose} disabled={busy}>
              Cancel
            </Button>
            <Button onClick={() => void submit()} disabled={busy}>
              {busy ? <Spinner className="h-4 w-4 border-white/40 border-t-white" /> : null}
              {busy ? 'Submitting…' : 'Submit request'}
            </Button>
          </>
        )
      }
    >
      {done ? (
        <div className="space-y-3">
          <Alert tone="success" title="Request submitted">
            The Governor / Provincial IT Admin will inspect your documents and
            verify your endorsement. Your access level stays unchanged until a
            decision is recorded.
          </Alert>
          <p className="text-sm text-slate-500">
            You can keep using the portal with your current permissions.
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {error ? <Alert tone="error">{error}</Alert> : null}

          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Full legal name" required>
              <Input
                value={fullName}
                onChange={(event) => setFullName(event.target.value)}
                placeholder="Juan Dela Cruz"
              />
            </Field>
            <Field label="Requested role tier" required>
              <Select
                value={String(tier)}
                onChange={(event) => setTier(Number(event.target.value))}
              >
                {[2, 3, 4].map((value) => (
                  <option key={value} value={value}>
                    {accessLevelLabel(value)}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label="Assigned municipality" required>
              <Select
                value={municipalityId}
                onChange={(event) => setMunicipalityId(event.target.value)}
              >
                <option value="">Select municipality</option>
                {municipalities.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.name}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label="Department / office name" required>
              <Input
                value={department}
                onChange={(event) => setDepartment(event.target.value)}
                placeholder="Municipal Tourism Office"
              />
            </Field>
            <Field label="Official position / designation" required>
              <Input
                value={position}
                onChange={(event) => setPosition(event.target.value)}
                placeholder="Tourism Officer II"
              />
            </Field>
            <Field label="Government / LGU contact number" required>
              <Input
                value={contact}
                onChange={(event) => setContact(event.target.value)}
                placeholder="0917 123 4567"
              />
            </Field>
          </div>

          <Field
            label="Justification / purpose"
            required
            hint="Explain your role in municipal tourism and what you will manage in TuklasRizal."
          >
            <Textarea
              rows={4}
              maxLength={500}
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              placeholder="I manage the municipal tourism calendar and will publish official events and advisories…"
            />
          </Field>

          <div>
            <p className="field-label">Verification documents</p>
            <input
              ref={fileInputRef}
              type="file"
              accept=".jpg,.jpeg,.png,.webp,.pdf,image/*,application/pdf"
              multiple
              className="hidden"
              onChange={(event) => {
                addFiles(event.target.files);
                if (fileInputRef.current) fileInputRef.current.value = '';
              }}
            />
            <div className="mt-1 flex flex-wrap items-center gap-2">
              <Button
                variant="outline"
                onClick={() => fileInputRef.current?.click()}
                disabled={files.length >= 3}
              >
                Attach document
              </Button>
              <span className="text-xs text-slate-400">
                JPG, PNG, WEBP or PDF · up to 10 MB each · max 3
              </span>
            </div>
            {files.length === 0 ? (
              <p className="mt-2 text-xs text-amber-700">
                At least one document (Official LGU ID, endorsement letter or
                authorization memo) is required.
              </p>
            ) : (
              <ul className="mt-2 space-y-1">
                {files.map((file, index) => (
                  <li
                    key={`${file.name}-${index}`}
                    className="flex items-center justify-between gap-3 rounded-lg border border-slate-200 px-3 py-2 text-xs"
                  >
                    <span className="truncate text-slate-600">{docFileName(file.name)}</span>
                    <button
                      type="button"
                      className="font-semibold text-red-600 hover:text-red-700"
                      onClick={() =>
                        setFiles((current) => current.filter((_, i) => i !== index))
                      }
                    >
                      Remove
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>

          <Alert tone="info">
            Documents are stored in a private bucket. Only you and the Level 4
            Provincial IT Admin can open them.
          </Alert>
        </div>
      )}
    </Modal>
  );
}
