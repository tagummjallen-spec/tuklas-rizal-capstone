# AI_WORKFLOW.md
# TuklasRizal — Multi-Agent Orchestration Guide

> Defines how upcoming development tasks are divided across **OpenCode** (Lead Architect / Full-Stack), **Cline.Ai**, **Hermes**, and **Frebuff**.
>
> Principle: **OpenCode owns architecture, schema, and integration seams.** Each agent owns clearly bounded deliverables. Do not write the entire app in one go — build the mobile app and backend first; Web Admin Portal is Phase 4 (LAST).

---

## 1. Agent Roles & Boundaries

| Agent | Role | Primary Ownership |
|---|---|---|
| **OpenCode** | Lead Software Architect & Full-Stack Developer | Monorepo structure, Supabase schema/RLS/Edge Functions, API/service contracts, CI/lint, cross-agent integration, final review & merge |
| **Cline.Ai** | Flutter Mobile App Developer | `mobile_app/` — UI, screens, navigation, state management, geofencing debug toggle, chat UI, local storage |
| **Hermes** | Backend / Supabase Engineer | `supabase/` — migrations, Edge Functions, RLS policies, Storage buckets, pgvector RAG service stub, auth hooks |
| **Frebuff** | QA / Test / Data Engineer | `dataset/` — mock JSON/CSV, sample data seeding scripts, test fixtures, evaluation instruments (ISO/IEC 25010:2023 + TAM), bug triage |

---

## 2. Workflow Rules

1. **One deliverable at a time.** No agent starts a new feature until the current one is reviewed and merged by OpenCode.
2. **Interface contracts first.** Hermes/OpenCode define Supabase + Edge Function contracts before Cline.Ai consumes them.
3. **Form I rules bind everyone.** No `"RZL"`, no generic `"Admin"`/`"Event Organizer"` (use `"Tourism Coordinator"`), no `"Recommendations"` (use `"Promote Towns and Events"`).
4. **Mock-first for blocked items.** RAG/Llama and geofencing are mocked/stubbed (see `docs/DEFERRED_FEATURES.md`) so UI work is never blocked.
5. **OpenCode reviews and merges.** All PRs/commits must be reviewed by OpenCode before merging to `main`.

---

## 3. Phase Plan

| Phase | Focus | Lead Agent(s) | Deliverables |
|---|---|---|---|
| **Phase 0** | Foundation | OpenCode | Monorepo dirs, `CAPSTONE_REQUIREMENTS.md`, `DEFERRED_FEATURES.md`, `AI_WORKFLOW.md`, `001_initial_schema.sql` |
| **Phase 1** | Supabase backend | Hermes + OpenCode | Migrations, RLS, auth, Storage, Edge Function stubs, seed script |
| **Phase 2** | Mobile app core | Cline.Ai + OpenCode | Flutter project init, auth/onboarding, Discovery Hub, "Promote Towns and Events", categories, municipality/barangay filters |
| **Phase 3** | Mobile app advanced | Cline.Ai + Hermes + Frebuff | Events/RSVP, POI/foods, coordinator directory+inquiry, geofence debug toggle, mock RAG chat UI, dataset mocks |
| **Phase 4** | Web Admin Portal | OpenCode + Cline.Ai + Hermes | `web_admin/` 4-tier RBAC portal (green/yellow `#033300`/`#ffc800`) — built LAST |

---

## 4. Task Division (Upcoming, after Phase 0)

### OpenCode — Architecture & Integration
- Review and merge all agent deliverables
- Define Supabase ↔ Flutter API contracts
- Scaffold CI/lint/format tooling
- Final `001_initial_schema.sql` review and RLS audit
- Phase 4 Web Admin portal architecture (when reached)

### Cline.Ai — Flutter Mobile App (`mobile_app/`)
- `flutter create` + project config (after OpenCode confirmation)
- Auth screens (login/signup) + profile setup
- Onboarding: Tourism Category/Interest selection (`USER_INTERESTS`)
- Home / Discovery Hub: Featured Events, "Promote Towns and Events", Municipality & Barangay filter, category chips
- Destinations / Unique Foods / Restaurants browsing
- Events & Calendar: details, RSVP (`EVENT_PARTICIPATION`), bookmarks, device calendar
- Municipal Tourism Coordinator Directory & Inquiry
- Geofencing + debug toggle for simulated municipal entry
- Conversational AI Assistant chat UI (bound to Hermes mock RAG service)

### Hermes — Supabase Backend (`supabase/`)
- Apply `001_initial_schema.sql` + seed script (14 municipalities, categories)
- Auth providers + RBAC helper functions (`current_user_role_tier`, etc.)
- Edge Functions: mock RAG/Llama endpoint, coordinator inquiry router, notification stub
- Storage buckets: event images, POI images, profile avatars
- `pgvector` index maintenance; embedding backfill script
- RLS policy audit with OpenCode

### Frebuff — Data, QA, & Evaluation (`dataset/`)
- Mock JSON/CSV: Angono Higantes Festival, Binangonan Petroglyphs/Lakeshore, Taytay Tiangge
- Seed script for Supabase mock data
- Test fixtures for events, POIs, inquiries, participations
- Bug triage and test-case log
- Evaluation instruments: ISO/IEC 25010:2023 heuristics + TAM survey (deferred, prepared now)

---

## 5. Communication & Handoffs

- **Contracts:** Hermes/OpenCode publish endpoint + schema contracts (OpenAPI-ish markdown in `docs/` or `supabase/functions/`).
- **Mocks:** Frebuff publishes dataset + expected responses; Cline.Ai builds against them.
- **Blockers:** Raised immediately to OpenCode; deferred items recorded in `docs/DEFERRED_FEATURES.md`.
- **Merge:** OpenCode performs final review before any merge to `main`.
