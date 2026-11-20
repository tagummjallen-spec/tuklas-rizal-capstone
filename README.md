# TuklasRizal

An LLM-based application for culture, arts and tourism in the **Province of Rizal**.
TuklasRizal pairs a Flutter mobile app for visitors with a React web admin portal for
municipal **Tourism Coordinators**, both backed by a single Supabase (PostgreSQL +
pgvector) project and a RAG Edge Function for the AI tour guide.

- **Mobile app** (`mobile_app/`) — Flutter: discover municipalities, approved events,
  heritage sites, unique Rizal foods, RA 10173-compliant geofence welcome alerts and a
  conversational AI tour guide served by the `rizal-ai-chat` Edge Function (live
  Supabase records + a verified reference guide, Groq with a Gemini fallback).
- **Web admin** (`web_admin/`) — React + Vite: Tourism Coordinators review event
  submissions, manage points of interest and answer visitor inquiries.
- **Backend** (`supabase/`) — migrations, seeds, storage policies, approval and review
  guardrails, plus the `rizal-ai-chat` Edge Function.

📘 **Full technical documentation:** [SYSTEM_DOCUMENTATION.md](SYSTEM_DOCUMENTATION.md)
(architecture, schema & RLS, auth/RBAC, the AI guide, feature flows, deployment).

## Repository layout

```
mobile_app/                     Flutter app (Android, iOS, web)
web_admin/                      React + Vite + TypeScript admin portal
supabase/migrations/            SQL schema (001_initial_schema.sql)
supabase/functions/rizal-ai-chat/  RAG Edge Function (index.ts, rizal_knowledge.ts)
supabase/seed.sql               Small demo seed
supabase/seed_full_rizal.sql    Full idempotent seed: 14 municipalities,
                                6 categories, 28 approved events, 36 POIs
supabase/storage_policies.sql   Public tourism-media bucket + policies
supabase/admin_user_approvals.sql  LGU approval columns, triggers, private docs
supabase/review_guardrails.sql  event_reviews table + eligibility policies
dataset/rizal_tourism_dataset.json   JSON mirror of the full seed
docs/                           Capstone documentation
SYSTEM_DOCUMENTATION.md         Complete system documentation
```

## Prerequisites

| Tool | Version used | Needed for |
| --- | --- | --- |
| Flutter SDK | 3.13+ (Dart 3) | mobile app |
| Node.js | 18+ | web admin |
| npm | 9+ | web admin |
| Supabase project | hosted or local | database |

## 1. Database setup

Create a Supabase project, then run the schema and seed.

**Hosted Supabase:** open *SQL Editor* and run, in order:

1. `supabase/migrations/001_initial_schema.sql`
2. `supabase/seed_full_rizal.sql` (or `supabase/seed.sql` for the small demo set)

**Supabase CLI (local):**

```bash
supabase start
supabase db reset          # applies migrations + seed
```

`seed_full_rizal.sql` is idempotent: municipalities and categories upsert on their
unique `slug`, and events/POIs are inserted only when the same title or name is not
already present in that municipality. Re-running it never duplicates rows.

The app expects the public (publishable/anon) API key only; all privileged access is
enforced by row level security. Never commit a service-role key.

### Verifying the live data

The seed targets the deployed PostgREST schema. A quick read check:

```bash
BASE="https://<project-ref>.supabase.co/rest/v1"
KEY="<publishable-key>"
curl -s "$BASE/municipalities?select=id,name" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
curl -s "$BASE/events?select=id,title&status=eq.approved" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
curl -s "$BASE/pois_logistics?select=id,name" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
```

Expect 14 municipalities, all seeded events with `status=approved`, and the full POI set.

## 2. Run the mobile app

```bash
cd mobile_app
flutter pub get
flutter run -d chrome        # or: flutter run -d <device-id>
```

Supabase URL and publishable key live in
`mobile_app/lib/core/constants/app_constants.dart`. When they are still placeholders
the app starts in mock/demo mode instead of initializing Supabase.

Quality checks:

```bash
flutter analyze
flutter test                 # if tests are present
flutter build web --release  # bundle in build/web
```

## 3. Run the web admin portal

```bash
cd web_admin
npm install
cp .env.example .env.local   # then fill in the values
npm run dev                  # http://localhost:5173
```

`web_admin/.env.local` holds the browser-safe publishable key; it is git-ignored.
`npm run build` runs `tsc --noEmit` followed by `vite build` and writes `dist/`.

```bash
npm run build
npm run preview
```

## 4. Deployment

### Web admin — Vercel

The portal is a single-page app, so deep links must fall back to `index.html`.
`web_admin/vercel.json` already contains the rewrite:

```json
{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }
```

1. Import the repository in Vercel.
2. Set **Root Directory** to `web_admin`.
3. Framework preset: **Vite**; build command `npm run build`; output directory `dist`.
4. Add environment variables `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`
   (Production and Preview).
5. Deploy.

### Web admin — Netlify

`web_admin/public/_redirects` contains `/* /index.html 200`, which Vite copies into
`dist/` at build time.

1. New site from Git; **Base directory** `web_admin`.
2. Build command `npm run build`; publish directory `web_admin/dist`.
3. Add the same `VITE_*` environment variables.
4. Deploy.

### Mobile app — Android APK

```bash
cd mobile_app
flutter pub get
flutter build apk --release            # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release      # Play Store AAB
```

Install the APK on a device:

```bash
flutter install --release
# or
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Release notes:

- For a smaller download use `flutter build apk --release --split-per-abi`.
- Sign with your own keystore before distribution: create `android/key.properties`
  and a signing config in `android/app/build.gradle` (do **not** commit the keystore
  or `key.properties`).
- Location permission is required for the municipal geofence welcome alert; grant it
  on first launch.

### Mobile app — web build

```bash
flutter build web --release
```

Serve `mobile_app/build/web/` from any static host. The build output is git-ignored.

## 5. Git hygiene

The root `.gitignore` excludes `.env`/`.env.*`, `node_modules/`, `dist/`,
`mobile_app/build/`, logs and editor noise; `web_admin/.gitignore` and
`mobile_app/.gitignore` add their own tooling artifacts. `.env.example` stays tracked
as the template.

Check what would be committed before pushing:

```bash
git status
git ls-files | grep -iE '(^|/)\.env'   # should list only .env.example files
```

## Terminology

TuklasRizal uses **Tourism Coordinator** for LGU staff, **Promote Towns and Events**
for the recommendation feature, and never the acronym "RZL".
