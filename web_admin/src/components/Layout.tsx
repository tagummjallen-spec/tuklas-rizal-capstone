import { useState } from 'react';
import type { ReactNode } from 'react';
import { Icon } from './Icon';
import { Badge } from './ui';
import {
  NAV_ITEMS,
  TIER_LABELS,
  isProvincial,
  type ViewKey,
} from '../lib/rbac';
import type { Municipality, UserProfile } from '../types';

interface LayoutProps {
  profile: UserProfile;
  active: ViewKey;
  onNavigate: (view: ViewKey) => void;
  municipalities: Municipality[];
  onSignOut: () => void;
  children: ReactNode;
}

export function Layout({
  profile,
  active,
  onNavigate,
  municipalities,
  onSignOut,
  children,
}: LayoutProps) {
  const [mobileOpen, setMobileOpen] = useState(false);

  const items = NAV_ITEMS.filter((item) => item.visible(profile));
  const activeItem = items.find((item) => item.key === active) ?? items[0];
  const municipality = municipalities.find((m) => m.id === profile.municipality_id);
  const scopeLabel = isProvincial(profile)
    ? `Province-wide · ${municipalities.length || 14} municipalities`
    : municipality?.name ?? 'Municipality not assigned';
  const roleLabel = TIER_LABELS[profile.role_tier] ?? 'LGU Staff';
  const initials =
    profile.full_name
      .split(' ')
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase() ?? '')
      .join('') || 'TR';

  const sidebar = (
    <div className="flex h-full flex-col bg-forest text-white">
      <div className="flex items-center gap-3 px-5 py-5">
        <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-gold text-forest">
          <Icon name="pois" className="h-5 w-5" />
        </span>
        <div>
          <p className="text-base font-bold leading-tight">TuklasRizal</p>
          <p className="text-[11px] uppercase tracking-widest text-white/60">
            LGU Web Admin
          </p>
        </div>
      </div>

      <div className="mx-5 rounded-lg bg-white/5 px-3 py-2.5">
        <p className="text-[10px] font-semibold uppercase tracking-widest text-white/50">
          Access scope
        </p>
        <p className="mt-0.5 text-sm font-medium text-white">{scopeLabel}</p>
        <p className="mt-0.5 text-[11px] text-gold">{roleLabel}</p>
      </div>

      <nav className="mt-6 flex-1 space-y-1 px-3">
        {items.map((item) => {
          const selected = item.key === active;
          return (
            <button
              key={item.key}
              type="button"
              onClick={() => {
                onNavigate(item.key);
                setMobileOpen(false);
              }}
              className={`flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-left text-sm font-medium transition ${
                selected
                  ? 'bg-gold text-forest shadow-sm'
                  : 'text-white/75 hover:bg-white/10 hover:text-white'
              }`}
            >
              <Icon name={item.icon} className="h-5 w-5" />
              {item.label}
            </button>
          );
        })}
      </nav>

      <div className="border-t border-white/10 px-4 py-4">
        <div className="flex items-center gap-3">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-gold text-xs font-bold text-forest">
            {initials}
          </span>
          <div className="min-w-0">
            <p className="truncate text-sm font-semibold">{profile.full_name}</p>
            <p className="truncate text-[11px] text-white/60">{profile.email}</p>
          </div>
        </div>
        <button
          type="button"
          onClick={onSignOut}
          className="mt-3 flex w-full items-center gap-2 rounded-lg px-2 py-2 text-xs font-semibold text-white/70 transition hover:bg-white/10 hover:text-white"
        >
          <Icon name="logout" className="h-4 w-4" />
          Sign out
        </button>
      </div>
    </div>
  );

  return (
    <div className="flex min-h-screen bg-surface">
      <aside className="hidden w-64 shrink-0 lg:block">
        <div className="fixed inset-y-0 left-0 w-64">{sidebar}</div>
      </aside>

      {mobileOpen ? (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div
            className="absolute inset-0 bg-forest/50 backdrop-blur-sm"
            onClick={() => setMobileOpen(false)}
            role="presentation"
          />
          <div className="absolute inset-y-0 left-0 w-72 shadow-2xl">{sidebar}</div>
        </div>
      ) : null}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 flex flex-wrap items-center justify-between gap-3 border-b border-slate-200 bg-white/90 px-4 py-3 backdrop-blur sm:px-6">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => setMobileOpen(true)}
              className="rounded-lg p-2 text-forest hover:bg-forest-soft lg:hidden"
              aria-label="Open navigation"
            >
              <Icon name="menu" />
            </button>
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-widest text-slate-400">
                TuklasRizal · Province of Rizal
              </p>
              <h2 className="text-lg font-bold text-forest">
                {activeItem?.label ?? 'Overview Dashboard'}
              </h2>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Badge tone="green">{roleLabel}</Badge>
            <Badge tone="gold">{scopeLabel}</Badge>
            <span className="hidden text-xs text-slate-500 sm:inline">
              {profile.is_approved ? 'Approved LGU account' : 'Pending approval'}
            </span>
          </div>
        </header>

        <main className="flex-1 px-4 py-6 sm:px-6 lg:px-8">{children}</main>

        <footer className="border-t border-slate-200 bg-white px-4 py-4 text-center text-[11px] text-slate-400 sm:px-6">
          TuklasRizal — LGU Web Admin Portal · Discover Culture, Arts &amp; Tourism in
          Rizal
        </footer>
      </div>
    </div>
  );
}
