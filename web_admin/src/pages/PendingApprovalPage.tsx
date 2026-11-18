import { Icon } from '../components/Icon';
import { Badge, Button, Card } from '../components/ui';
import { TIER_LABELS } from '../lib/rbac';
import { fmtDateTime } from '../lib/format';
import type { Municipality, UserProfile } from '../types';

interface PendingApprovalPageProps {
  profile: UserProfile;
  municipalities: Municipality[];
  onSignOut: () => void;
}

export default function PendingApprovalPage({
  profile,
  municipalities,
  onSignOut,
}: PendingApprovalPageProps) {
  const municipality = municipalities.find((item) => item.id === profile.municipality_id);
  const roleLabel = TIER_LABELS[profile.role_tier] ?? 'LGU Staff';

  return (
    <div className="flex min-h-screen items-center justify-center bg-surface px-4 py-12">
      <div className="w-full max-w-xl">
        <div className="mb-6 flex items-center justify-center gap-3">
          <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-forest text-gold">
            <Icon name="pois" className="h-6 w-6" />
          </span>
          <div>
            <p className="text-lg font-bold text-forest">TuklasRizal</p>
            <p className="text-[10px] uppercase tracking-widest text-slate-400">
              LGU Web Admin Portal
            </p>
          </div>
        </div>

        <Card className="overflow-hidden">
          <div className="bg-gold px-6 py-5">
            <div className="flex items-center gap-3">
              <span className="rounded-full bg-forest/10 p-2 text-forest">
                <Icon name="shield" className="h-6 w-6" />
              </span>
              <div>
                <h1 className="text-lg font-bold text-forest">
                  Pending Provincial Admin Approval
                </h1>
                <p className="text-xs text-forest/70">
                  Your LGU account is registered but not yet approved.
                </p>
              </div>
            </div>
          </div>

          <div className="space-y-5 px-6 py-6">
            <p className="text-sm leading-relaxed text-slate-600">
              Thank you for registering, <strong>{profile.full_name}</strong>. The
              Governor / Provincial IT Admin reviews LGU staff requests before portal
              access is enabled. You will be able to sign in to the dashboard as soon as
              your account is approved.
            </p>

            <dl className="grid gap-3 rounded-lg border border-slate-200 bg-surface/60 p-4 text-sm sm:grid-cols-2">
              <div>
                <dt className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                  Account
                </dt>
                <dd className="mt-0.5 text-slate-700">{profile.email}</dd>
              </div>
              <div>
                <dt className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                  Requested role
                </dt>
                <dd className="mt-0.5 text-slate-700">{roleLabel}</dd>
              </div>
              <div>
                <dt className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                  Municipality
                </dt>
                <dd className="mt-0.5 text-slate-700">
                  {municipality?.name ?? 'Not assigned'}
                </dd>
              </div>
              <div>
                <dt className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                  Requested
                </dt>
                <dd className="mt-0.5 text-slate-700">{fmtDateTime(profile.created_at)}</dd>
              </div>
              <div className="sm:col-span-2">
                <dt className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                  Status
                </dt>
                <dd className="mt-1">
                  <Badge tone="gold">Pending approval</Badge>
                </dd>
              </div>
            </dl>

            <div className="rounded-lg border border-slate-200 px-4 py-3 text-xs text-slate-500">
              Need urgent access? Contact the Provincial Tourism Office or email the
              Provincial IT Admin with your registered address and LGU designation.
            </div>

            <div className="flex justify-end">
              <Button variant="outline" onClick={onSignOut}>
                <Icon name="logout" className="h-4 w-4" />
                Sign out
              </Button>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
