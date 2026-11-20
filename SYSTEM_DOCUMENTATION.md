# TuklasRizal — System Documentation

**Project:** TuklasRizal: An LLM-Based Application for Culture, Arts and Tourism for the Province of Rizal
**Scope:** All 14 municipalities of the Province of Rizal
**Repository:** `tuklas-rizal-capstone` (monorepo)
**Document status:** Generated from the source code, SQL, and configuration actually present in this repository (verified 20 November 2026). Where the code differs from a requirement or a familiar table name, the difference is called out explicitly rather than smoothed over.

---

## Table of Contents

1. [System Architecture & Tech Stack](#1-system-architecture--tech-stack)
2. [Database Schema, RLS & 14-Municipality Coverage](#2-database-schema-rls--14-municipality-coverage)
3. [Authentication & Role-Based Access Control](#3-authentication--role-based-access-control)
4. [RAG AI Tour Guide (`rizal-ai-chat`)](#4-rag-ai-tour-guide-rizal-ai-chat)
5. [Key Mobile & Web Features](#5-key-mobile--web-features)
6. [Setup, Environment & Deployment Guide](#6-setup-environment--deployment-guide)
7. [Appendix: Known Gaps & Operational Notes](#7-appendix-known-gaps--operational-notes)

---

## 1. System Architecture & Tech Stack

### 1.1 What the system is

TuklasRizal is a provincial tourism platform delivered as three components plus one managed backend:

| Component | Path | Stack | Primary users |
|---|---|---|---|
| Tourist Mobile / Web App | `mobile_app/` | Flutter (Dart), Riverpod, GoRouter, Supabase Flutter SDK, `app_links`, `geolocator` | Residents, tourists, guests |
| LGU Web Admin Portal | `web_admin/` | React 18 + TypeScript + Vite + Tailwind CSS, `@supabase/supabase-js` | Barangay Officials, Tourism Coordinators, Municipal/Provincial IT |
| Edge Function | `supabase/functions/rizal-ai-chat/` | Deno TypeScript (no npm imports), PostgREST retrieval, Groq + Gemini | Invoked by the mobile app |
| Backend | `supabase/` | PostgreSQL + pgvector, Supabase Auth, Storage, Row Level Security, Edge Functions | — |

Supporting assets: `dataset/rizal_tourism_dataset.json` (JSON mirror of the tourism seed) and `docs/` (capstone requirements, AI workflow notes, deferred features).

### 1.2 High-level architecture

```
                       ┌───────────────────────────────────────────────────────────┐
                       │                 Supabase project (single)                 │
                       │                                                           │
  ┌──────────────┐     │  Auth: email+password, 6-digit email OTP, Google OAuth     │     ┌──────────────────┐
  │ Flutter app  │────▶│  PostgreSQL: public schema, pgvector, RLS on every table   │◀────│ React web admin  │
  │              │     │  Storage: tourism-media (public), admin-verification-docs  │     │                  │
  │ Riverpod     │     │           (private)                                       │     │ Vite SPA,        │
  │ GoRouter     │     │  Realtime: postgres_changes streams                        │     │ publishable key  │
  │              │     │  Edge Function: rizal-ai-chat  (verify_jwt = false)        │     └──────────────────┘
  └──────┬───────┘     └───────────────────────┬───────────────────────────────┬───┘              │
         │                                     │                               │                  │
         │ functions.invoke('rizal-ai-chat')   │ PostgREST reads               │ Vercel / Netlify
         ▼                                     ▼                               ▼
   ┌───────────────┐                 ┌────────────────────┐          ┌────────────────────┐
   │ Groq          │                 │ events             │          │ Static SPA hosting │
   │ gpt-oss-120b  │◀── fallback ──▶ │ pois_logistics     │          └────────────────────┘
   │ gpt-oss-20b   │                 │ municipalities     │
   └──────┬────────┘                 └────────────────────┘
          │ fallback
   ┌──────▼────────────────┐
   │ Gemini 3.8 Flash      │        ┌──────────────────────────────────────────────┐
   │ thinkingBudget: 0     │        │ On-device only (never uploaded):             │
   └──────┬────────────────┘        │  GPS fix → town-radius / 200 m POI geofence  │
          │ both unavailable        │ SharedPreferences: onboarding, saves,        │
   ┌──────▼────────────────┐        │  reviews, theme, consent, notification reads  │
   │ Deterministic DB-only │        └──────────────────────────────────────────────┘
   │ reply (provider=database)│
   └───────────────────────┘
```

Key architectural properties:

1. **Single backend, two first-party clients, one function.** Both clients talk to Supabase over HTTPS using only the **publishable (anon) key**. No service-role key ships in either client and there is no custom API server; authorization is PostgreSQL RLS. The only server-side code is the `rizal-ai-chat` Edge Function, which holds the LLM API keys and (ideally) a service-role key for retrieval.
2. **The AI guide is server-side RAG.** Retrieval, ranking, prompt assembly, the LLM chain and the deterministic fallback all live in the Edge Function. The Flutter app is a thin client over `functions.invoke`.
3. **Offline/mock mode.** `AppConstants.isSupabaseConfigured` gates `Supabase.initialize`. With placeholder credentials the app boots without a backend and every service provider resolves to a mock implementation (`MockAuthService`, `MockDiscoveryService`, `MockCoordinatorService`). Geofencing and the AI guide are wired to their live implementations regardless, and degrade with friendly errors.
4. **Routing split.** `GoRouter` uses a `ShellRoute` for the bottom-navigation tabs plus registered shell branches (`/coordinators`, `/assistant`); detail and action routes (`/event/:id`, `/poi/:id`, `/settings`, …) are root-level so a pushed detail page never collides with a shell tab's page key.
5. **Local-first personal state.** Onboarding completion, guest interests, saved events/POIs, notification read marks, theme, accessibility settings, location consent and community reviews live in `SharedPreferences`, then sync to Supabase where a policy allows it.
6. **Privacy-by-design location.** GPS coordinates are compared on-device against town centres and POI coordinates; the app uploads no coordinates (documented in the RA 10173 consent dialog).

### 1.3 Repository layout

```
mobile_app/                       Flutter app (Android, iOS, web)
  lib/
    core/                         constants, providers, router, theme, utils, shared widgets
    features/                     auth, onboarding, home, explore, events, saved, coordinators,
                                  assistant, notifications, profile, settings, submissions,
                                  contact, about, geofence, interests
    models/                        EventItem, PoiLogistics, Municipality, UserProfile,
                                  ChatMessage, CoordinatorInquiry
    services/                      auth, discovery, coordinator, storage, geofence, rag_chat,
                                  saved_places, lookup, oauth_deep_link
  android/app/src/main/AndroidManifest.xml   OAuth deep-link intent filter
web_admin/
  src/
    App.tsx                       session → profile → approval → view switch
    components/                   Layout, AccessRequestModal, GalleryUpload, Icon, ui primitives
    context/AuthContext.tsx        Supabase session + public.users profile loading
    hooks/                        useLookups, usePendingApprovals
    lib/                          rbac, supabase client, storage, verification, format, validation
    pages/                        Login, Dashboard, Events, Pois, Inquiries, Promote,
                                  PendingApproval, UserApprovals
  vercel.json                     SPA rewrite          public/_redirects   Netlify fallback
supabase/
  migrations/001_initial_schema.sql   tables, enums, indexes, RLS helpers & policies
  seed_full_rizal.sql                 full idempotent 14-municipality seed
  seed_enriched_rizal.sql             additional enrichment records
  seed.sql                            small demo seed
  storage_policies.sql                tourism-media bucket + policies
  admin_user_approvals.sql            approval columns, helpers, triggers, RLS, private bucket
  review_guardrails.sql               event_reviews table, constraints, eligibility, RLS
  config.toml                         [functions.rizal-ai-chat] verify_jwt = false
  functions/rizal-ai-chat/            index.ts, rizal_knowledge.ts, README.md
dataset/rizal_tourism_dataset.json
docs/                             CAPSTONE_REQUIREMENTS.md, AI_WORKFLOW.md, DEFERRED_FEATURES.md
```

### 1.4 Technology inventory (verified from manifests)

**Mobile — `mobile_app/pubspec.yaml`**

| Package | Version | Purpose |
|---|---|---|
| `supabase_flutter` | ^2.7.0 | Auth, PostgREST, Realtime, Storage, Edge Functions |
| `flutter_riverpod` | ^2.6.1 | State management and dependency injection |
| `go_router` | ^14.2.0 | Declarative navigation with a bottom-nav shell |
| `app_links` | ^7.2.2 | Receives the Google OAuth deep link on Android/iOS |
| `google_fonts` | ^6.2.1 | Poppins typography |
| `geolocator` | ^13.0.1 | Location permission, position stream, distance |
| `url_launcher` | ^6.3.1 | Google Maps directions, Google Calendar, `mailto:` |
| `image_picker` | ^1.1.2 | Gallery photo picking for submissions and verification docs |
| `shared_preferences` | ^2.3.2 | Local persistence |
| `intl` | ^0.19.0 | Date formatting |
| `add_2_calendar` | ^3.1.1 | Declared; the implemented calendar action is a template URL |

Dart SDK constraint `^3.13.4`. Android application ID / namespace `com.tuklasrizal.tuklas_rizal`.

**Web admin — `web_admin/package.json`**

| Package | Version | Purpose |
|---|---|---|
| `react`, `react-dom` | ^18.3.1 | UI |
| `@supabase/supabase-js` | ^2.45.4 | Auth, PostgREST, Storage |
| `vite` | ^5.4.11 | Dev server / bundler |
| `typescript` | ~5.6.3 | `tsc --noEmit` in the build |
| `tailwindcss` | ^3.4.17 | Styling (`postcss` + `autoprefixer`) |
| `@vitejs/plugin-react` | ^4.3.3 | JSX transform |

`npm run build` = `tsc --noEmit && vite build` → `dist/`.

**AI Edge Function — `supabase/functions/rizal-ai-chat/`**

| Item | Value |
|---|---|
| Runtime | Deno (Supabase Edge Runtime); self-contained, no npm/jsr imports |
| Entry | `index.ts` → `Deno.serve` (POST, CORS preflight `OPTIONS` → 200) |
| JWT | `verify_jwt = false` in `supabase/config.toml` (guests may chat) |
| Providers | Groq `openai/gpt-oss-120b` → `openai/gpt-oss-20b`; Gemini `gemini-3.8-flash` |
| Retrieval | PostgREST over `events`, `pois_logistics`, `municipalities` |
| Static knowledge | `rizal_knowledge.ts` (source-cited reference guide) |

### 1.5 Cross-cutting UI conventions

| Convention | Implementation |
|---|---|
| Brand palette | Forest green `#033300` / dark header gradient `#022600 → #075A12`, gold `#FFC800`, cream surface `#F7F6F2` |
| Typography | Poppins via `google_fonts`, themed in `core/theme/app_theme.dart` |
| Main tab header | `TuklasMainHeader` — fixed **128 px** total (38 px utility row + 10 px gap + 58 px bottom row + 8/14 px padding), so switching tabs never shifts content. The requirement text often calls this "124 px"; the code constant is `TuklasMainHeader.height = 128`. |
| Secondary page header | `TuklasPageHeader` — gradient band, gold emblem, wordmark, 26 px title, optional subtitle, `actions`/`leading` slots |
| Buttons | `ElevatedButton`/`FilledButton`/`OutlinedButton` themes use 24 px horizontal + 16 px vertical padding; onboarding CTAs are full-width 54 px stadium pills with 32 px horizontal padding |
| Theme | Light and dark `ThemeData` built from the same token set; dark uses deep slate `#0E1512` with emerald `#5FD08A` accents |
| Naming | "Tourism Coordinator" (never generic Admin), "Promote Towns and Events" (never "Recommendations"), never the acronym "RZL" |

---

## 2. Database Schema, RLS & 14-Municipality Coverage

### 2.1 Extensions and enums

```sql
CREATE EXTENSION IF NOT EXISTS vector;     -- pgvector, VECTOR(768)
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()
```

| Enum | Labels |
|---|---|
| `event_status` | `draft`, `pending`, `approved`, `rejected`, `archived` |
| `participation_status` | `going`, `interested`, `attended` |
| `inquiry_status` | `open`, `in_progress`, `resolved`, `closed` |

> `001_initial_schema.sql` is documented as **reconstructed from the deployed production database** via PostgREST introspection. Column names and types match production; NOT NULL constraints, defaults, checks, indexes and RLS policies are reconstructed from observed behaviour and application code. Treat the policies as the intended security model and verify against the live project.

### 2.2 Table-by-table data dictionary

There are **eleven tables**. The requirement/spec naming used in some documents does not match the live names; see [§2.7](#27-table-name-map).

#### `public.municipalities` — the 14 municipalities

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK, default `gen_random_uuid()` | |
| `name` | `TEXT NOT NULL UNIQUE` | |
| `slug` | `TEXT NOT NULL UNIQUE` | Seed joins on slug |
| `description` | `TEXT` | Shown in welcome banners and the AI context |
| `latitude`, `longitude` | `DOUBLE PRECISION` | Geofence centre |
| `geofence_radius_meters` | `INTEGER DEFAULT 5000` | Drives the Town Welcome Alert |
| `tourism_office_name` | `TEXT` | |
| `coordinator_contact_email` | `TEXT` | Used in AI grounding + contact screens |
| `coordinator_contact_phone` | `TEXT` | |
| `tourism_office_address` | `TEXT` | |
| `visitor_priority_boost` | `NUMERIC(4,2) DEFAULT 1.00` | "Promote Towns and Events" lever; production range 1.00–1.60 |
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
| Constraint | `UNIQUE (municipality_id, name)` | `barangays_municipality_id_name_key` |

The SQL seed does not insert barangays; the mobile app ships a sample `RizalBarangays.byMunicipality` map, and the portal reads real rows.

#### `public.categories`

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `name` | `TEXT NOT NULL UNIQUE` | |
| `slug` | `TEXT NOT NULL UNIQUE` | Six seeded slugs |
| `icon_name` | `TEXT` | Production column is `icon_name`; there is no `color` |
| `description` | `TEXT` | |
| `created_at` | `TIMESTAMPTZ` | |

Seeded categories: `Cultural & Arts / cultural-arts`, `Festival / festival`, `Food & Heritage / food-heritage`, `Eco-Tourism & Nature / eco-tourism`, `Civic & Community / civic-community`, `Sports & Recreation / sports-recreation`.

#### `public.users` — visitor and LGU profiles (`id` = Supabase Auth user id)

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | Equals `auth.users.id`; there is no `auth_user_id` |
| `email` | `TEXT NOT NULL` | |
| `full_name` | `TEXT NOT NULL` | |
| `avatar_url` | `TEXT` | No `profile_image_url`; no `phone`; bio lives in auth metadata |
| `role_tier` | `INTEGER NOT NULL DEFAULT 1` | 0–4 (see §3) |
| `role_title` | `TEXT` | Denormalized display label |
| `municipality_id` | `UUID → municipalities(id) ON DELETE SET NULL` | Scope |
| `barangay_id` | `UUID → barangays(id) ON DELETE SET NULL` | Scope |
| `is_approved` | `BOOLEAN NOT NULL DEFAULT false` | Portal gate |
| `created_at`, `updated_at` | `TIMESTAMPTZ NOT NULL DEFAULT now()` | |

Added by `admin_user_approvals.sql` (all nullable/defaulted, `IF NOT EXISTS`): `approval_status TEXT DEFAULT 'pending'`, `approved_at`, `approved_by`, `requested_role_tier`, `requested_municipality`, `department_office`, `official_position`, `contact_number`, `request_reason`, `verification_doc_urls TEXT[] DEFAULT '{}'`, `review_notes`, `verified_lgu_id`, `verified_endorsement`, `requested_at`.
Constraints/indexes: `users_approval_status_check`, `users_approval_status_idx`, `idx_users_municipality`, `idx_users_barangay`, `idx_users_role_tier`.

#### `public.user_interests`

| Column | Type | Notes |
|---|---|---|
| `user_id` | `UUID NOT NULL → users(id) ON DELETE CASCADE` | |
| `category_id` | `UUID NOT NULL → categories(id) ON DELETE CASCADE` | |
| `created_at` | `TIMESTAMPTZ` | |
| PK | `(user_id, category_id)` | One row per interest |

Written by `SupabaseAuthService.setUserInterests()` (delete-then-insert, resolving onboarding slugs and live UUIDs to `categories.id`).

#### `public.events`

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `municipality_id` | `UUID NOT NULL → municipalities(id) ON DELETE CASCADE` | |
| `barangay_id` | `UUID → barangays(id) ON DELETE SET NULL` | |
| `category_id` | `UUID → categories(id) ON DELETE SET NULL` | |
| `created_by` | `UUID → users(id) ON DELETE SET NULL` | Organizer identity; also blocks self-review |
| `approved_by` | `UUID → users(id) ON DELETE SET NULL` | |
| `title` | `TEXT NOT NULL` | |
| `description` | `TEXT` | |
| `venue_name` | `TEXT` | Replaces old `location`/`address` |
| `how_to_get_there` | `TEXT` | Grounded verbatim by the AI guide |
| `latitude`, `longitude` | `DOUBLE PRECISION` | |
| `start_date`, `end_date` | `TIMESTAMPTZ NOT NULL` | `CHECK (end_date >= start_date)` |
| `image_url` | `TEXT` | Public `tourism-media` URL |
| `status` | `event_status NOT NULL DEFAULT 'draft'` | Only `approved` is publicly readable |
| `is_featured` | `BOOLEAN NOT NULL DEFAULT false` | |
| `promotion_weight` | `NUMERIC(4,2) DEFAULT 1.00` | LGU promotion lever |
| `created_at`, `updated_at` | `TIMESTAMPTZ NOT NULL DEFAULT now()` | |

Indexes: `idx_events_municipality`, `idx_events_barangay`, `idx_events_category`, `idx_events_status`, `idx_events_dates (start_date, end_date)`.

#### `public.event_embeddings`

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `event_id` | `UUID NOT NULL UNIQUE → events(id) ON DELETE CASCADE` | |
| `embedding` | `VECTOR(768) NOT NULL` | Reserved for semantic search |
| `created_at` | `TIMESTAMPTZ` | |

Provisioned and RLS-restricted to approved staff. The **deployed AI guide does not query it** — retrieval is keyword/intent ranking over live rows plus the static reference guide (see §4.2).

#### `public.event_participation` — RSVP / attendance

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `user_id` | `UUID NOT NULL → users(id) ON DELETE CASCADE` | |
| `event_id` | `UUID NOT NULL → events(id) ON DELETE CASCADE` | |
| `status` | `participation_status NOT NULL DEFAULT 'interested'` | **`status`**, not `rsvp_status` |
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
| `latitude`, `longitude` | `DOUBLE PRECISION` | Also used for the 200 m POI approach alert |
| `image_url` | `TEXT` | |
| `is_promoted` | `BOOLEAN NOT NULL DEFAULT false` | |
| `created_at` | `TIMESTAMPTZ` | No `updated_at`, no `is_active`, no `status` |

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

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | |
| `event_id` | `UUID NOT NULL → events(id) ON DELETE CASCADE` | |
| `user_id` | `UUID → users(id) ON DELETE CASCADE` | Nullable: seeded/legacy reviews may have no author |
| `author_name` | `TEXT` | Display name kept by the mobile app |
| `rating` | `INTEGER NOT NULL DEFAULT 5` | `CHECK (rating BETWEEN 1 AND 5)` |
| `review_text` | `TEXT NOT NULL` | `CHECK (char_length(btrim(review_text)) BETWEEN 10 AND 500)` |
| `created_at` | `TIMESTAMPTZ NOT NULL DEFAULT now()` | |
| `updated_at` | `TIMESTAMPTZ DEFAULT now()` | |
| Constraint | `UNIQUE (event_id, user_id)` | One review per user per event |
| Index | `event_reviews_event_idx (event_id)` | |

### 2.3 Coverage of all 14 municipalities

Seeded by `seed_full_rizal.sql` (14 municipalities, each with real coordinates, tourism-office contact fields and a 5 000 m geofence radius):

| # | Municipality | Seed slug | Curated id (mobile) | Anchor content used across the app |
|---|---|---|---|---|
| 1 | Angono | `angono` | `angono` | Higantes Festival, Petroglyphs, Blanco/Botong Francisco museums, balaw-balaw |
| 2 | Antipolo | `antipolo` | `antipolo` | Cathedral & pilgrimage, Hinulugang Taktak, Pinto Art Museum, suman/kasuy |
| 3 | Baras | `baras` | `baras` | 1686 St. Joseph Parish, Masungi Georeserve, Palo Alto Falls |
| 4 | Binangonan | `binangonan` | `binangonan` | Petroglyphs, Santa Ursula Parish, Talim Island, abnoy/buro |
| 5 | Cainta | `cainta` | `cainta` | Our Lady of Light Parish, bibingka, SumBingTik Festival |
| 6 | Cardona | `cardona` | `cardona` | Rock Garden, Kaluskos Festival, nilasing na hipon |
| 7 | Jala-Jala | `jalajala` | `jala_jala` | Laguna de Bay island town, lakeshore seafood |
| 8 | Morong | `morong` | `morong` | Heritage church & stone fortifications, sinigang na kanduli |
| 9 | Pililla | `pililla` | `pililla` | Pililla Wind Farm, binarutak/okoy |
| 10 | Rodriguez | `rodriguez` | `rodriguez` | Sierra Madre gateway, Wawa, Mt. Pamitinan |
| 11 | San Mateo | `san-mateo` | `san_mateo` | Aranzazu shrine, river trails, kakanin |
| 12 | Tanay | `tanay` | `tanay` | Daranak/Batlag Falls, Calinawan Cave, Mt. Daraitan, Regina RICA |
| 13 | Taytay | `taytay` | `taytay` | Tiangge/garments, Santa Ana de Sapa Parish, lauya |
| 14 | Teresa | `teresa` | `teresa` | Upland trails and waterfalls, adobong matanda |

Slug note: Jala-Jala is stored as `jalajala` in the seed, `jala-jala` in `rizal_knowledge.ts`, and `jala_jala` as the curated mobile id. The AI function normalises slugs when matching, and `interest_matcher.dart` normalises ids, names and slugs before comparing, so the three spellings interoperate.

### 2.4 Row Level Security

RLS is enabled on all eleven tables plus `event_reviews`.

#### Reference data

| Table | Policy | Rule |
|---|---|---|
| `municipalities` | `municipalities_select_public` | `SELECT USING (true)` |
| | `municipalities_manage_tier34` | `ALL` if `is_approved_staff()` and (tier 4 or `id = current_user_municipality_id()`) |
| `barangays` | `barangays_select_public` | `SELECT USING (true)` |
| | `barangays_manage_tier234` | `ALL` if staff and (tier 4 or own municipality) |
| `categories` | `categories_select_public` | `SELECT USING (true)` |
| | `categories_manage_tier4` | `ALL` if tier 4 |

#### `users`

| Policy | Command | Rule |
|---|---|---|
| `users_select_own` | SELECT | `id = auth.uid()` |
| `users_select_staff` | SELECT | `is_approved_staff()` and (tier 4 or same municipality) |
| `users_update_own` | UPDATE | `id = auth.uid()` (privileged columns restored by trigger) |
| `users_insert_self` | INSERT | `id = auth.uid()` |
| `level4_read_all_users` | SELECT | `is_level4_admin()` |
| `level4_update_users` | UPDATE | `is_level4_admin()` |
| `applicant_update_own_request` | UPDATE | `auth.uid() = id`; guarded by `guard_user_self_update` |

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

#### `event_reviews`

| Policy | Command | Rule |
|---|---|---|
| `event_reviews_public_read` | SELECT | `USING (true)` |
| `event_reviews_verified_insert` | INSERT | `auth.uid() = user_id` **and** `can_review_event(event_id)` **and** rating 1–5 **and** 10–500 chars |
| `event_reviews_author_update` | UPDATE | owner with the same eligibility/length checks |
| `event_reviews_author_delete` | DELETE | owner or `is_level4_admin()` |

Eligibility helper (`SECURITY DEFINER`, `STABLE`, execute granted to `authenticated`/`service_role`):

```sql
public.can_review_event(target_event_id uuid) RETURNS boolean
-- event exists AND events.created_by IS DISTINCT FROM auth.uid()
--             AND events.start_date <= now()
--             AND coalesce(status::text,'approved') <> 'cancelled'
-- AND an event_participation row exists with status = 'going'
```

#### Helper functions

| Helper | Source | Purpose |
|---|---|---|
| `current_user_role_tier()` | `001_initial_schema.sql` | Caller's tier |
| `current_user_municipality_id()` | `001_initial_schema.sql` | Municipal scope |
| `current_user_barangay_id()` | `001_initial_schema.sql` | Barangay scope |
| `is_approved_staff()` | `001_initial_schema.sql` | `role_tier >= 2 AND is_approved` |
| `is_level4_admin()` | `admin_user_approvals.sql` | `SECURITY DEFINER`; tier ≥ 4 and approved, avoids recursive RLS on `users` |
| `can_review_event(uuid)` | `review_guardrails.sql` | Attendance-verified review eligibility |
| `guard_user_self_update()` | `admin_user_approvals.sql` | Trigger: blocks self-promotion |
| `stamp_user_approval()` | `admin_user_approvals.sql` | Trigger: audit stamps on `is_approved` change |

### 2.5 Storage buckets

| Bucket | Public | Size limit | MIME types | Path convention | Defined in |
|---|---|---|---|---|---|
| `tourism-media` | **yes** | 5 MB | `image/jpeg`, `image/png`, `image/webp`, `image/gif` | `events/<ts>_<rand>.jpg`, `pois/…`, `avatars/…` | `storage_policies.sql` |
| `admin-verification-docs` | **no** | 10 MB | `image/jpeg`, `image/png`, `image/webp`, `application/pdf` | `<auth.uid()>/<timestamp>_<name>` | `admin_user_approvals.sql` |

`tourism-media` policies: public `SELECT`; `INSERT`/`UPDATE`/`DELETE` for `authenticated`. Uploads store `getPublicUrl(path)` in `events.image_url` / `pois_logistics.image_url`.

`admin-verification-docs` policies: `INSERT` only into the caller's own folder (`(storage.foldername(name))[1] = auth.uid()::text`); `SELECT`/`DELETE` for the owner folder or `is_level4_admin()`. The portal renders documents through 1-hour signed URLs (`createSignedUrl(path, 3600)`); the mobile app stores only the path.

### 2.6 Seed data

`supabase/seed_full_rizal.sql` (idempotent, single transaction):

| Data | Count | Idempotency strategy |
|---|---|---|
| Municipalities | 14 | Upsert on unique `slug` |
| Categories | 6 | Upsert on unique `slug` |
| Approved events | 28 | Insert only when no event with the same title exists in that municipality |
| POIs / logistics | 36 | Insert only when no POI with the same name exists in that municipality |

All seeded events use `status = 'approved'` so guests see them. `seed.sql` is a smaller demo set; `seed_enriched_rizal.sql` adds extra records. Seeding is deliberately not part of the migration.

### 2.7 Table name map

Some requirement documents and defence notes use shorter names. The live schema keeps the longer ones:

| Familiar / requested name | Actual table | Note |
|---|---|---|
| `profiles` | `public.users` | `id` is the auth user id |
| `pois` | `public.pois_logistics` | Includes foods, restaurants and logistics, not only sights |
| `event_rsvps` | `public.event_participation` | Column is `status` (`going`/`interested`/`attended`) |
| `reviews` | `public.event_reviews` | Created by `review_guardrails.sql` |
| `inquiries` | `public.coordinator_inquiries` | Municipal scope |
| `submissions` | *(no table)* | Community submissions land directly in `events` as `status = 'draft'` with `created_by`, or in `pois_logistics`; approval status lives on `users` for LGU accounts only |
| `audit_logs` | *(no table)* | Audit fields are stamped on `users`: `approved_at`, `approved_by`, `approval_status`, `review_notes`, plus `events.approved_by` |

---

## 3. Authentication & Role-Based Access Control

### 3.1 Three-tier operational hierarchy (and the five integer tiers in code)

For defence framing the platform has three operating levels: **Resident/Tourist → Municipal Tourism Coordinator → Provincial IT Admin**. The implementation refines that into five integer tiers in `public.users.role_tier` (labels in `web_admin/src/lib/rbac.ts`):

| Tier | Label in code | Scope | Maps to the 3-tier story |
|---|---|---|---|
| **0** | Resident & Tourist | Province-wide read | Resident / tourist |
| **1** | Barangay Official | Own barangay (drafts only) | Resident-side LGU encoder; cannot publish |
| **2** | Tourism Coordinator | Own municipality | Municipal Tourism Coordinator |
| **3** | Mayor / Municipal IT Admin | Own municipality | Municipal executive oversight (broadcasts) |
| **4** | Governor / Provincial IT Admin | Province-wide (all 14 LGUs) | Provincial IT Admin |

Default assignment: mobile email/Google sign-up → `role_tier = 0`, `is_approved = true`. Web self-registration as LGU staff → the requested tier, `is_approved = false`. Tier 4 is granted only by an existing approved tier-4 admin.

### 3.2 Capability matrix (`web_admin/src/lib/rbac.ts`)

| Capability | Helper | Requirement |
|---|---|---|
| Reach any portal view | `isApprovedProfile()` | `is_approved` or `approval_status = 'approved'` |
| Overview Dashboard / Events / POIs views | `NAV_ITEMS[].visible` | Any approved profile |
| Create event | `forcedEventStatus()` | Tier ≤ 1 is forced to `status = 'draft'` |
| Approve / reject events | `canReviewEvents()` | ≥ 2 |
| Feature / unfeature events | `canFeatureEvents()` | ≥ 2 |
| Manage POIs, foods & logistics | `canManagePois()` | ≥ 2 |
| Coordinator inquiry inbox | `canHandleInquiries()` | ≥ 2 |
| Municipal Civic Broadcast | `canBroadcast()` | ≥ 3 |
| Promote Towns and Events weights | `canAdministerProvince()` | ≥ 4 |
| Admin & User Approvals | `canApproveUsers()` | ≥ 4 **and** approved |
| Province-wide scope | `isProvincial()` | ≥ 4 |
| Municipality scope filter | `municipalityScope()` | Tiers 0–3 → own `municipality_id`; 4 → null |
| Barangay scope filter | `barangayScope()` | Tier ≤ 1 → own `barangay_id` |

### 3.3 Guest browsing mode

There is no login wall. Guests can browse events, POIs, municipalities, the saved collection (device-local), the AI Tour Guide and the Coordinator directory. Sign-in is demanded only at action boundaries by `core/utils/auth_gate.dart::requireSignIn(context, ref, action: ...)`, which shows a dialog ("Sign in required", with "Not now" / "Sign in"). Used for RSVP, bookmarks, inquiries, reviews and community submissions.

### 3.4 Auth methods

Implemented in `mobile_app/lib/services/auth_service.dart` (`SupabaseAuthService` / `MockAuthService`); UI in `features/auth/pages/login_screen.dart` (`LoginPage`), `login_page.dart` (`SignupPage`, `OAuthCallbackPage`, `InterestOnboardingPage`), and the web portal's `LoginPage.tsx`.

#### Email + password

`signInWithPassword`. Unconfirmed addresses are detected (`emailConfirmationRequired` / `_verificationMessageFor`) and the session is signed out so no usable unverified session survives. Profile load is given a 10 s budget; on timeout a lightweight profile is built from auth metadata so the spinner never hangs.

#### 6-digit email OTP

| Flow | Implementation |
|---|---|
| Sign-up | `signUp()` creates the auth user with metadata `full_name`, `role_tier`, `role_title` and `emailRedirectTo = AppConstants.oauthRedirectUrl`. When Supabase returns no session, `emailConfirmationRequired = true` and `SignupPage` advances to its OTP step. `verifySignupOtp()` → `verifyOTP(type: OtpType.signup)` then provisions the `public.users` row. `resendSignupOtp()` re-sends with a UI countdown. |
| Sign-in | `sendLoginOtp()` → `signInWithOtp(shouldCreateUser: false)` (never creates a half-baked user); `verifyLoginOtp()` → `verifyOTP(type: OtpType.email)` and creates a profile if none exists. |

#### Google OAuth (web + mobile deep link)

- PKCE is explicit: `Supabase.initialize(..., authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce))` in `main.dart`.
- `signInWithGoogle()` uses a platform redirect target:
  - **Web:** `'${Uri.base.origin}/'` (bare origin with trailing slash, no hash route, so it matches the Supabase allowlist).
  - **Android/iOS:** `io.supabase.tuklasrizal://login-callback`, launched with `LaunchMode.externalApplication` so the browser can hand control back to the app.
- `services/oauth_deep_link.dart` runs immediately after `Supabase.initialize`: it reads `getInitialLink()` and listens to `AppLinks().uriLinkStream`, filters for the registered scheme/host, and exchanges the code with `auth.getSessionFromUrl(uri)` (skipped when a session already exists; `AuthException` is swallowed so a stale URL cannot crash startup).
- `android/app/src/main/AndroidManifest.xml` declares a single `VIEW`/`DEFAULT`/`BROWSABLE` intent filter on `.MainActivity` for `scheme=io.supabase.tuklasrizal`, `host=login-callback`, `autoVerify="false"`. `flutter_web_auth_2` is **not** a dependency, so no `CallbackActivity` entry exists (adding one would break manifest resolution).
- Both redirect URLs must be allowlisted in Supabase → Authentication → URL Configuration: `https://<deployed-origin>/` and `io.supabase.tuklasrizal://login-callback`.
- `completeGoogleSignIn()` calls `ensureProfile()`, then persists any guest onboarding interests that are not already stored, and returns the DB-backed profile.
- Profile provisioning (`_createProfileFromAuthUser`) reads `full_name`/`name` and `avatar_url`/`picture` from Google metadata and creates the `public.users` row with `role_tier = 1`, `role_title = 'Resident & Tourist'`, `is_approved = true`.

#### Route and session guards

| Guard | Behaviour |
|---|---|
| `AuthRedirectNotifier` (`app_router.dart`) | Mirrors the signed-in user id; `refreshListenable` merges it with the onboarding controller |
| Redirect rule | Signed-in users on `/login` or `/signup` → `/` |
| `main.dart` auth listener | Updates `authRedirectNotifier` post-frame; on first profile sighting per session, syncs guest interests and sends users without saved interests to `/onboarding/interests` |
| Existing-session bootstrap | If a session is restored without a change event, the notifier is seeded once after the first frame |
| Web portal | `AuthContext` loads `public.users`; unapproved → `PendingApprovalPage`; missing row → insert from metadata with `is_approved: false` |

### 3.5 Verification, approval and audit workflow

1. **Apply.** Web self-registration (tiers 2–4) or "Request higher access" (`AccessRequestModal`, tiers ≤ 3), or the mobile LGU Access Request form (`/lgu-access-request`). Documents go to the private `admin-verification-docs` bucket under `<uid>/<timestamp>_<name>`; the returned paths plus applicant fields are written to `public.users`.
2. **Self-approval is impossible.** `guard_user_self_update` is a `BEFORE UPDATE` trigger that restores `role_tier`, `role_title`, `is_approved`, `municipality_id`, `barangay_id`, `approved_at`, `approved_by` for non-tier-4 callers and refuses any `approval_status` other than `pending`/`rejected`.
3. **Review.** Tier 4 opens **Admin & User Approvals** → **Inspect & Review**: full application, every document (absolute links as-is, storage paths via 1-hour signed URLs, PDFs in an iframe), LGU-ID and endorsement checkboxes, target tier + municipality, and review notes.
4. **Decide.** Approve & assign tier (`is_approved: true`, chosen `role_tier`, `approval_status: 'approved'`), Reject with reason (requires a note, demotes to tier 1), or Revoke access (immediate demotion).
5. **Audit.** `stamp_user_approval` fires `BEFORE UPDATE OF is_approved` and stamps `approved_at`, `approved_by = auth.uid()` and `approval_status`, regardless of which client performed the change.
6. **Degraded mode.** `hasApprovalColumns(profile)` tolerates an unapplied migration: the UI derives status from `is_approved` and hides audit fields instead of failing with PostgREST `PGRST204`.

---

## 4. RAG AI Tour Guide (`rizal-ai-chat`)

Deployed as Supabase Edge Function **`rizal-ai-chat` v8** at `https://<project-ref>.supabase.co/functions/v1/rizal-ai-chat`, with `verify_jwt = false` so guests can chat.

### 4.1 Request lifecycle

```
Flutter assistant_page
  └─ SupabaseRagChatService.sendMessage(text, municipality)
       └─ functions.invoke('rizal-ai-chat', { message, history[≤12], municipality? })
            ├─ parseBody + validation (message ≤ 4000 chars)
            ├─ retrieve(message, municipality)
            │    ├─ loadTowns()   municipalities (50)      ┐
            │    ├─ loadEvents()  events status=approved   ├─ live PostgREST
            │    └─ loadPois()    pois_logistics (200)     ┘
            │    ├─ drop QA rows matching /\btest(s|ing|er|ers|ed)?\b/i
            │    ├─ resolve municipality (explicit → message scan)
            │    ├─ keyword tokens (stopwords removed, singular fallback)
            │    ├─ detect intents (family/food/faith/adventure/heritage)
            │    ├─ rank rows → top 6 events, top 7 POIs, top 3 towns
            │    ├─ buildContext() (verified fields only, clipped descriptions)
            │    └─ buildRecommendations() → max 4 tappable items
            ├─ buildKnowledgeContext() → budgeted reference guide
            ├─ generate(history, prompt)  Groq ×2 → Gemini → null
            └─ response { reply, sources, items, municipality, provider, model }
```

### 4.2 Live-record retrieval and ranking

**Queries.**

- `municipalities`: `id,name,slug,description,latitude,longitude,geofence_radius_meters,tourism_office_name,coordinator_contact_email,coordinator_contact_phone,tourism_office_address` (limit 50).
- `events`: `status=eq.approved` with an embedded `municipalities!inner(...)` join (limit 200); on join failure it retries without the embed and attaches towns client-side from the municipalities map.
- `pois_logistics`: same shape, limit 200, no status column.
- Reads use `SUPABASE_SERVICE_ROLE_KEY` when present, otherwise `SUPABASE_ANON_KEY` (RLS then still applies, and only approved events are visible either way).

**Test-data exclusion.** Before ranking, every row is dropped when its name/title/description/venue/address matches the whole-word pattern `test`, `tests`, `testing`, `tester(s)`, `tested` — so "Test 1" QA rows never ground an answer or appear in recommendation cards. The mobile client applies the same filter to `items` defensively.

**Municipality resolution.** An explicit `municipality` wins (name or slug, then partial). Otherwise the message is scanned for all 14 town names/slugs, longest match first. An unknown town string becomes a label-only filter and never leaks into grounding data.

**Keyword scoring.** Tokens are NFKD-normalised, diacritics stripped, lowercased, punctuation removed; tokens under 3 characters and ~230 English/Tagalog stopwords are discarded; a light singular is added for words ending in `s`. Each keyword hit in a row's haystack adds **+3**; every row starts at **0.15** so broad questions still return records.

**Intent scoring.** Five intent families — `family`, `food`, `faith`, `adventure`, `heritage` — each with trigger words (family: kid/child/picnic/reunion…; food: eat/pasalubong/kakanin/itik…; faith: church/shrine/simbahan/pilgrimage…; adventure: hike/falls/cave/trail…; heritage: art/museum/petroglyph/higantes…). Record-side synonyms earn **+6 for the first term** and **+1.5 for each additional term (up to four)** per intent. Phrase and stem matching tolerate plurals.

**Municipal filter.** A row in the filtered town earns **+8**; other towns keep **+0.4** so province-wide itinerary questions still have material.

**Outputs.** Top 6 events + top 7 POIs + top 3 towns are rendered as a grounded context block, with event dates reduced to calendar dates, coordinates as `lat, lng`, descriptions clipped to 220 characters, and structured fields (hours, fees, how-to-get-there, contacts) preserved verbatim. Sources are unique strings such as `public.events — Tanay`, plus the reference-guide attribution. Recommendation cards are deduplicated and capped at **4** across events and POIs.

### 4.3 Verified reference guide (`rizal_knowledge.ts`)

A static, source-cited module bundled with the function. Every block carries the source URL in comments (Province of Rizal, DOT, LRTA, municipal tourism offices, reputable published guides), compiled on 20 November 2026.

| Export | Content |
|---|---|
| `PROVINCIAL_TOURISM_OFFICE` | Rizal Provincial Tourism Office: `tourismoffice@rizalprovincialgov.ph`, `(02) 8256-3000 local 4241/4242`, Capitol address, Mon–Fri 8–5 |
| `FFAAN_PILLARS` | Rizal's 5 DOT Green Corridor pillars — Faith, Food, Art, Adventure, Nature — with town-level examples |
| `MUNICIPALITIES` | All 14 towns: aliases, tagline, FFAAN pillars, highlights, food & pasalubong, commute corridor, tourism-office contact, hidden-gem note |
| `COMMUTE_CORRIDORS` | Metro Manila departure hubs (Cubao, EDSA Shaw/Starmall, Pasig Palengke, Ortigas, LRT-2 Marikina-Pasig & Antipolo) and transfer hubs (Masinag Junction, Tanay Public Market, Binangonan/Cardona ports) |
| `FEE_HOURS_BENCHMARKS` | Entrance/guide fee and hours benchmarks for Hinulugang Taktak, Pinto Art Museum, Daranak/Batlag Falls, Calinawan Cave, Mt. Daraitan & Tinipak River, Regina RICA, Pililla Wind Farm |
| `ETIQUETTE_AND_SAFETY` | Church/shrine dress and silence rules, trail/cave registration and mandatory guides, waterfall/weather advisories, no-swimming rules, Leave No Trace |
| `MULTI_TOWN_LOOPS` | Proximity loops — Art & Pilgrimage, Lakeshore Heritage, Highlands & Windmill — each pairing a hub with under-represented towns |
| `buildKnowledgeContext(message, municipality)` | Budget-aware selector |

Context selection is priority-ordered and character-budgeted to **`KNOWLEDGE_CHAR_BUDGET = 7 500`**:

| Priority | Section | Kept when |
|---|---|---|
| 0 | Provincial tourism office; safety/confirmation reminder; mentioned towns | Always |
| 1 | Fee/hour benchmarks | Fee/price intent |
| 1 | Commute corridors | Commute intent or open-ended question |
| 1 | Multi-town loops | Itinerary intent or open-ended question |
| 1 | Town-by-town food guide | Food intent on an open-ended question |
| 1 | Etiquette & safety | Message mentions dress/church/trail/hike/cave/waterfall/weather/`bawal` |
| 2 | FFAAN pillars | Pillar intent or open-ended question |

Priority-0 sections are never dropped; lower priorities are skipped when they would exceed the budget.

### 4.4 Token budgeting (8 000 TPM)

The Groq on-demand tier allows roughly **8 000 tokens per minute per request window**, so the function bounds every input:

| Bound | Value |
|---|---|
| User message | ≤ 4 000 characters (else HTTP 400) |
| History window | Last **12** turns; each turn clipped to 2 000 characters |
| Live DB rows | 50 towns, 200 events, 200 POIs fetched → 6 events + 7 POIs + 3 towns rendered |
| Description clipping | 220 characters per record |
| Reference guide | 7 500 characters total |
| Completion | `max_tokens` / `maxOutputTokens` = 1 500, temperature 0.35 |
| Per-call timeout | 30 s (`AbortController`) |

Clients also trim each history turn to 800 characters before sending, so the 2 000-character server clip is a ceiling rather than the norm.

### 4.5 Model chain and fallbacks

```
GROQ_API_KEY set?
  ├─ openai/gpt-oss-120b  (reasoning_effort: "low")
  └─ openai/gpt-oss-20b   (reasoning_effort: "low")
GEMINI_API_KEY set?
  └─ gemini-3.8-flash  (generationConfig.thinkingConfig.thinkingBudget = 0)
otherwise / all failed
  └─ deterministicReply(retrieved)   provider = "database"
```

| Condition | Behaviour |
|---|---|
| Non-2xx from a Groq model (400/404/429/503…) | Error appended to `lastLlmErrors`, next model tried |
| Network error or 30 s timeout | Same as above |
| Gemini 3.x "thinking" | Disabled with `thinkingBudget: 0` so the token budget goes to the visible answer; the guard is applied only to `gemini-3*` models |
| Both providers unreachable | Deterministic answer assembled from verified rows (events, POIs, tourism-office contacts) plus the provincial office line, labelled as a database-only answer |
| Returned text empty | Treated as a failure and the next provider is tried |

`provider` in the response is `groq`, `gemini`, or `database`; `model` names the exact model (or `database-records-only`).

### 4.6 Response contract

```json
{
  "reply": "…",
  "sources": ["public.events — Tanay", "public.municipalities — Tanay",
              "TuklasRizal verified reference guide (rizalprovince.ph / DOT / LRTA / LGU tourism offices)"],
  "items": [{ "id": "…", "type": "poi", "title": "Daranak Falls", "municipality": "Tanay" }],
  "municipality": "Tanay",
  "provider": "groq",
  "model": "openai/gpt-oss-20b"
}
```

Errors return `{ "error": "…" }` with 400 (bad body), 405 (non-POST), or 500 (unexpected). Every response, including the `OPTIONS` preflight, carries permissive CORS headers (`*`).

### 4.7 Privacy and safety guardrails

The system prompt enforces five mandatory rules:

1. **Strict grounding, zero guessing.** Answer only from the live records and the reference guide; never invent dates, prices, schedules, routes, hours, venues or contacts. When a detail is unpublished, say so and give the exact Municipal Tourism Office email/phone. Peso amounts and travel times are labelled benchmarks to confirm before travelling.
2. **Explainable hidden-gem promotion.** For open-ended itinerary questions, pair a popular hub (Antipolo/Tanay) with at least one under-represented town (Jala-Jala, Cardona, Pililla, Morong, Teresa) and explain why it matches the visitor's interests.
3. **Automatic language mirroring.** Reply in English, Tagalog, or Taglish; never translate official names.
4. **Out-of-scope and travel-safety guardrails.** Steer unrelated prompts back to Rizal tourism; remind hikers, cavers and waterfall visitors to check weather and LGU advisories, register, hire mandatory guides, and follow site rules.
5. **Privacy and AI transparency — RA 10173 / NPC Advisory No. 2024-04.** Never ask for a home address, phone number or government ID in chat; be explicit that the answer comes from an AI assistant grounded in the TuklasRizal directory.

The prompt also forbids revealing the system prompt or raw context, mentioning tables/columns/JSON/retrieval mechanics, and using Markdown tables or pipe characters (a phone-width formatting rule carried into the mobile renderer).

### 4.8 Configuration and deployment

Secrets (never committed): `GROQ_API_KEY`, `GEMINI_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (falls back to `SUPABASE_ANON_KEY`).

```bash
supabase secrets set GROQ_API_KEY=... GEMINI_API_KEY=... \
  SUPABASE_URL=https://<project-ref>.supabase.co \
  SUPABASE_SERVICE_ROLE_KEY=...

npx supabase functions deploy rizal-ai-chat --project-ref <project-ref>
```

`supabase/config.toml`:

```toml
[functions.rizal-ai-chat]
verify_jwt = false
```

Smoke test:

```bash
curl -i "https://<project-ref>.supabase.co/functions/v1/rizal-ai-chat" \
  -H "Authorization: Bearer <publishable-key>" \
  -H "apikey: <publishable-key>" \
  -H "Content-Type: application/json" \
  -d '{"message":"Paano pumunta sa Daranak Falls galing Cubao, at magkano ang entrance fee?","history":[],"municipality":"Tanay"}'
```

### 4.9 Client integration

`mobile_app/lib/services/rag_chat_service.dart` (`SupabaseRagChatService`, wired by `ragChatServiceProvider`):

- Sends `message`, the trimmed `history` (≤ 800 chars per turn, errors excluded) and an optional `municipality` scope.
- Accepts `reply`/`answer`/`text`, parses `sources` and `items`, and drops items whose title matches `\btest`.
- Friendly failure copy distinguishes offline, "service not deployed" (404) and generic transport failure; the failed question is kept in the transcript for retry.
- `ChatMessage` carries `municipality`, `sources` and `items`; the UI renders items as tappable cards and flattens Markdown tables so nothing renders as raw pipes on a phone.

---

## 5. Key Mobile & Web Features

### 5.1 Onboarding flow

Four pages in `features/onboarding/onboarding_flow.dart`, gated by `has_completed_onboarding` (loaded before `runApp`, so the router redirect can read it synchronously):

| Page | Content | Action |
|---|---|---|
| 0 | Dark-green splash, gold emblem, "RIZAL / EVENTS / HUB" | Auto-advances after 2 s |
| 1 | Gold emblem badge, `TUKLASRIZAL` eyebrow, "Welcome to Rizal" (34 px), subtitle over the Higantes hero | "Let's Get Started" (gold stadium pill) or "Skip for now" |
| 2 | "What are you interested in?" with six icon cards — Festivals, Food & Drink, Arts & Culture, Faith & Heritage, Nature & Falls, Sports & Adventure — and a pinned Continue bar | Persists interests (`setInterests`) then advances |
| 3 | Cream completion screen, elastic check emblem, corrected copy "Your preferences have been saved. You're now ready to explore Rizal." | "Explore Events" → `complete()` + interest sync |

Wave-2 CTAs use `minimumSize: Size(double.infinity, 54)`, `StadiumBorder`, 32 px horizontal padding, 16 px `w600` text with `letterSpacing: 0.3`, `maxLines: 1`. Persistence keys: `has_completed_onboarding`, `tuklas_onboarding_interests_v1`; `resetOnboarding()` replays the flow from Settings.

### 5.2 Explainable promotion badges

The "Promote Towns and Events" engine (`scorePromoteTownsAndEvents`) scores approved events:

| Signal | Score |
|---|---|
| Category matches a saved interest | +40 |
| Municipality never visited | +30 |
| Municipality visited fewer than 3 times | +15 |
| `is_featured` | +20 |
| `promotion_weight > 1.0` | `round((weight − 1.0) × 40)` |

`core/utils/promotion_reason.dart` converts the winning rules into short, honest labels, and `PromotionReasonPill` renders at most two of them on a card:

| Condition | Label |
|---|---|
| Interest match | `Matches Your Interest` |
| Featured in a busy town (Antipolo, Taytay, Cainta) | `Featured by Tourism Office` |
| Featured in a low-visit town (visit count ≤ 1) | `Featured · Hidden Gem Municipality` |
| `promotion_weight > 1.0` (only if fewer than two reasons) | `LGU Priority Boost` |

POI cards use the same interest/featured logic against `is_promoted`. The pill is theme-aware (forest-on-mist in light, emerald-on-slate in dark), 9.5 px `w600`, with an info glyph, capped at two lines — so "why am I seeing this?" is always answerable without exposing the raw score.

### 5.3 RA 10173-compliant GPS geofencing & Town Welcome Alerts

`GeolocatorGeofenceService` (wired by `geofenceServiceProvider`) is the live implementation:

- **Consent first.** `locationConsentController` persists `tuklas_location_dpa_notice_accepted_v1` and `tuklas_location_alerts_enabled_v1`. The RA 10173 dialog ("Your Location, Your Choice") explains local-only comparison, no upload, no third-party sharing, and an off switch **before** the OS permission prompt. Alerts stay disabled unless consent is recorded.
- **Monitoring.** `startMonitoring()` loads live municipality centres (`geofence_radius_meters`) and up to 500 POIs from Supabase (falling back to the curated 14 centres when offline), checks availability, then subscribes to `Geolocator.getPositionStream` at `LocationAccuracy.medium`, `distanceFilter: 50 m`, plus one immediate `getCurrentPosition()`.
- **Detection.** A town entry fires when the position falls inside a municipality radius (default 5 000 m) and the town id differs from the last one; a POI alert fires within **200 m** of a registered coordinate. Both are cooldown-limited to one notification per 5 minutes per key; demo simulations bypass the cooldown.
- **Availability states.** `ready`, `permissionDenied`, `permissionDeniedForever`, `gpsDisabled`, `error`, each with actionable copy ("Enable it in device Settings", "Device location (GPS) is turned off…").
- **Presentation.** `GeofenceAlertHost` wraps the whole app (installed in `MaterialApp.builder`) and shows a gold banner above the navigator: "Welcome to {municipality}!" with the town description and Tourism Coordinator line, or "Heritage site nearby: {POI}" with the distance. Auto-dismiss after 10 s, manual close, and a separate gold error banner for GPS/permission problems. A `ValueKey` including a version counter makes repeated demo triggers visibly re-animate.
- **Developer demo.** `/geofence-simulator` ("Welcome Alert Preview") injects town entries indoors.

### 5.4 Community submissions & LGU approval workflow

`/submit/:type` (`features/submissions/pages/submit_content_page.dart`), reachable from Home/Explore actions and gated by `requireSignIn`:

| Submission | Write |
|---|---|
| Event | Photo to `tourism-media/events/…`, then `events.insert({ …, status: 'draft', is_featured: false, promotion_weight: 1.0, created_by: auth.uid() })` |
| Place / food / destination | Photo to `tourism-media/pois/…`, then `pois_logistics.insert({ …, poi_type: 'destination', is_promoted: false })` |

Validation covers title/name, municipality, category, description, venue/address, and end ≥ start for events. The coordinator then reviews in the portal: drafts appear in **Events Management** and the Dashboard's pending list where tiers 2–4 approve (publish) or reject them, and can feature them. Only `status = 'approved'` rows are publicly readable (RLS).

> RLS note: `pois_logistics` has no status column and its write policy is staff-only (`pois_manage_staff`). A resident-submitted place therefore only lands if the project adds a permissive insert policy for residents; event drafts are covered by `events_manage_staff` + `created_by` handling, which the project should verify against the live policy set before demoing resident place submissions.

### 5.5 Coordinator inquiry messaging

- **Mobile:** `/coordinators` lists all 14 offices from `municipalities` (guests can read the directory); `/inquiry/:municipalityId` composes an inquiry (`coordinator_inquiries.insert` with `user_id`, `municipality_id`, subject, message, `status = 'open'`). "My inquiries" streams the caller's own rows.
- **Portal:** **Coordinator Inquiries** (tier 2+) shows the municipal inbox; coordinators write `coordinator_reply` and move `status` through `open → in_progress → resolved → closed`.
- Anonymous submissions are impossible: RLS requires `user_id = auth.uid()`.

### 5.6 Persistent Light/Dark theme and accessibility

| Setting | Controller | Key / behaviour |
|---|---|---|
| Theme mode | `core/theme/theme_mode_controller.dart` | `app_theme_mode` = `'light'`/`'dark'`. Never `ThemeMode.system`: a fresh install opens Light, and only an explicit choice switches to Dark. Loaded before the first frame so there is no flash. |
| Text scale | `AppSettingsController` | `settings_text_scale_v1`, range 0.90–1.30 in 0.05 steps, applied via `MediaQuery.textScaler` |
| High contrast | `AppSettingsController` | `settings_high_contrast_v1`; strengthens text/outline contrast in both themes |
| Notification toggles | `AppSettingsController` | event reminders, new events in my area, recommendations |
| Location consent | `LocationConsentController` | DPA notice + alerts enabled |

Both themes are built from the same token set: light uses forest/gold on `#F7F6F2`; dark uses `#0E1512` surfaces with emerald `#5FD08A`, gold accents and adjusted card/divider treatments. Sign-out is confirmed on both clients (`core/utils/logout_confirmation.dart`, portal `Layout` modal) and clears local controllers.

### 5.7 Unified navigation headers

- `TuklasMainHeader` (Home, Explore, Events, Saved): fixed 128 px band with a 38 px utility row (brand mark, search, AI Guide button, notification bell with unread badge) and a 58 px bottom slot. Each tab supplies only its `bottomRow` (`TuklasHeaderHeading` or `TuklasMunicipalitySelector`), so tab switching never changes header height or rhythm.
- `TuklasPageHeader` (secondary pages): gradient band with gold emblem, wordmark, 26 px title, optional subtitle, actions and leading slots.
- Detail routes (`/event/:id`, `/poi/:id`) live inside the shell, with section tabs and bottom action bars, so the header stays consistent while scrolling.

### 5.8 Other mobile modules

| Feature | Location | Notes |
|---|---|---|
| Home / Discovery Hub | `features/home` | Hero carousel, featured events, Promote Towns and Events, municipality & barangay filters, category chips, search field |
| Explore | `features/explore` | POIs, foods, destinations; `PoiDetailPage`, `DirectionsPage` |
| Events | `features/events` | List + filters; detail page with RSVP, directions, calendar, engagement card, review composer |
| Saved | `features/saved` | Device-persisted bookmarks for guests and users |
| Assistant | `features/assistant` | Chat UI over `rizal-ai-chat`, suggestion prompts, source chips, record cards, retry |
| Notifications | `features/notifications` | Derives civic broadcasts/new/upcoming events from approved data; read ids in `tuklas_notifications_read_v1`; no push service |
| Profile / Settings | `features/profile`, `features/settings` | Accessibility, theme, notification toggles, replay onboarding, About, Contact, LGU access request, geofence simulator, logout |
| About / Contact | `features/about`, `features/contact` | Platform overview, data-privacy statement, provincial office details, `mailto:` action |

**Route map** (`core/router/app_router.dart`): shell tabs `/`, `/explore`, `/events`, `/saved`, `/profile`; registered shell branches `/coordinators`, `/assistant`; root routes `/login`, `/signup`, `/settings`, `/notifications`, `/contact`, `/about`, `/lgu-access-request`, `/auth-callback`, `/submit/:type`, `/onboarding`, `/onboarding/interests`, `/directions`, `/inquiry/:municipalityId`, `/geofence-simulator`; detail routes `/poi/:id`, `/event/:id` inside the shell. All routes share a 200 ms fade + 3 % slide transition.

### 5.9 LGU Web Admin modules

| Module | Tier | What it does |
|---|---|---|
| Overview Dashboard | 0+ (approved) | KPIs (approved events, pending approvals, open inquiries, active POIs, province-wide RSVPs for tier 4), municipal distribution chart, one-click approve/reject, inquiry preview, **Municipal Civic Broadcast** (tier 3+) |
| Events Management | 0+ | Full CRUD scoped by municipality/barangay; tier ≤ 1 forced to `draft`; tiers 2–4 approve/reject/feature; gallery upload; promotion weight |
| POIs, Foods & Logistics | 0+ (manage at 2+) | CRUD on `pois_logistics`, `poi_type`, hours, fees, directions, coordinates, image upload, `is_promoted` toggle |
| Coordinator Inquiries | 2+ | Municipal inbox, reply, status workflow |
| Promote Towns and Events | 4 | Edits `municipalities.visitor_priority_boost`, shows per-municipality admin counts |
| Admin & User Approvals | 4 | Document inspection, approve/reject/revoke, tier + municipality assignment, pending badge |

Civic broadcasts insert an immediately approved, featured civic event (`Civic Broadcast: <title>`, `promotion_weight: 1.2`, starts now, ends in 24 h) into the `civic-community` category — that is how municipal advisories reach the mobile feed and notification inbox.

---

## 6. Setup, Environment & Deployment Guide

### 6.1 Prerequisites

| Tool | Version used | Needed for |
|---|---|---|
| Flutter SDK | 3.13+ (repo constraint `^3.13.4`) | `mobile_app` |
| Node.js | 18+ | `web_admin` |
| npm | 9+ | `web_admin` |
| Supabase project | hosted (or CLI-local stack) | backend |
| Supabase CLI | latest | migrations, function deploy, secrets |
| Deno | bundled with Supabase CLI | function type-checking locally (optional) |

### 6.2 Configuration

**Mobile — `mobile_app/lib/core/constants/app_constants.dart`**

| Constant | Purpose |
|---|---|
| `supabaseUrl` | `https://<project-ref>.supabase.co` |
| `supabaseAnonKey` | Publishable/anon key |
| `oauthRedirectUrl` | Derived: `'${Uri.base.origin}/'` on web, `io.supabase.tuklasrizal://login-callback` on mobile |
| `tourismOfficeEmail` / `tourismOfficeTrunkline` | `tourismoffice@rizalprovincialgov.ph`, `(02) 8256-3000` |
| `defaultPageSize` | `20` |

`isSupabaseConfigured` requires an `https://` URL without `your-project` and a non-empty key without `your-anon-key`; otherwise the app runs in mock mode.

**Web admin — `web_admin/.env.local`** (copy `.env.example`, git-ignored)

```dotenv
VITE_SUPABASE_URL=https://<project-ref>.supabase.co
VITE_SUPABASE_ANON_KEY=<publishable-key>
```

`src/lib/supabase.ts` throws at import time when either value is missing. Only the publishable key belongs in the browser bundle.

**Supabase Auth URL configuration:** add the deployed web origin (`https://<origin>/`) and `io.supabase.tuklasrizal://login-callback` to the redirect allowlist, and confirm OTP email templates deliver a 6-digit token.

**Function secrets:** `GROQ_API_KEY`, `GEMINI_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (see §4.8).

### 6.3 Database setup (order matters)

| # | File | Required | Purpose |
|---|---|---|---|
| 1 | `supabase/migrations/001_initial_schema.sql` | yes | Extensions, enums, eleven tables, indexes, RLS helpers and policies |
| 2 | `supabase/seed_full_rizal.sql` (or `seed.sql`) | recommended | 14 municipalities, 6 categories, 28 events, 36 POIs (idempotent) |
| 3 | `supabase/storage_policies.sql` | yes, for uploads | Public `tourism-media` bucket (5 MB) + policies |
| 4 | `supabase/admin_user_approvals.sql` | yes, for LGU approvals | Request/approval columns, `is_level4_admin()`, audit + self-update triggers, tier-4 RLS, private verification bucket |
| 5 | `supabase/review_guardrails.sql` | yes, for server-enforced reviews | `event_reviews`, constraints, `can_review_event()`, review RLS |

Hosted project: paste each file into the SQL Editor in this order. Files 3–5 live outside `migrations/`, so `supabase db reset` will not apply them unless they are moved/copied into `supabase/migrations/`. All three are idempotent.

```bash
supabase start
supabase db reset          # migrations + configured seed
```

Verify the seed:

```bash
BASE="https://<project-ref>.supabase.co/rest/v1"
KEY="<publishable-key>"
curl -s "$BASE/municipalities?select=id,name" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
curl -s "$BASE/events?select=id,title&status=eq.approved" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
curl -s "$BASE/pois_logistics?select=id,name" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
```

Expect 14 municipalities, 28 approved events and 36 POIs.

### 6.4 Running the Flutter app

```bash
cd mobile_app
flutter pub get
flutter run -d chrome           # web preview
flutter run -d <device-id>      # Android/iOS device or emulator
```

Android OAuth note: after any manifest change, uninstall and reinstall before testing the deep link, and verify the browser returns to `io.supabase.tuklasrizal://login-callback`.

Quality gates:

```bash
flutter analyze
flutter test                    # if tests are present
```

### 6.5 Building release bundles

```bash
cd mobile_app
flutter build web --release                     # build/web
flutter build apk --release                     # build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release --split-per-abi     # smaller per-ABI APKs
flutter build appbundle --release               # Play Store AAB
flutter install --release                       # or: adb install -r <apk>
```

- Application ID / namespace: `com.tuklasrizal.tuklas_rizal`.
- Sign with your own keystore (`android/key.properties` + signing config in `android/app/build.gradle.kts`); never commit the keystore or `key.properties`.
- Serve `build/web/` from any static host; add that origin to the Supabase redirect allowlist.
- Location permission is requested only after RA 10173 consent.

### 6.6 Running the web admin

```bash
cd web_admin
npm install
cp .env.example .env.local       # fill in VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY
npm run dev                      # http://localhost:5173
npm run build                    # tsc --noEmit && vite build → dist/
npm run preview                  # serve the production bundle
```

### 6.7 Deploying the AI Edge Function

```bash
# one-time: secrets
npx supabase secrets set GROQ_API_KEY=... GEMINI_API_KEY=... \
  SUPABASE_URL=https://<project-ref>.supabase.co \
  SUPABASE_SERVICE_ROLE_KEY=... --project-ref <project-ref>

# deploy (verify_jwt = false comes from supabase/config.toml)
npx supabase functions deploy rizal-ai-chat --project-ref <project-ref>
```

A harmless "WARNING: Docker is not running" may appear; it does not affect the deploy. Redeploy the function after any change to `index.ts` or `rizal_knowledge.ts`.

### 6.8 Hosting

**Vercel (web admin).** `web_admin/vercel.json` already rewrites all paths to `index.html`. Import the repo, set **Root Directory** `web_admin`, framework preset **Vite**, build `npm run build`, output `dist`, and add `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` for Production and Preview.

**Netlify (web admin).** `web_admin/public/_redirects` contains `/* /index.html 200` and is copied into `dist/`. Base directory `web_admin`, build `npm run build`, publish `web_admin/dist`, same env vars.

**Flutter web.** Upload `mobile_app/build/web/` to any static host and allowlist its origin in Supabase Auth.

### 6.9 Post-deploy verification checklist

1. Sign in with an approved tier-2+ account; the sidebar shows the correct role and municipal scope.
2. Approve a draft event in **Events Management**; confirm it appears in the mobile feed (RLS requires `status = 'approved'`).
3. Publish a **Civic Broadcast** as tier 3+; confirm the featured civic event reaches the mobile feed and notification inbox.
4. As tier 4, open **Admin & User Approvals** → **Inspect & Review**; documents render via signed URLs; approve with a tier and confirm the pending badge decrements.
5. As a tourist, RSVP "I'm Going" to a started event, post a review, then post again and confirm it edits rather than duplicates.
6. Confirm an unapproved account only sees `PendingApprovalPage`, and that foreign writes are rejected by RLS.
7. Confirm `tourism-media` images load without a session while `admin-verification-docs` objects do not.
8. Ask the AI Tour Guide a commute/fee question (expect `provider: groq`), a Tagalog question (mirrored reply), and an off-topic question (redirect). Confirm no `Test …` record appears in cards.
9. Enable location alerts, accept the DPA notice, and use `/geofence-simulator` to confirm the welcome banner.
10. Toggle Light/Dark and text size, then restart to confirm persistence.

### 6.10 Git hygiene

The root `.gitignore` excludes `.env`/`.env.*`, `node_modules/`, `dist/`, `mobile_app/build/`, logs and editor artifacts; `.env.example` stays tracked.

```bash
git status
git ls-files | grep -iE '(^|/)\.env'   # should list only .env.example files
```

---

## 7. Appendix: Known Gaps & Operational Notes

These describe the code as it exists today.

| Area | Current state |
|---|---|
| `event_embeddings` | Table and pgvector extension exist, but the deployed AI guide does not perform vector search; retrieval is keyword + intent ranking over live rows plus the static reference guide. Populating embeddings is future work. |
| Place submissions | `pois_logistics` has no moderation status and its write policy is staff-only; resident place submissions need a permissive insert policy or a separate staging table before they can be demoed end-to-end. |
| Submissions/audit tables | There is no `submissions` or `audit_logs` table; submissions are draft event rows and audit data is stamped on `users` (`approved_at`, `approved_by`, `approval_status`, `review_notes`) and `events.approved_by`. |
| Header height | The shared main header is `128 px` in code (`TuklasMainHeader.height`), though requirement text refers to "124 px". |
| `add_2_calendar` | Declared in `pubspec.yaml`; the implemented action opens a Google Calendar template URL through `url_launcher`. |
| Review gate locality | The mobile gate reads the device-persisted RSVP; the authoritative cross-device check is `can_review_event()` in RLS. |
| Mobile verification docs | JPG/PNG through `image_picker`; PDFs are covered by the optional document-link field and the `mailto:` fallback. The portal accepts PDFs directly. |
| `event_reviews` | Optional table created by `review_guardrails.sql`; reviews persist locally and sync best-effort, so a missing table never loses a local review. |
| `001_initial_schema.sql` | Reconstructed from production introspection — verify constraints, indexes and policies against the live project. |
| Barangay seed | No barangay rows in SQL; the mobile app ships a sample map, the portal reads live rows. |
| Portal pre-migration behaviour | Without `admin_user_approvals.sql`, request/approval writes fail and the inspector shows no documents; the UI degrades via `hasApprovalColumns` instead of crashing. |
| Tier naming | Requirement text pairs Level 1 with barangay officials and Level 2 with "Department Head (Tourism Office)"; code labels tier 2 **Tourism Coordinator** per the terminology rules, and tier 0 is Resident & Tourist. |
| Push notifications | None. The notification inbox is derived from approved data plus local read marks. |
| Mock mode | With placeholder credentials the app runs entirely on mock services; geofencing (live geolocator) and the AI guide (Edge Function) still require the network/Supabase to function. |
| Tests | Coverage is a single Flutter smoke test (`mobile_app/test/widget_test.dart`); the portal has no test suite. Routine gates are `flutter analyze`, `flutter test`, `flutter build web --release` and `npm run build`. |
| Live data | The live project contains at least one QA event titled `Test 1`; the AI function and mobile client both filter `Test …` records from grounding and recommendation cards. |
