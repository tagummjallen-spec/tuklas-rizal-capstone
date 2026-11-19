# TuklasRizal — System Documentation

**Project:** TuklasRizal: An LLM-Based Application for Culture, Arts and Tourism for the Province of Rizal
**Scope:** All 14 municipalities of the Province of Rizal
**Repository:** `tuklas-rizal-capstone` (monorepo)
**Document status:** Generated from the source code, SQL migrations and configuration actually present in this repository. Where the code and the SQL disagree, the discrepancy is called out explicitly.

---

## Table of Contents

1. [System Overview & Architecture](#1-system-overview--architecture)
2. [User Roles & 4-Tier Access Control Matrix](#2-user-roles--4-tier-access-control-matrix)
3. [Database Schema & Storage Architecture](#3-database-schema--storage-architecture)
4. [Core Functional Modules & User Flows](#4-core-functional-modules--user-flows)
5. [Environment Setup, Local Development & Deployment Guide](#5-environment-setup-local-development--deployment-guide)
6. [Appendix: Known Gaps & Operational Notes](#6-appendix-known-gaps--operational-notes)

---

## 1. System Overview & Architecture

### 1.1 What the system is

TuklasRizal is a provincial tourism platform for Rizal, Philippines. It has three deliverables in one monorepo:

| Component | Path | Stack | Primary users |
|---|---|---|---|
| Tourist Mobile / Web App | `mobile_app/` | Flutter (Dart), Riverpod, GoRouter, Supabase Flutter SDK | Residents, tourists, guests |
| LGU Web Admin Portal | `web_admin/` | React 18 + TypeScript + Vite + Tailwind CSS, `@supabase/supabase-js` | Barangay officials, Tourism Coordinators, Mayors / Municipal IT, Governor / Provincial IT |
| Backend | `supabase/` | PostgreSQL + pgvector, Supabase Auth, Supabase Storage, Row Level Security | — |

Supporting assets:

- `dataset/rizal_tourism_dataset.json` — JSON mirror of the full tourism seed.
- `docs/` — capstone requirements, AI workflow notes, deferred features.
- `supabase/seed.sql` — small demo dataset; `supabase/seed_full_rizal.sql` — full 14-municipality dataset.

### 1.2 High-level architecture

```
                        ┌──────────────────────────────────────────┐
                        │        Supabase Project (single)         │
                        │                                          │
   ┌──────────────┐     │  Auth (email/password, OTP, Google)      │     ┌──────────────────┐
   │ Flutter app  │────▶│  PostgreSQL  public schema + pgvector    │◀────│ React web admin  │
   │ mobile_app/  │     │  RLS on every public table               │     │ web_admin/       │
   │              │     │  Storage: tourism-media (public)         │     │                  │
   │ Riverpod     │     │           admin-verification-docs        │     │ Vite SPA,        │
   │ GoRouter     │     │           (private)                      │     │ browser anon key │
   └──────────────┘     │  Realtime streams (postgres_changes)     │     └──────────────────┘
        │               └──────────────────────────────────────────┘              │
        │                                                                        │
        ├── Google Maps deep links (url_launcher)                               │
        ├── Google Calendar template URL (url_launcher)                         │
        ├── Mail client (mailto: tourism office)                                │
        └── SharedPreferences (onboarding flags, saves, settings, reviews)      │
                                                                                └── Vercel / Netlify static hosting
```

Key architectural properties:

1. **Single backend, two clients.** Both clients talk directly to Supabase over HTTPS with the **publishable (anon) key**. There is no custom API server and no service-role key in either client. All authorization is enforced by PostgreSQL Row Level Security.
2. **No Edge Functions yet.** `supabase/functions/` exists but is empty. The RAG assistant performs retrieval client-side and uses a bundled offline knowledge base as fallback; the remote LLM hook (`_composeWithRemoteLlm`) currently returns `null`.
3. **Offline/mock mode.** The Flutter app checks `AppConstants.isSupabaseConfigured`. When credentials are placeholders, it never initializes Supabase and every service provider resolves to a mock implementation, so the UI runs without a backend.
4. **Detail/action routes are root-level.** `GoRouter` uses a `ShellRoute` for the five bottom-nav tabs and keeps everything else at root level, because pushing a shell-tab route from a root route breaks GoRouter's page-key reservation.
5. **Local-first user state.** Onboarding completion, guest interests, saved events/POIs, notification read marks, accessibility settings and community reviews live in `SharedPreferences`, then sync to Supabase where applicable.

### 1.3 Repository layout

```
mobile_app/                     Flutter app (Android, iOS, web, desktop shells)
  lib/
    core/                       constants, providers, router, theme, utils, shared widgets
    features/                   auth, onboarding, home, explore, events, saved,
                                coordinators, assistant, notifications, profile,
                                settings, submissions, contact, about
    models/                     EventItem, PoiLogistics, Municipality, UserProfile, ...
    services/                   auth, discovery, coordinator, storage, geofence,
                                rag_chat, saved_places, lookup
web_admin/
  src/
    App.tsx                     session → profile → approval → view switch
    components/                 Layout (sidebar, badge, sign-out modal), AccessRequestModal,
                                GalleryUpload, Icon, ui primitives
    context/AuthContext.tsx     Supabase session + public.users profile loading
    hooks/                      useLookups, usePendingApprovals
    lib/                        rbac, supabase client, storage, verification, format
    pages/                      Login, Dashboard, Events, Pois, Inquiries, Promote,
                                PendingApproval, UserApprovals
supabase/
  migrations/001_initial_schema.sql   tables, enums, indexes, RLS helpers & policies
  seed_full_rizal.sql                 full idempotent seed
  seed.sql                            small demo seed
  storage_policies.sql                tourism-media bucket + policies
  admin_user_approvals.sql            Level 4 columns, helpers, triggers, RLS, private bucket
  review_guardrails.sql               event_reviews table, unique + eligibility policies
dataset/rizal_tourism_dataset.json
docs/
```

### 1.4 Technology inventory (verified from manifests)

**Mobile (`mobile_app/pubspec.yaml`)**

| Package | Version | Purpose |
|---|---|---|
| `supabase_flutter` | ^2.7.0 | Auth, PostgREST, Realtime, Storage |
| `flutter_riverpod` | ^2.6.1 | State management and dependency injection |
| `go_router` | ^14.2.0 | Declarative navigation |
| `google_fonts` | ^6.2.1 | Typography |
| `geolocator` | ^13.0.1 | Location permission / coordinates (declared; coordinate calls are still TODO in `GeofenceService`) |
| `add_2_calendar` | ^3.1.1 | Declared dependency |
| `url_launcher` | ^6.3.1 | Google Maps, Google Calendar, mailto |
| `image_picker` | ^1.1.2 | JPG/PNG picking for verification documents and gallery uploads |
| `shared_preferences` | ^2.3.2 | Local persistence |
| `intl` | ^0.19.0 | Date formatting |

Dart SDK constraint: `^3.13.4`. Android application ID: `com.tuklasrizal.tuklas_rizal`.

**Web admin (`web_admin/package.json`)**

| Package | Version | Purpose |
|---|---|---|
| `react`, `react-dom` | ^18.3.1 | UI |
| `@supabase/supabase-js` | ^2.45.4 | Auth, PostgREST, Storage |
| `vite` | ^5.4.11 | Dev server / bundler |
| `typescript` | ~5.6.3 | Type checking (`tsc --noEmit` in build) |
| `tailwindcss` | ^3.4.17 | Styling (`postcss` + `autoprefixer`) |
| `@vitejs/plugin-react` | ^4.3.3 | JSX transform |

`npm run build` = `tsc --noEmit && vite build` → `dist/`.

---

## 2. User Roles & 4-Tier Access Control Matrix

### 2.1 Tier definitions

The canonical label map is `web_admin/src/lib/rbac.ts` (`TIER_LABELS`). `public.users.role_tier` is an **integer**, not an enum.

| Tier | Label in code | Scope | Mobile representation |
|---|---|---|---|
| **0** | Resident & Tourist | Province-wide read | Default for email/password and Google sign-ups in `mobile_app` |
| **1** | Barangay Official | Own barangay | Also used as the fallback label for new Google profiles in the mobile app |
| **2** | Tourism Coordinator | Own municipality | Default for `isLguStaff: true` sign-ups |
| **3** | Mayor / Municipal IT Admin | Own municipality | Registered through the web portal (Tier 2–4 options) |
| **4** | Governor / Provincial IT Admin | Province-wide (all 14 LGUs) | Assigned only by an existing Level 4 admin |

> The requirement document describes Level 1 as "Barangay Officials" and Level 2 as "Department Head (e.g., Tourism Office)". The UI uses **Tourism Coordinator** for Tier 2, per the binding Form I terminology rules (no generic "Admin"/"Event Organizer"; never the acronym "RZL").

### 2.2 Capability matrix (from `web_admin/src/lib/rbac.ts`)

| Capability | Helper | Tier required |
|---|---|---|
| Sign in to portal at all | `profile.is_approved` | Any tier, but must be approved |
| View Overview Dashboard | `NAV_ITEMS.dashboard` | 0+ (approved) |
| View Events Management | `NAV_ITEMS.events` | 0+ (approved) |
| Create event | `forcedEventStatus()` | Tier ≤ 1 is forced to `draft` |
| Approve / reject events | `canReviewEvents()` | ≥ 2 |
| Feature / unfeature events | `canFeatureEvents()` | ≥ 2 |
| Manage POIs, foods & logistics | `canManagePois()` | ≥ 2 |
| Handle coordinator inquiries | `canHandleInquiries()` | ≥ 2 |
| Municipal Civic Broadcasts | `canBroadcast()` | ≥ 3 |
| Promote Towns and Events weights | `canAdministerProvince()` | ≥ 4 |
| Admin & User Approvals | `canApproveUsers()` | 4 **and** `is_approved` |
| Province-wide scope | `isProvincial()` | ≥ 4 |
| Municipality scope filter | `municipalityScope()` | tiers 0–3 → own `municipality_id` |
| Barangay scope filter | `barangayScope()` | tier ≤ 1 → own `barangay_id` |

### 2.3 How tier and approval are stored and enforced

**Storage.** `public.users`:

- `role_tier INTEGER NOT NULL DEFAULT 1`
- `role_title TEXT` (denormalized display label)
- `is_approved BOOLEAN NOT NULL DEFAULT false`
- `municipality_id`, `barangay_id` (scope)

**Database helpers** (in `001_initial_schema.sql`):

```sql
public.current_user_role_tier()      -- SELECT role_tier FROM users WHERE id = auth.uid()
public.current_user_municipality_id()
public.current_user_barangay_id()
public.is_approved_staff()           -- role_tier >= 2 AND is_approved = true
```

**Level 4 helper** (in `admin_user_approvals.sql`):

```sql
public.is_level4_admin()             -- SECURITY DEFINER; role_tier >= 4 AND is_approved
```

`is_level4_admin()` is `SECURITY DEFINER` specifically so the `users` RLS policy can evaluate the caller's tier without recursing into the `users` policy itself.

**Application enforcement.**

- `web_admin/src/App.tsx` renders `PendingApprovalPage` for any authenticated profile with `is_approved = false`, so an unapproved account cannot reach any portal view.
- Visible nav items are filtered by `NAV_ITEMS[].visible(profile)`; the active view falls back to `dashboard` if the selected view is not permitted.
- Scope filters are applied to every list query via `.match(filters)` with `municipality_id` from `municipalityScope()`.

### 2.4 Level 4 document verification & approval workflow

This is the end-to-end lifecycle implemented across `mobile_app`, `web_admin` and `supabase/admin_user_approvals.sql`.

#### Step 1 — Applicant submits, or registers, and cannot self-approve

Three entry points exist:

1. **Web portal self-registration** (`web_admin/src/pages/LoginPage.tsx` + `AuthContext.signUp`): chooses a tier (2–4), municipality, and barangay for Tier 1; the `public.users` row is inserted with `is_approved = false`.
2. **Web portal "Request higher access"** (`components/AccessRequestModal.tsx`, available to every signed-in profile with `role_tier <= 3` from the sidebar): collects Full Legal Name, Requested Role Tier (2/3/4), municipality, Department/Office, Official Position, LGU contact number, justification, and verification documents.
3. **Mobile app "Apply as an LGU Coordinator"** (`mobile_app/lib/features/contact/pages/lgu_access_request_page.dart`, route `/lgu-access-request`): form + image upload + optional document link; offers a `mailto:` fallback to `AppConstants.tourismOfficeEmail`.

Documents are uploaded to the **private** bucket `admin-verification-docs` under `<user_id>/<timestamp>_<name>`:

- Web: `uploadVerificationFile()` in `web_admin/src/lib/verification.ts` — accepts `jpg/jpeg/png/webp/pdf`, ≤ 10 MB, sanitizes the filename.
- Mobile: `StorageService.uploadVerificationDocument()` — JPG/PNG through `image_picker`; returns the storage **path** (not a public URL).

The returned paths are written to `public.users.verification_doc_urls` (`text[]`), together with `requested_role_tier`, `requested_municipality`, `department_office`, `official_position`, `contact_number`, `request_reason`, `requested_at`, and `approval_status = 'pending'`.

**Self-approval guard.** RLS cannot restrict columns, and the applicant update policy (`applicant_update_own_request`, `auth.uid() = id`) would otherwise allow a crafted update. Trigger `trg_guard_user_self_update` → `guard_user_self_update()` runs `BEFORE UPDATE`: for a non-Level-4 caller updating their own row, it restores the previous `role_tier`, `role_title`, `is_approved`, `municipality_id`, `barangay_id`, `approved_at`, `approved_by`, and refuses any `approval_status` other than `pending`/`rejected`.

#### Step 2 — Level 4 reviews

`web_admin/src/pages/UserApprovalsPage.tsx` (nav: **Admin & User Approvals**, with a live pending-count badge):

- Loads all profiles with `select('*')`, ordered by `created_at`.
- Has a search box and status filters: All / Pending / Approved Admins (approved and `role_tier >= 2`).
- Stat cards: pending, approved admins, rejected, total.
- Per-row actions: **Inspect & Review**, plus approve / reject / revoke confirmation modals.

The **Inspect & Review** modal shows:

- Full profile: name, email, phone, requested tier, municipality, department/office, position, justification, requested date, current status.
- Every entry in `verification_doc_urls` through `DocumentViewer`:
  - absolute `http(s)` links are used as-is (e.g. a pasted Drive link);
  - storage paths are converted with `createSignedUrl(path, 3600)` (1-hour URL);
  - PDFs render in an `<iframe>`, images in `<img>`;
  - every document has an **Open full document / Download** link;
  - failures show a readable fallback explaining the file may still be uploading or the storage policy may not be applied.
- Verification checkboxes: **LGU ID verified** (`verified_lgu_id`) and **Endorsement verified** (`verified_endorsement`).
- Assignment controls: target tier (1–4) and municipality.
- Admin note / rejection reason (`review_notes`).

#### Step 3 — Decision

| Action | Payload written | Behaviour |
|---|---|---|
| **Approve & Assign Tier** | `is_approved: true`, `role_tier: <chosen>`, `role_title`, `municipality_id`, `approval_status: 'approved'`, `review_notes`, `verified_*` | Applicant gains portal access at the assigned tier |
| **Reject with Reason** | `is_approved: false`, `role_tier: 1`, `approval_status: 'rejected'`, `review_notes` | Requires a non-empty note; the applicant stays out of the portal |
| **Revoke Access** | `is_approved: false`, `role_tier: 1`, `approval_status: 'rejected'` | Demotes an existing admin immediately |

Every write is wrapped in `try/catch` with `describeError()` messages, and the parent `App.tsx` increments `pendingRefresh` via `onReviewed` so the sidebar badge reloads.

#### Step 4 — Audit

Trigger `trg_stamp_user_approval` → `stamp_user_approval()` fires `BEFORE UPDATE OF is_approved` and, when the flag changes, stamps `approved_at = now()`, `approved_by = auth.uid()`, and sets `approval_status` to `approved` (true) or `rejected` (false, unless still `pending`). This holds regardless of which client (portal, SQL editor, RPC) performs the change.

`users_approval_status_check` constrains `approval_status` to `('pending','approved','rejected')`; `users_approval_status_idx` indexes it.

#### Degraded mode

The portal tolerates an unapplied migration: `hasApprovalColumns(user)` checks `hasOwnProperty('approval_status')`. If the columns are absent, the UI derives status from `is_approved` and omits audit/request fields instead of failing with PostgREST `PGRST204`.

---

## 3. Database Schema & Storage Architecture

### 3.1 Extensions and enums

```sql
CREATE EXTENSION IF NOT EXISTS vector;     -- pgvector, VECTOR(768) embeddings
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()
```

| Enum | Labels |
|---|---|
| `event_status` | `draft`, `pending`, `approved`, `rejected`, `archived` |
| `participation_status` | `going`, `interested`, `attended` |
| `inquiry_status` | `open`, `in_progress`, `resolved`, `closed` |

> `001_initial_schema.sql` is explicitly documented as **reconstructed from the deployed production database** via PostgREST introspection. Table and column names/types match production; NOT NULL constraints, defaults, checks, indexes and RLS policies are reconstructed from observed behaviour and application code. Treat policy definitions as the intended security model and verify against the live project.

### 3.2 Table-by-table data dictionary

#### `public.municipalities` — the 14 municipalities of Rizal

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK, default `gen_random_uuid()` | |
| `name` | `TEXT NOT NULL UNIQUE` | |
| `slug` | `TEXT NOT NULL UNIQUE` | Seed joins on slug |
| `description` | `TEXT` | |
| `latitude`, `longitude` | `DOUBLE PRECISION` | Geofence centre |
| `geofence_radius_meters` | `INTEGER DEFAULT 5000` | Drives the welcome alert |
| `tourism_office_name` | `TEXT` | |
| `coordinator_contact_email` | `TEXT` | |
| `coordinator_contact_phone` | `TEXT` | |
| `tourism_office_address` | `TEXT` | |
| `visitor_priority_boost` | `NUMERIC(4,2) DEFAULT 1.00` | "Promote Towns and Events" weighting, production range 1.00–1.60 |
| `created_at` | `TIMESTAMPTZ NOT NULL DEFAULT now()` | |

No `province` or `is_active` column exists in production.

#### `public.barangays`

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `municipality_id` | `UUID NOT NULL → municipalities(id) ON DELETE CASCADE` | |
| `name` | `TEXT NOT NULL` | |
| `latitude`, `longitude` | `DOUBLE PRECISION` | |
| `created_at` | `TIMESTAMPTZ` | |
| Constraint | `UNIQUE (municipality_id, name)` (`barangays_municipality_id_name_key`) | |

The full seed does **not** insert barangays; the mobile app ships a sample `RizalBarangays.byMunicipality` map for its sub-filter, and the web portal reads real rows from this table.

#### `public.categories`

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `name` | `TEXT NOT NULL UNIQUE` | |
| `slug` | `TEXT NOT NULL UNIQUE` | Seeded slugs below |
| `icon_name` | `TEXT` | Production column is `icon_name`; there is no `color` |
| `description` | `TEXT` | |
| `created_at` | `TIMESTAMPTZ` | |

Seeded categories (`seed_full_rizal.sql`):

| Name | Slug |
|---|---|
| Cultural & Arts | `cultural-arts` |
| Festival | `festival` |
| Food & Heritage | `food-heritage` |
| Eco-Tourism & Nature | `eco-tourism` |
| Civic & Community | `civic-community` |
| Sports & Recreation | `sports-recreation` |

#### `public.users` — profiles; `id` is the Supabase Auth user id

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | Equals `auth.users.id`; there is no `auth_user_id` |
| `email` | `TEXT NOT NULL` | |
| `full_name` | `TEXT NOT NULL` | |
| `avatar_url` | `TEXT` | No `profile_image_url`; no `phone`; no `bio` (bio lives in auth metadata) |
| `role_tier` | `INTEGER NOT NULL DEFAULT 1` | 0–4 |
| `role_title` | `TEXT` | |
| `municipality_id` | `UUID → municipalities(id) ON DELETE SET NULL` | |
| `barangay_id` | `UUID → barangays(id) ON DELETE SET NULL` | |
| `is_approved` | `BOOLEAN NOT NULL DEFAULT false` | |
| `created_at`, `updated_at` | `TIMESTAMPTZ NOT NULL DEFAULT now()` | |

Columns added by `admin_user_approvals.sql` (all nullable / defaulted, added with `IF NOT EXISTS`):

| Column | Type | Purpose |
|---|---|---|
| `approval_status` | `TEXT DEFAULT 'pending'` | `pending` / `approved` / `rejected` |
| `approved_at` | `TIMESTAMPTZ` | Stamped by trigger |
| `approved_by` | `UUID` | `auth.uid()` of the deciding admin |
| `requested_role_tier` | `INTEGER` | Applicant's requested tier |
| `requested_municipality` | `TEXT` | Applicant's stated LGU |
| `department_office` | `TEXT` | |
| `official_position` | `TEXT` | |
| `contact_number` | `TEXT` | Official LGU number |
| `request_reason` | `TEXT` | Justification |
| `verification_doc_urls` | `TEXT[] DEFAULT '{}'` | Storage paths or absolute links |
| `review_notes` | `TEXT` | Admin note / rejection reason |
| `verified_lgu_id` | `BOOLEAN DEFAULT false` | Inspector checklist |
| `verified_endorsement` | `BOOLEAN DEFAULT false` | Inspector checklist |
| `requested_at` | `TIMESTAMPTZ` | |

Constraints/indexes: `users_approval_status_check`, `users_approval_status_idx`; plus `idx_users_municipality`, `idx_users_barangay`, `idx_users_role_tier`.

#### `public.user_interests`

| Column | Type | Notes |
|---|---|---|
| `user_id` | `UUID NOT NULL → users(id) ON DELETE CASCADE` | |
| `category_id` | `UUID NOT NULL → categories(id) ON DELETE CASCADE` | |
| `created_at` | `TIMESTAMPTZ` | |
| PK | `(user_id, category_id)` | One row per interest |

Written by `SupabaseAuthService.setUserInterests()`: delete-then-insert, resolving onboarding slugs and live UUIDs to real `categories.id` values.

#### `public.events`

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `municipality_id` | `UUID NOT NULL → municipalities(id) ON DELETE CASCADE` | |
| `barangay_id` | `UUID → barangays(id) ON DELETE SET NULL` | |
| `category_id` | `UUID → categories(id) ON DELETE SET NULL` | |
| `created_by` | `UUID → users(id) ON DELETE SET NULL` | Organizer identity — used by review anti-abuse |
| `approved_by` | `UUID → users(id) ON DELETE SET NULL` | |
| `title` | `TEXT NOT NULL` | |
| `description` | `TEXT` | |
| `venue_name` | `TEXT` | Replaces old `location`/`address` |
| `how_to_get_there` | `TEXT` | |
| `latitude`, `longitude` | `DOUBLE PRECISION` | |
| `start_date`, `end_date` | `TIMESTAMPTZ NOT NULL` | `CHECK (end_date >= start_date)` |
| `image_url` | `TEXT` | Public `tourism-media` URL |
| `status` | `event_status NOT NULL DEFAULT 'draft'` | |
| `is_featured` | `BOOLEAN NOT NULL DEFAULT false` | |
| `promotion_weight` | `NUMERIC(4,2) DEFAULT 1.00` | LGU promotion lever |
| `created_at`, `updated_at` | `TIMESTAMPTZ NOT NULL DEFAULT now()` | |

Indexes: `idx_events_municipality`, `idx_events_barangay`, `idx_events_category`, `idx_events_status`, `idx_events_dates (start_date, end_date)`.

#### `public.event_embeddings` — RAG semantic index

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `event_id` | `UUID NOT NULL UNIQUE → events(id) ON DELETE CASCADE` | |
| `embedding` | `VECTOR(768) NOT NULL` | Keep dimension in step with the embedding model |
| `created_at` | `TIMESTAMPTZ` | |

Internal to the RAG pipeline; readable only by approved staff.

#### `public.event_participation` — RSVP / attendance

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `user_id` | `UUID NOT NULL → users(id) ON DELETE CASCADE` | |
| `event_id` | `UUID NOT NULL → events(id) ON DELETE CASCADE` | |
| `status` | `participation_status NOT NULL DEFAULT 'interested'` | **`status`**, not `rsvp_status`; no `participated_at` |
| `created_at` | `TIMESTAMPTZ` | |
| Constraint | `UNIQUE (user_id, event_id)` | Enables `upsert(..., onConflict: 'user_id,event_id')` |

#### `public.pois_logistics` — heritage sites, foods, restaurants, destinations

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `municipality_id` | `UUID NOT NULL → municipalities(id) ON DELETE CASCADE` | |
| `barangay_id` | `UUID → barangays(id) ON DELETE SET NULL` | |
| `category_id` | `UUID → categories(id) ON DELETE SET NULL` | |
| `name` | `TEXT NOT NULL` | |
| `description` | `TEXT` | |
| `poi_type` | `TEXT` | `heritage_site`, `unique_food`, `restaurant`, `destination`, `logistics` |
| `address` | `TEXT` | |
| `how_to_get_there` | `TEXT` | |
| `operating_hours` | `TEXT` | |
| `entrance_fee` | `TEXT` | |
| `latitude`, `longitude` | `DOUBLE PRECISION` | |
| `image_url` | `TEXT` | |
| `is_promoted` | `BOOLEAN NOT NULL DEFAULT false` | |
| `created_at` | `TIMESTAMPTZ` | No `updated_at`, no `is_active` |

#### `public.coordinator_inquiries`

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `user_id` | `UUID NOT NULL → users(id) ON DELETE CASCADE` | |
| `municipality_id` | `UUID NOT NULL → municipalities(id) ON DELETE CASCADE` | |
| `subject` | `TEXT NOT NULL` | |
| `message` | `TEXT NOT NULL` | |
| `coordinator_reply` | `TEXT` | |
| `status` | `inquiry_status NOT NULL DEFAULT 'open'` | |
| `created_at`, `updated_at` | `TIMESTAMPTZ` | |

#### `public.event_reviews` — created by `review_guardrails.sql`

Not present in `001_initial_schema.sql`; provisioned by the guardrails migration and created `IF NOT EXISTS`, so it is optional to the app.

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `event_id` | `UUID NOT NULL → events(id) ON DELETE CASCADE` | |
| `user_id` | `UUID → users(id) ON DELETE CASCADE` | Nullable: legacy/seeded reviews may have no author id |
| `author_name` | `TEXT` | Display name kept by the mobile app |
| `rating` | `INTEGER NOT NULL DEFAULT 5` | `CHECK (rating BETWEEN 1 AND 5)` |
| `review_text` | `TEXT NOT NULL` | `CHECK (char_length(btrim(review_text)) BETWEEN 10 AND 500)` |
| `created_at` | `TIMESTAMPTZ NOT NULL DEFAULT now()` | |
| `updated_at` | `TIMESTAMPTZ DEFAULT now()` | |
| Constraint | `event_reviews_event_id_user_id_key UNIQUE (event_id, user_id)` | One review per user per event |
| Index | `event_reviews_event_idx (event_id)` | |

### 3.3 Row Level Security

RLS is enabled on **all ten schema tables plus `event_reviews`**. Policies below are as written in the repository.

#### Reference data

| Table | Policy | Rule |
|---|---|---|
| `municipalities` | `municipalities_select_public` | `SELECT USING (true)` |
| | `municipalities_manage_tier34` | `ALL` if `is_approved_staff()` and (tier = 4 or `id = current_user_municipality_id()`) |
| `barangays` | `barangays_select_public` | `SELECT USING (true)` |
| | `barangays_manage_tier234` | `ALL` if staff and (tier = 4 or own municipality) |
| `categories` | `categories_select_public` | `SELECT USING (true)` |
| | `categories_manage_tier4` | `ALL` if tier = 4 |

#### `users`

| Policy | Command | Rule |
|---|---|---|
| `users_select_own` | SELECT | `id = auth.uid()` |
| `users_select_staff` | SELECT | `is_approved_staff()` and (tier = 4 or same municipality) |
| `users_update_own` | UPDATE | `id = auth.uid()` (columns restricted by trigger) |
| `users_insert_self` | INSERT | `id = auth.uid()` |
| `level4_read_all_users` | SELECT | `is_level4_admin()` |
| `level4_update_users` | UPDATE | `is_level4_admin()` |
| `applicant_update_own_request` | UPDATE | `auth.uid() = id`; privileged columns forced back by `guard_user_self_update` |

#### Interests, events, participation, POIs, inquiries

| Table | Policy | Rule |
|---|---|---|
| `user_interests` | `user_interests_manage_own` | `ALL` where `user_id = auth.uid()` |
| `events` | `events_select_approved` | `status = 'approved'` **or** staff with tier 4 / own municipality |
| | `events_manage_staff` | `ALL` for staff with tier 4 / own municipality |
| `event_embeddings` | `event_embeddings_staff` | `ALL` for `is_approved_staff()` |
| `event_participation` | `event_participation_select_own` | own rows, or staff for events in their municipality / tier 4 |
| | `event_participation_manage_own` | `ALL` where `user_id = auth.uid()` |
| `pois_logistics` | `pois_select_public` | `SELECT USING (true)` |
| | `pois_manage_staff` | `ALL` for staff with tier 4 / own municipality |
| `coordinator_inquiries` | `inquiries_insert_own` | INSERT where `user_id = auth.uid()` |
| | `inquiries_select_own` | own rows, or staff for own municipality / tier 4 |
| | `inquiries_update_coordinator` | UPDATE for staff, own municipality / tier 4 |

#### `event_reviews` (`review_guardrails.sql`)

| Policy | Command | Rule |
|---|---|---|
| `event_reviews_public_read` | SELECT | `USING (true)` — reviews are public |
| `event_reviews_verified_insert` | INSERT | `auth.uid() = user_id` **and** `can_review_event(event_id)` **and** `rating BETWEEN 1 AND 5` **and** `char_length(btrim(review_text)) BETWEEN 10 AND 500` |
| `event_reviews_author_update` | UPDATE | `auth.uid() = user_id` and the same eligibility/length checks |
| `event_reviews_author_delete` | DELETE | `auth.uid() = user_id` or `is_level4_admin()` |

Eligibility helper:

```sql
public.can_review_event(target_event_id uuid) RETURNS boolean
  SECURITY DEFINER, STABLE
-- event exists AND events.created_by IS DISTINCT FROM auth.uid()
--             AND events.start_date <= now()
--             AND coalesce(status::text,'approved') <> 'cancelled'
-- AND an event_participation row exists with status = 'going'
```

`SECURITY DEFINER` lets the policy read `events` and `event_participation` regardless of the caller's row visibility. Execute is granted to `authenticated` and `service_role` only.

### 3.4 Storage buckets

| Bucket | Public | Size limit | MIME types | Folder convention | Defined in |
|---|---|---|---|---|---|
| `tourism-media` | **yes** | 5 MB | `image/jpeg`, `image/png`, `image/webp`, `image/gif` | `events/<timestamp>_<rand>.jpg`, `pois/…`, `avatars/…` | `storage_policies.sql` |
| `admin-verification-docs` | **no** | 10 MB | `image/jpeg`, `image/png`, `image/webp`, `application/pdf` | `<auth.uid()>/<timestamp>_<name>` | `admin_user_approvals.sql` |

**`tourism-media` policies**

| Policy | Command | Rule |
|---|---|---|
| `tourism_media_public_read` | SELECT | `bucket_id = 'tourism-media'` to `public` |
| `tourism_media_auth_insert` | INSERT | `bucket_id = 'tourism-media'` to `authenticated` |
| `tourism_media_auth_update` | UPDATE | same |
| `tourism_media_auth_delete` | DELETE | same |

Uploads return `getPublicUrl(path)`; the URL is stored in `events.image_url` / `pois_logistics.image_url`.

**`admin-verification-docs` policies**

| Policy | Command | Rule |
|---|---|---|
| `verification_docs_owner_insert` | INSERT | bucket matches **and** `(storage.foldername(name))[1] = auth.uid()::text` |
| `verification_docs_read` | SELECT | owner folder **or** `is_level4_admin()` |
| `verification_docs_owner_delete` | DELETE | owner folder **or** `is_level4_admin()` |

Reads are never public: the web portal converts stored paths into 1-hour signed URLs (`createSignedUrl(path, 3600)`), and the mobile app stores only the path.

### 3.5 Seed data

`supabase/seed_full_rizal.sql` is idempotent and contains:

| Data | Count | Idempotency strategy |
|---|---|---|
| Municipalities | 14 | Upsert on unique `slug` |
| Categories | 6 | Upsert on unique `slug` |
| Approved events | 28 | Insert only when no event with the same title exists in that municipality |
| POIs / logistics | 36 | Insert only when no POI with the same name exists in that municipality |

`supabase/seed.sql` is a smaller demo set (a few municipalities, events and POIs) for quick local work. Seeding is deliberately **not** part of the migration.

---

## 4. Core Functional Modules & User Flows

### 4.1 First-launch 4-step onboarding & interest-based recommendation engine

#### The four steps (`mobile_app/lib/features/onboarding/onboarding_flow.dart`)

Gated by `has_completed_onboarding` in `SharedPreferences`. `main.dart` awaits `onboardingController.load()` **before** `runApp`, so `GoRouter`'s redirect can read the flag synchronously. `appRouter` also uses `onboardingController` as `refreshListenable` and redirects any non-onboarding location to `/onboarding` while incomplete.

| Page | Index | Content | Action |
|---|---|---|---|
| Splash | 0 | Dark-green `#033300` screen, gold location-pin logo, "RIZAL / EVENTS / HUB" | Auto-advances after 2 s |
| Welcome | 1 | Higantes hero photo, "Welcome", "EXPLORE EVENTS IN YOUR AREA" | Pill button "Let's get started" |
| Interests | 2 | Masungi hero, "What are you interested in?", 8 selectable chips | "Continue" (disabled until ≥ 1 selected) persists interests |
| Complete | 3 | Cream background, elastic checkmark animation, "You're all set up!" | "Explore Events" → `onboard.complete()` |

Interest chips and the category slug each maps to:

| Chip | Slug |
|---|---|
| Festivals | `festival` |
| Food & Drink | `food-heritage` |
| Arts & Culture | `cultural-arts` |
| Music | `cultural-arts` |
| Workshops | `civic` |
| Sports | `sports` |
| Parades | `festival` |
| Heritage Sites | `cultural-arts` |

Persistence keys (`OnboardingController`): `has_completed_onboarding` (bool) and `tuklas_onboarding_interests_v1` (string list). `complete()` also syncs interests to `public.user_interests` if a session exists. `resetOnboarding()` clears the flag so Settings can replay the flow.

A second, signed-in-only interest screen (`InterestOnboardingPage`, route `/onboarding/interests`) presents the six seeded categories (`cultural`, `festival`, `civic`, `sports`, `health`, `food_heritage`) and writes them with `setUserInterests`. `main.dart` routes a signed-in user there once per session if `hasSavedInterests()` is false.

#### Recommendation path

`recommendedInterestCategoriesProvider` prefers live `public.user_interests` rows for a signed-in user and falls back to device-persisted onboarding interests for guests.

`mobile_app/lib/core/utils/interest_matcher.dart` (`resolveRecommendations`) normalizes every token shape into two lookup sets:

- `categoryIds` — live Supabase UUIDs plus seeded ids;
- `categoryNames` — lowercase display names.

It handles onboarding slugs, seeded ids (`cultural`, `sports`, …), legacy slugs and live UUIDs, with an alias table (`cultural-arts → cultural`, `civic-community → civic`, `sports-recreation → sports`, `eco-tourism → cultural`).

`SupabaseDiscoveryService.scorePromoteTownsAndEvents()` is the rule-based "Promote Towns and Events" engine:

| Signal | Score |
|---|---|
| Event category matches a user interest | +40 |
| Municipality never visited (`municipalityVisitCounts[id] == 0`) | +30 |
| Municipality visited fewer than 3 times | +15 |
| `is_featured` | +20 |
| `promotion_weight > 1.0` | `round((weight − 1.0) × 40)` |

Results are sorted descending by `promotedRank`. The feature is never labelled "Recommendations" in the UI — the binding title is **Promote Towns and Events**.

### 4.2 Authentication flows

Implemented in `mobile_app/lib/services/auth_service.dart` (`SupabaseAuthService` / `MockAuthService`), with UI in `features/auth/pages/login_screen.dart` and `login_page.dart`.

#### Google OAuth

```dart
signInWithOAuth(OAuthProvider.google,
  redirectTo: AppConstants.oauthRedirectUrl,
  authScreenLaunchMode: LaunchMode.externalApplication)
```

`oauthRedirectUrl` is `Uri.base.origin` on web and `io.supabase.tuklasrizal://login-callback` on mobile. `OAuthCallbackPage` (`/auth-callback`) reports the result. On the first authenticated event, `_createProfileFromAuthUser()` creates the `public.users` row (`role_tier = 1`, `role_title = 'Resident & Tourist'`, `is_approved = true`) from Google metadata (`full_name`/`name`, `avatar_url`/`picture`).

Register both redirect URLs in Supabase → Authentication → URL Configuration: `https://<domain>/**` and `io.supabase.tuklasrizal://login-callback`.

#### 6-digit Email OTP

- **Sign-up:** `signUp()` creates the auth user with metadata (`full_name`, `role_tier`, `role_title`). If Supabase returns no session (email confirmation on), `emailConfirmationRequired` is set and `SignupPage` advances to its OTP step (`_step = 1`). `verifySignupOtp()` calls `verifyOTP(type: OtpType.signup)` and then provisions the `public.users` row. `resendSignupOtp()` re-sends with a countdown timer in the UI.
- **Sign-in:** `sendLoginOtp()` calls `signInWithOtp(shouldCreateUser: false)`; `verifyLoginOtp()` calls `verifyOTP(type: OtpType.email)` and creates a profile if none exists.
- A password mode toggle in `LoginPage` switches to `signInWithPassword`.

Role defaults on sign-up: tourists/residents `role_tier = 0` with `is_approved = true`; LGU staff (`isLguStaff: true`) `role_tier = 2` with `is_approved = false` pending approval.

#### Guest mode

The app never forces a login wall. `core/utils/auth_gate.dart` exposes `requireSignIn(context, ref, action: ...)`, which shows a "Sign in required" dialog ("Sign in to <action>. Browsing events, places and the assistant stays free for guests.") with **Not now** / **Sign in**. It is used for RSVP, bookmarking, coordinator inquiries and review submission. Guests can browse events, POIs, municipalities, saved places (device-local) and the assistant.

#### Safety nets

- `_resolveCategoryIds()` and `loadUserInterestCategories()` catch failures so a missing lookup never blocks sign-up.
- `signIn()` converts Supabase's "email not confirmed" `AuthException` into a readable message.
- `ensureProfile()` is idempotent and is used to repair missing profile rows after email confirmation.

### 4.3 Event discovery, POI navigation, calendar deep-linking and reviews

#### Discovery (`services/discovery_service.dart`)

| Stream/Future | Query |
|---|---|
| `featuredEvents` | `events` realtime stream, `is_featured = true`, `status = 'approved'` |
| `promoteTownsAndEvents` | `events` realtime stream, `status = 'approved'` |
| `pois` | `pois_logistics` realtime stream |
| `municipalities` | `municipalities` realtime stream |
| `getEventsByMunicipality(id)` | `status = 'approved'`, ordered by `start_date` |
| `getPoisByMunicipality(id)` | by `municipality_id` |
| `searchEvents(q)` | `ilike('title', '%q%')`, approved only |

Every stream/future falls back to bundled seed records (Higantes Festival, Binangonan Petroglyphs, Taytay Tiangge, Balaw-Balaw, …) when the live table returns nothing, so the UI is never empty on a fresh project.

#### Navigation & maps

`core/utils/maps_launcher.dart` builds `https://www.google.com/maps/dir/?api=1&destination=<lat>,<lng>&travelmode=driving`, preferring coordinates and falling back to the venue/address string, then opening it with `LaunchMode.externalApplication`.

#### Google Calendar deep link

`event_detail_page.dart::_addToCalendar` builds a Google Calendar template URL and opens it externally:

```
https://calendar.google.com/calendar/render
  ?action=TEMPLATE
  &text=<title>
  &dates=<yyyyMMdd'T'HHmmss'Z'>/<end>       (UTC)
  &details=<description + how to get there + "Organized by the … Tourism Office.">
  &location=<venue, municipality, Rizal, Philippines>
```

If the end date is not after the start, start + 2 hours is used. Failure shows "Could not open Google Calendar on this device." (`add_2_calendar` is declared as a dependency but the implemented path is the Calendar URL.)

#### RSVP

`rsvpEvent(eventId, status, userId)` upserts `event_participation` with `onConflict: 'user_id,event_id'`; `removeRsvp()` deletes the row. Accepted statuses: `going`, `interested`, `attended`.

#### Attendance-verified review system

UI gate: `core/utils/review_guardrails.dart::evaluateReviewGate()`; banner: `core/widgets/review_status_banner.dart`; server authority: `supabase/review_guardrails.sql`.

Gate evaluation order and messages:

| # | Condition | Result |
|---|---|---|
| 1 | No signed-in user | Blocked — "Sign in to review this event and share your experience." |
| 2 | `event.createdBy == user.id` | Blocked — "Organizers can't review their own event. Thanks for hosting!" |
| 3 | `event.status == 'cancelled'` | Blocked — "This event was cancelled, so reviews are closed." |
| 4 | `event.startDate.isAfter(now)` | Blocked — "Reviews unlock once the event starts for attendees who marked 'I'm Going'." |
| 5 | Local RSVP status ≠ `'going'` | Blocked — "Only attendees who marked \"I'm Going\" can review this event. Update your RSVP on this page first." |
| 6 | Existing review by this user | Allowed in **edit** mode — "You already reviewed this event — saving will update your existing review instead of posting a duplicate." |
| 7 | Otherwise | Allowed — "Verified attendee — one review per event. Your feedback helps other travellers." |

Validation (`validateReviewText`): 10–500 characters after sanitization; rejects empty text, symbol-only text (< 3 letters), repeated characters (`(.)\1{4,}`) and any word repeated more than four times. `sanitizeReviewText` strips `<...>` tags, `<>{} \ $` backticks and collapses whitespace. `isValidRating` requires 1–5.

Persistence: `EventReviewsController.addReview()` is local-first (persists to `tuklas_event_reviews_v1`, inserts or replaces in memory so the UI updates immediately), then best-effort `upsert` into `public.event_reviews` with `onConflict: 'event_id,user_id'`, falling back to `insert`. A rejected write (table missing or policy denial) never loses the local review. `reviewByUser()` returns the current user's review so the sheet opens in "Edit Your Review" mode. Seeded demo reviews plus a base count of 679 provide social proof when the table is empty.

Server-side the same rules apply through `can_review_event()` plus the unique constraint, so a modified client cannot post a second review, review an unstarted event, review without a `going` RSVP, or review their own event.

#### Notifications

`features/notifications/notification_state.dart` derives notifications from live approved events — civic broadcasts (`status = 'approved'` + civic category), new events, and upcoming events — and persists read ids in `tuklas_notifications_read_v1` for the unread badge. There is no push notification service.

#### Conversational assistant

`services/rag_chat_service.dart`:

- `SupabaseRagChatService.retrieve()` reads `municipalities` (name, description, office contact), approved `events` (venue, how-to-get-there, dates) and `pois_logistics` (type, address, hours, fees), composes a grounded answer, and falls back to `OfflineRizalKnowledge` on any error, RLS denial or empty match.
- `useRemoteLlm` is constructed as `false` in `app_providers.dart`; `_composeWithRemoteLlm()` is the documented hook for a future Llama/Supabase Edge Function `/rag-chat` and currently returns `null`.
- `ChatMessage` carries `municipality` and `sources` for provenance chips.

#### Geofencing

`GeofenceService` computes haversine distance locally (no external math library) and resolves the containing municipality from the 14 hard-coded centres/radii (5 000 m each). Live GPS acquisition is still a documented TODO; `MockGeofenceService` plus the in-app `/geofence-simulator` page (`Simulate Geofence Entry (Dev)`) demonstrate the welcome alert, with a 5-minute re-notification guard.

### 4.4 LGU Web Admin workflows

The portal is a single-page app with view switching in `App.tsx` (no router); nav visibility comes from `NAV_ITEMS` in `rbac.ts`.

#### Session and profile bootstrap (`context/AuthContext.tsx`)

1. `supabase.auth.getSession()`; subscribe to `onAuthStateChange`.
2. Load `public.users` by `id` with `select('*')`.
3. If no row exists (email-confirmation registration), insert one from auth metadata with `is_approved: false`.
4. While `loading` → splash; on error → "Portal access error" card with Sign out / Retry; if `!is_approved` → `PendingApprovalPage`; else render `Layout`.

#### Overview Dashboard (`pages/DashboardPage.tsx`)

- KPIs: Total Approved Events, Pending Approvals (drafts), Open Coordinator Inquiries, Active POIs; province-wide RSVP count for Tier 4 (`event_participation` head count).
- Municipal event distribution bar chart (approved events per municipality, scoped).
- Pending approvals list with one-click **Approve** / **Reject** (`events.update({ status })`).
- Coordinator Inbox preview (Tier 2+).
- **Municipal Civic Broadcast** (Tier 3+): a modal that inserts an immediately `approved`, `is_featured: true`, `promotion_weight: 1.2` civic event titled `Civic Broadcast: <title>`, starting now and ending 24 hours later, using the `civic-community` (or any `civic`) category. This is the mechanism by which advisories appear in the mobile feed and notification inbox.

#### Event approval pipeline (`pages/EventsPage.tsx`)

1. Tier 1 (Barangay Official) creates an event; `forcedEventStatus(profile)` forces `status = 'draft'`, and the status selector is disabled.
2. Tiers 2–4 see drafts and approve or reject them (`status` update) — "Barangay Officials create draft events; the Municipal Tourism Coordinator approves and publishes them."
3. Tier 2+ can toggle `is_featured` ("Feature" / "Unfeature").
4. Event fields: municipality, barangay, category, title, description, venue, how-to-get-there, coordinates, start/end dates, image URL (via `GalleryUpload`), status, featured flag, promotion weight.
5. `municipalityScope()` restricts all lists and writes for non-provincial users; `barangayScope()` narrows Tier 1.

Only `status = 'approved'` events are publicly readable by the mobile app (RLS + client queries).

#### POIs, foods & logistics (`pages/PoisPage.tsx`)

Full CRUD on `pois_logistics` for Tier 2+ with municipality scoping, `poi_type` selection (`heritage_site`, `unique_food`, `destination`, `restaurant`, `logistics`), operating hours, entrance fee, how-to-get-there, coordinates and image upload. `is_promoted` is toggled inline and feeds the "Promote Towns and Events" ranking.

#### Coordinator inquiries (`pages/InquiriesPage.tsx`)

Tier 2+ inbox over `coordinator_inquiries` scoped by municipality. Coordinators write `coordinator_reply` and move `status` through `open → in_progress → resolved`. Tourists submit inquiries from the mobile Coordinator Directory (`/inquiry/:municipalityId`).

#### Promote Towns and Events (`pages/PromotePage.tsx`, Tier 4)

- Lists all 14 municipalities with their `visitor_priority_boost`; edits are persisted with `municipalities.update({ visitor_priority_boost })`.
- Shows per-municipality admin/user counts to support approval decisions.
- This screen is the provincial lever for steering traffic toward lesser-visited towns.

#### Admin & User Approvals (`pages/UserApprovalsPage.tsx`, Tier 4)

Described in full in [§2.4](#24-level-4-document-verification--approval-workflow). Sidebar badge count comes from `hooks/usePendingApprovals.ts`, which counts unapproved profiles and refreshes when a review completes (`pendingRefresh` in `App.tsx`).

#### Sign-out confirmation

Both clients confirm before ending a session:

- Web (`components/Layout.tsx`): modal "Sign out of the portal?" — "Are you sure you want to sign out of TuklasRizal LGU Web Admin? Any unsaved draft will be discarded." with **Cancel** / **Sign Out**.
- Mobile (`core/utils/logout_confirmation.dart::confirmAndSignOut`): used by `settings_page.dart` and `profile_page.dart`, clearing local controllers after sign-out.

#### Error handling conventions

- `lib/supabase.ts::describeError()` normalizes `{message, details, hint, code}` into one readable sentence; missing env vars throw at module load with an explicit instruction.
- Every page wraps loads and writes in `try/catch` and renders `<Alert tone="error">` rather than throwing.
- `types.ts` documents that unknown columns cause PostgREST `PGRST204`, and optional approval columns are typed `?` so the portal works pre-migration.

### 4.5 Mobile supporting modules

| Feature | Location | Notes |
|---|---|---|
| Home / Discovery Hub | `features/home/pages/home_page.dart` | Hero carousel, featured events, Promote Towns and Events, municipality & barangay filters, category chips |
| Explore | `features/explore/pages/explore_page.dart` | POI/destination browsing; `PoiDetailPage`, `DirectionsPage` live here |
| Events | `features/events/pages/events_page.dart` | List + filters; `EventDetailPage` handles RSVP, calendar, maps, reviews |
| Saved | `features/saved/pages/saved_page.dart` | Device-persisted bookmarks for guests and users |
| Coordinators | `features/coordinators/pages/coordinators_page.dart` | Tourism Coordinator directory, `InquiryPage` |
| Assistant | `features/assistant/pages/assistant_page.dart` | Chat UI over RAG service |
| Profile / Settings | `features/profile`, `features/settings` | Accessibility (text scale, high contrast), notification toggles, replay onboarding, About, Contact, LGU access request, logout |
| Submit content | `features/submissions/pages/submit_content_page.dart` | `/submit/:type` gallery upload into `tourism-media` |
| About | `features/about/pages/about_page.dart` | Platform overview, mission, features, governance, data privacy |
| Contact | `features/contact/pages/contact_us_page.dart` | Tourism office details, LGU access request entry, `mailto:` action |
| LGU access request | `features/contact/pages/lgu_access_request_page.dart` | Applicant form + document upload |

**Routing map** (`core/router/app_router.dart`): shell tabs `/`, `/explore`, `/events`, `/saved`, `/profile` (navigate with `context.go`); root routes `/login`, `/signup`, `/settings`, `/notifications`, `/contact`, `/about`, `/lgu-access-request`, `/auth-callback`, `/submit/:type`, `/onboarding`, `/onboarding/interests`, `/poi/:id`, `/directions`, `/event/:id`, `/inquiry/:municipalityId`, `/geofence-simulator` (navigate with `context.push`). `/coordinators` and `/assistant` remain registered as shell branches even though they are not in the five-item bottom bar.

---

## 5. Environment Setup, Local Development & Deployment Guide

### 5.1 Prerequisites

| Tool | Version | Needed for |
|---|---|---|
| Flutter SDK | 3.13+ / Dart 3.13 (repo constraint `^3.13.4`) | `mobile_app` |
| Node.js | 18+ | `web_admin` |
| npm | 9+ | `web_admin` |
| Supabase project | hosted or CLI-local | backend |
| Supabase CLI (optional) | latest | local stack, `db reset` |
| Git Bash / POSIX shell | — | documented commands use POSIX syntax |

### 5.2 Required configuration keys

**Mobile — `mobile_app/lib/core/constants/app_constants.dart`**

| Constant | Purpose |
|---|---|
| `supabaseUrl` | `https://<project-ref>.supabase.co` |
| `supabaseAnonKey` | Publishable/anon key |
| `oauthRedirectUrl` | Derived: `Uri.base.origin` (web) or `io.supabase.tuklasrizal://login-callback` (mobile) |
| `tourismOfficeEmail` | `tourismoffice@rizalprovincialgov.ph` — mailto fallback |
| `tourismOfficeTrunkline` / `tourismOfficeLocal` | `(02) 8256-3000`, `local 4241 / 4242` |
| `defaultPageSize` | `20` |

`AppConstants.isSupabaseConfigured` returns true only when the URL starts with `https://`, does not contain `your-project`, and the key is non-empty and does not contain `your-anon-key`. When false, the app runs entirely on mock services.

**Web admin — `web_admin/.env.local`** (copy from `.env.example`; git-ignored)

```dotenv
VITE_SUPABASE_URL=https://<project-ref>.supabase.co
VITE_SUPABASE_ANON_KEY=<publishable-key>
```

`lib/supabase.ts` throws at import time if either is missing. Only the publishable key belongs in the browser bundle — never a service-role key.

### 5.3 Supabase SQL migration order

Run in the SQL Editor (or via the CLI) in this exact order:

| # | File | Required | What it does |
|---|---|---|---|
| 1 | `supabase/migrations/001_initial_schema.sql` | yes | Extensions, enums, all ten tables, indexes, RLS helpers and policies |
| 2 | `supabase/seed_full_rizal.sql` (or `seed.sql`) | recommended | 14 municipalities, 6 categories, 28 events, 36 POIs |
| 3 | `supabase/storage_policies.sql` | yes, for uploads | Creates the public `tourism-media` bucket (5 MB) and its policies |
| 4 | `supabase/admin_user_approvals.sql` | yes, for Level 4 | Approval/request columns, `is_level4_admin()`, audit + self-update guard triggers, Level 4 RLS, private `admin-verification-docs` bucket (10 MB) and its policies |
| 5 | `supabase/review_guardrails.sql` | yes, for server-enforced reviews | Creates `event_reviews`, dedupes, adds unique + length/rating constraints, `can_review_event()`, and review RLS |

Local CLI equivalent:

```bash
supabase start
supabase db reset      # applies migrations + configured seed
```

Files 3–5 are not under `migrations/` in this repository; apply them manually to hosted projects or move/copy them into `supabase/migrations/` before `db reset` if you want them automated. All three are idempotent (`begin … commit`, `if not exists`, `drop policy if exists`), so re-running is safe.

Storage buckets can equally be created in the dashboard, but the SQL also sets `file_size_limit` and `allowed_mime_types`; using the SQL avoids drift.

### 5.4 Running the mobile app

```bash
cd mobile_app
flutter pub get
flutter run -d chrome           # web preview
flutter run -d <device-id>      # Android/iOS device or emulator
```

Quality gates:

```bash
flutter analyze
flutter test                    # if tests are present
flutter build web --release     # output: build/web
```

Supabase URL and key live in `app_constants.dart`. With placeholders the app boots in mock/demo mode instead of calling `Supabase.initialize`.

### 5.5 Running the web admin portal

```bash
cd web_admin
npm install
cp .env.example .env.local      # fill in VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY
npm run dev                     # http://localhost:5173
npm run build                   # tsc --noEmit && vite build → dist/
npm run preview                 # serve the production bundle
```

### 5.6 Deployment

#### Web admin — Vercel

`web_admin/vercel.json` already provides SPA fallback:

```json
{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }
```

1. Import the repository in Vercel.
2. **Root Directory:** `web_admin`.
3. Framework preset **Vite**; build command `npm run build`; output directory `dist`.
4. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` for Production **and** Preview.
5. Deploy.

#### Web admin — Netlify

`web_admin/public/_redirects` contains `/* /index.html 200`, copied into `dist/` by Vite.

1. New site from Git; **Base directory** `web_admin`.
2. Build command `npm run build`; publish directory `web_admin/dist`.
3. Add the same `VITE_*` variables.
4. Deploy.

#### Flutter Web

```bash
cd mobile_app
flutter build web --release
```

Serve `mobile_app/build/web/` from any static host. Add the deployed origin to Supabase → Authentication → URL Configuration so Google OAuth redirects return correctly.

#### Android APK / AAB

```bash
cd mobile_app
flutter pub get
flutter build apk --release           # build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release --split-per-abi   # smaller per-ABI artifacts
flutter build appbundle --release     # Play Store AAB
flutter install --release             # or: adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Release notes:

- Application ID / namespace: `com.tuklasrizal.tuklas_rizal`.
- Sign with your own keystore before distribution (`android/key.properties` + a signing config in `android/app/build.gradle.kts`); never commit the keystore or `key.properties`.
- Location permission is required for the municipal geofence welcome alert.

### 5.7 Post-deploy verification checklist

1. Sign in to the portal with an approved Tier 2+ account; the sidebar shows the correct scope and role badges.
2. Approve a Tier 1 draft in **Events Management**; confirm it appears in the mobile app feed (RLS requires `status = 'approved'`).
3. Publish a **Civic Broadcast** as Tier 3+; confirm the featured civic event appears in the mobile feed and notification inbox.
4. As Level 4, open **Admin & User Approvals**, click **Inspect & Review**, confirm documents render (signed URLs) and approve with an assigned tier; confirm the badge count drops.
5. As a tourist, RSVP **I'm Going** to a started event, post a review, then confirm a second review edits the first rather than duplicating.
6. Confirm an unapproved account sees `PendingApprovalPage` and cannot reach any portal view.
7. Confirm `tourism-media` images render without a session and `admin-verification-docs` objects are not publicly reachable.

### 5.8 Git hygiene

The root `.gitignore` excludes `.env`/`.env.*`, `node_modules/`, `dist/`, `mobile_app/build/`, logs and editor noise. `.env.example` stays tracked. Before pushing:

```bash
git status
git ls-files | grep -iE '(^|/)\.env'   # should list only .env.example
```

---

## 6. Appendix: Known Gaps & Operational Notes

These are properties of the code as it exists today, not defects introduced by this document.

| Area | Current state |
|---|---|
| Live GPS | `GeolocatorGeofenceService` has TODO stubs for permission and coordinate reads; `app_providers.dart` wires `MockGeofenceService` by default. Geofence behaviour is demonstrated via the `/geofence-simulator` page. |
| LLM phrasing | Retrieval is live, but `useRemoteLlm` is `false` and `_composeWithRemoteLlm()` returns `null`; answers come from the grounded template or the offline knowledge base. `supabase/functions/` is empty. |
| `add_2_calendar` | Declared in `pubspec.yaml`; the implemented calendar action uses a Google Calendar template URL through `url_launcher`. |
| Review gate locality | The mobile gate reads the device-persisted RSVP; the authoritative cross-device check is the `can_review_event()` RLS policy. |
| Mobile verification documents | JPG/PNG via `image_picker`; PDFs are covered by the optional document-link field and the `mailto:` fallback. The web portal accepts PDFs directly. |
| `event_reviews` | Optional table created by `review_guardrails.sql`; reviews persist locally and sync best-effort. Until the migration runs, only local reviews exist. |
| `001_initial_schema.sql` | Reconstructed from production introspection — constraints, indexes and policies are the intended model and should be verified against the live project. |
| Barangay seed | No barangay rows are seeded by the SQL; the mobile app ships a sample map, the portal reads live rows. |
| Portal pre-migration behaviour | Without `admin_user_approvals.sql`, request/approval writes fail and the inspector shows no documents; the UI degrades rather than crashing (`hasApprovalColumns`). |
| Tier vs. requirement naming | Requirement text pairs Level 1 with barangay officials and Level 2 with "Department Head (Tourism Office)"; code labels Tier 2 **Tourism Coordinator** per the binding terminology rules. Tier 0 exists in code as Resident & Tourist. |
| Tests | Automated coverage is a single Flutter smoke test (`mobile_app/test/widget_test.dart`, `flutter test`); the web portal has no test suite. Routine verification is `flutter analyze`, `flutter test`, `flutter build web --release` and `npm run build`. |
