import type { UserProfile } from '../types';

/**
 * TuklasRizal 4-tier LGU RBAC.
 *  1 Barangay Official        — barangay/municipality scope, drafts only
 *  2 Tourism Coordinator      — municipal scope, approves events, POIs, inquiries
 *  3 Mayor / Municipal IT     — municipal scope, full municipal management
 *  4 Governor / Provincial IT — province-wide, LGU approvals, promotion weights
 */
export const TIER_LABELS: Record<number, string> = {
  0: 'Resident & Tourist',
  1: 'Barangay Official',
  2: 'Tourism Coordinator',
  3: 'Mayor / Municipal IT Admin',
  4: 'Governor / Provincial IT Admin',
};

export function roleTitleFor(tier: number): string {
  return TIER_LABELS[tier] ?? TIER_LABELS[0];
}

/**
 * Effective approval check. The live `public.users` table stores
 * `is_approved`; the optional audit migration adds `approval_status`. Accept
 * either signal so Google / email LGU sign-ins are gated consistently even
 * before that migration is applied.
 */
export function isApprovedProfile(profile: UserProfile): boolean {
  return profile.is_approved === true || profile.approval_status === 'approved';
}

/** Province-wide oversight — every municipality is in scope. */
export function isProvincial(profile: UserProfile): boolean {
  return profile.role_tier >= 4;
}

/** Tier 1 writes drafts; tiers 2–4 review and publish. */
export function canReviewEvents(profile: UserProfile): boolean {
  return profile.role_tier >= 2;
}

export function canFeatureEvents(profile: UserProfile): boolean {
  return profile.role_tier >= 2;
}

/** POIs, unique foods and logistics are managed from tier 2 up. */
export function canManagePois(profile: UserProfile): boolean {
  return profile.role_tier >= 2;
}

/** Coordinator inbox is a tier 2+ responsibility. */
export function canHandleInquiries(profile: UserProfile): boolean {
  return profile.role_tier >= 2;
}

/** Municipal Civic Broadcasts (tier 3+). */
export function canBroadcast(profile: UserProfile): boolean {
  return profile.role_tier >= 3;
}

/** Tier 4 only: LGU account approvals + promotion weights. */
export function canAdministerProvince(profile: UserProfile): boolean {
  return profile.role_tier >= 4;
}

/** Tier 4 only: assign municipality + access level, approve or revoke. */
export function canApproveUsers(profile: UserProfile): boolean {
  return profile.role_tier >= 4 && isApprovedProfile(profile);
}

/** Human-readable access level, e.g. "Level 2 — Tourism Coordinator". */
export function accessLevelLabel(tier: number): string {
  const level = Math.min(Math.max(tier, 0), 4);
  return `Level ${level <= 1 ? 1 : level} — ${TIER_LABELS[level] ?? TIER_LABELS[0]}`;
}

/** Tier 1 events are always created as drafts. */
export function forcedEventStatus(profile: UserProfile): 'draft' | null {
  return profile.role_tier <= 1 ? 'draft' : null;
}

/** Municipality scope filter; null means province-wide (tier 4). */
export function municipalityScope(profile: UserProfile): string | null {
  return isProvincial(profile) ? null : profile.municipality_id;
}

/** Tier 1 also narrows the event list to their own barangay. */
export function barangayScope(profile: UserProfile): string | null {
  return profile.role_tier <= 1 ? profile.barangay_id : null;
}

export interface NavItem {
  key: ViewKey;
  label: string;
  icon: IconKey;
  visible: (profile: UserProfile) => boolean;
}

export type ViewKey =
  | 'dashboard'
  | 'events'
  | 'pois'
  | 'inquiries'
  | 'promote'
  | 'users';

export type IconKey =
  | 'dashboard'
  | 'events'
  | 'pois'
  | 'inquiries'
  | 'promote'
  | 'logout'
  | 'plus'
  | 'check'
  | 'close'
  | 'edit'
  | 'broadcast'
  | 'shield'
  | 'image'
  | 'menu'
  | 'users';

export const NAV_ITEMS: NavItem[] = [
  { key: 'dashboard', label: 'Overview Dashboard', icon: 'dashboard', visible: () => true },
  { key: 'events', label: 'Events Management', icon: 'events', visible: () => true },
  { key: 'pois', label: 'POIs, Foods & Logistics', icon: 'pois', visible: () => true },
  {
    key: 'inquiries',
    label: 'Coordinator Inquiries',
    icon: 'inquiries',
    visible: canHandleInquiries,
  },
  {
    key: 'promote',
    label: 'Promote Towns and Events',
    icon: 'promote',
    visible: canAdministerProvince,
  },
  {
    key: 'users',
    label: 'Admin & User Approvals',
    icon: 'users',
    visible: canAdministerProvince,
  },
];
