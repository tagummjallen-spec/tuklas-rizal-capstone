# CAPSTONE_REQUIREMENTS.md
# TuklasRizal — Reconciled System Specifications (Manuscript + Form I Panel Revisions)

> **Project:** TuklasRizal: An LLM-Based Application for Culture, Arts and Tourism for the Province of Rizal  
> **Scope:** 14 municipalities of the Province of Rizal  
> **Status:** Foundation scaffolding (Phase 0/1) — Flutter mobile app + Supabase backend first; Web Admin Portal last (Phase 4).  
> **Rule Source:** Reconciled Manuscript + Form I Panel Defense revisions. These rules are binding in code, UI labels, comments, and docs.

---

## 1. Project Context

TuklasRizal is a centralized cultural, arts, and tourism discovery platform covering all **14 municipalities** of the Province of Rizal. It is structured as a monorepo with three deliverables:

| Component | Path | Purpose | Build Phase |
|---|---|---|---|
| Flutter Mobile App | `mobile_app/` | Resident & Tourist UI (discovery, events, coordinator directory, geofencing, AI chat) | Phase 1–3 |
| Supabase Backend | `supabase/` | PostgreSQL, Auth, RBAC, Storage, Edge Functions, pgvector RAG | Phase 1–3 |
| Web Admin Portal | `web_admin/` | LGU Tourism Coordinator portal (4-tier RBAC) | Phase 4 (LAST) |

The mobile app must mirror the UI, design, and flow of the web prototype at `https://visionary-capybara-547515.netlify.app/`.

---

## 2. Binding Form I Rules (MUST be followed in code, UI labels, comments, docs)

| Rule | Requirement |
|---|---|
| **Naming** | Never use the acronym `"RZL"` anywhere in the codebase or UI. Always use `"TuklasRizal"` or `"Rizal"`. |
| **Terminology** | Replace generic `"Admin"` or `"Event Organizer"` labels with proper LGU titles: **`Tourism Coordinator`** (or specific LGU roles). |
| **Feature Naming** | Never label the recommendation section as `"Recommendations"`. Call it **`Promote Towns and Events`** — driven by a Rule-Based AI engine that boosts under-visited municipalities and local events while matching user interests. |

---

## 3. Core Mobile App Features

1. **Authentication & Onboarding** — User login/signup, profile setup, and Tourism Category/Interest selection (`USER_INTERESTS`).
2. **Home / Discovery Hub** — Featured Events, "Promote Towns and Events" (rule-based promotion of lesser-visited towns), Municipality & Barangay filter (all 14 Rizal municipalities + their barangays), and category filters (Cultural, Festival, Civic, Sports, Health, Food/Heritage).
3. **Destinations, Unique Foods & Restaurants** — Dedicated browsing for cultural/heritage sites, tourist spots, local restaurants, and unique Rizal delicacies.
4. **Events & Calendar** — Event details, RSVP/participation tracking (`EVENT_PARTICIPATION`), Bookmarking/Saving events, and Device Calendar integration.
5. **Municipal Tourism Coordinator Directory & Inquiry** — Users can view official tourism office contacts, guides, and send direct inquiries to each municipality's Tourism Coordinator.
6. **Geofencing & Location Services** — Detect when a user enters a municipality's geofence (e.g., Binangonan, Angono, Morong) to trigger a welcome alert showcasing local attractions, events, unique foods, and step-by-step directions ("how to get there").
7. **Conversational AI Assistant (Llama LLM + RAG)** — Chat interface grounded in the curated Rizal dataset via `pgvector` semantic search, answering who, what, when, how to get there, and coordinator contact details.

---

## 4. Web Admin Portal Specification (Phase 4 — BUILD LAST)

Replicates the exact UI, green/yellow provincial aesthetic (`#033300`, `#ffc800`), and 4-tier RBAC hierarchy of the `Web-Admin_2.html` prototype:

| Tier | Role | Scope | Capabilities |
|---|---|---|---|
| **Level 1** | Barangay Officials | Specific Barangay | Create Events as `Draft` only |
| **Level 2** | Department Head (e.g., Tourism Office) | Municipality | Create/approve Events, manage POI & Logistics, view Impact Reports, manage office members |
| **Level 3** | Mayor / Municipal IT Admin | Municipality | All Level 2 capabilities + Municipal Civic Broadcast Center |
| **Level 4** | Governor / Provincial IT Admin | Province-wide (all 14 LGUs) | All Level 3 capabilities + Access Approvals for new LGU coordinator registrations + System Settings |

---

## 5. Data Model Summary (see `supabase/migrations/001_initial_schema.sql`)

Core tables:
- `municipalities` — seeded with all 14 Rizal towns (incl. geofence lat/lng/radius, tourism office contact)
- `barangays` — child of municipalities
- `categories` — Cultural, Festival, Civic, Sports, Health, Food/Heritage
- `users` — Supabase Auth-linked profiles with 4-tier role, municipality, barangay
- `user_interests` — many-to-many users ↔ categories
- `events` — draft/published events owned by LGU users
- `event_embeddings` — pgvector embeddings for RAG/semantic search
- `event_participation` — user RSVP/attendance tracking
- `pois_logistics` — points of interest & logistics (heritage sites, restaurants, delicacies)
- `coordinator_inquiries` — user inquiries routed to municipal Tourism Coordinators

Row Level Security (RLS) is enabled on all tables with policies scoped by role tier and municipality/barangay ownership.

---

## 6. Deferred / Blocked Items (DO NOT BLOCK DEVELOPMENT)

See `docs/DEFERRED_FEATURES.md`. Key items:
- Mock/Stub the RAG & Llama LLM Pipeline with a clean service interface + realistic sample data (Angono Higantes Festival, Binangonan Petroglyphs/Lakeshore, Taytay Tiangge).
- Mock/Simulate Geofence Triggers with a developer debug toggle in the app.

---

## 7. Acceptance Notes

- No `"RZL"` acronym anywhere.
- No generic `"Admin"`/`"Event Organizer"` labels — use `"Tourism Coordinator"`.
- No `"Recommendations"` section — use `"Promote Towns and Events"`.
- Web Admin Portal (`web_admin/`) is explicitly deferred to Phase 4; do not build it before the mobile app and backend are solid.
