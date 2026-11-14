# TuklasRizal Capstone — Project Initialization & Architecture Blueprint

You are the **Lead Software Architect and Full-Stack Developer** for our BSIT Capstone Project:

**"TuklasRizal: An LLM-Based Application for Culture, Arts and Tourism for the Province of Rizal"**

Initialize, organize, and scaffold this entire project cleanly inside our current directory (`tuklas-rizal-capstone`) so we can build it step-by-step alongside **Cline.Ai**, **Hermes**, and **Frebuff**.

---

## 1. PROJECT CONTEXT & RECONCILED REQUIREMENTS (MANUSCRIPT + FORM I PANEL REVISIONS)

We are building a centralized cultural, arts, and tourism discovery platform for the 14 municipalities of the Province of Rizal ("TuklasRizal: An LLM-Based Application for Culture, Arts and Tourism for the Province of Rizal"), consisting of:

1. A **Flutter Mobile App** (`mobile_app/`) for Residents and Tourists.
2. A **Web Admin Portal** (`web_admin/`) for LGU Tourism Coordinators (to be built LAST, after the mobile app and backend are solid).
3. A **Supabase Backend** (`supabase/`) using PostgreSQL, Authentication, RBAC, Storage, Edge Functions, and `pgvector` for RAG semantic search.

**Strict Rules from our Panel Defense (Form I) that MUST be followed in code, UI labels, comments, and docs:**

- **Naming:** Never use the acronym "RZL" anywhere in the codebase or UI. Always use "TuklasRizal" or "Rizal".
- **Terminology:** Replace generic "Admin" or "Event Organizer" labels with proper LGU titles: **"Tourism Coordinator"** (or specific LGU roles).
- **Feature Naming:** Never label the recommendation section as "Recommendations". Call it **"Promote Towns and Events"** (driven by a Rule-Based AI engine that boosts under-visited municipalities and local events while matching user interests).
- **Core Mobile App Features (Must mirror the UI, design, and flow of our web prototype at `https://visionary-capybara-547515.netlify.app/`):**
  - **Authentication & Onboarding:** User login/signup, profile setup, and Tourism Category/Interest selection (`USER_INTERESTS`).
  - **Home / Discovery Hub:** Featured Events, "Promote Towns and Events" (rule-based promotion of lesser-visited towns), Municipality & Barangay filter (all 14 Rizal municipalities + their barangays), and category filters (Cultural, Festival, Civic, Sports, Health, Food/Heritage).
  - **Destinations, Unique Foods & Restaurants:** Dedicated browsing for cultural/heritage sites, tourist spots, local restaurants, and unique Rizal delicacies.
  - **Events & Calendar:** Event details, RSVP/participation tracking (`EVENT_PARTICIPATION`), Bookmarking/Saving events, and Device Calendar integration.
  - **Municipal Tourism Coordinator Directory & Inquiry:** Users can view official tourism office contacts, guides, and send direct inquiries to each municipality's Tourism Coordinator.
  - **Geofencing & Location Services:** Detect when a user enters a municipality's geofence (e.g., Binangonan, Angono, Morong) to trigger a welcome alert showcasing local attractions, events, unique foods, and step-by-step directions ("how to get there").
  - **Conversational AI Assistant (Llama LLM + RAG):** Chat interface grounded in our curated Rizal dataset via `pgvector` semantic search, answering *who, what, when, how to get there, and coordinator contact details*.

---

## 2. WEB ADMIN PORTAL SPECIFICATION (BUILD LAST - PHASE 4)

When we reach Phase 4, the `web_admin/` app will replicate the exact UI, green/yellow provincial aesthetic (`#033300`, `#ffc800`), and 4-tier RBAC hierarchy of our `Web-Admin_2.html` prototype:

- **Level 1 (Barangay Officials):** Scoped to their specific Barangay; can only create Events as `Draft`.
- **Level 2 (Department Head - e.g., Tourism Office):** Scoped to their Municipality; can create/approve Events, manage POI & Logistics, view Impact Reports, and manage office members.
- **Level 3 (Mayor / Municipal IT Admin):** Scoped to their Municipality; adds Municipal Civic Broadcast Center.
- **Level 4 (Governor / Provincial IT Admin):** Province-wide oversight across all 14 LGUs; adds Access Approvals for new LGU coordinator registrations and System Settings.

---

## 3. DEFERRED / BLOCKED ITEMS (DO NOT BLOCK DEVELOPMENT ON THESE)

Because we are still conducting LGU interviews (Angono, Taytay, Binangonan, Capitolyo) and web scraping for our Rizal dataset:

- **Mock/Stub the RAG & Llama LLM Pipeline** for now with a clean service interface and realistic sample data (Angono Higantes Festival, Binangonan Petroglyphs/Lakeshore, Taytay Tiangge) so the UI and chat flow work end-to-end without waiting for the full dataset.
- **Mock/Simulate Geofence Triggers** with a developer debug toggle in the app so we can test municipal entry alerts without physically traveling to each town.

---

## 4. YOUR IMMEDIATE TASKS RIGHT NOW

Do NOT write the entire app in one go. Start by setting up our clean foundation:

1. Create the monorepo directory structure: `docs/`, `mobile_app/`, `web_admin/`, `supabase/migrations/`, `supabase/functions/`, and `dataset/`.
2. Generate `docs/CAPSTONE_REQUIREMENTS.md` summarizing our reconciled system specs, Form I rules, and 4-tier RBAC rules.
3. Generate `docs/DEFERRED_FEATURES.md` listing the data-dependent blockers (full Rizal dataset, Llama LLM accuracy/relevance/clarity testing, physical geofence testing, and ISO/IEC 25010:2023 + TAM evaluations).
4. Generate `supabase/migrations/001_initial_schema.sql` implementing the complete PostgreSQL + `pgvector` schema (`municipalities` seeded with all 14 Rizal towns, `barangays`, `users` with 4-tier roles, `categories`, `user_interests`, `events`, `event_embeddings`, `event_participation`, `pois_logistics`, and `coordinator_inquiries`) with Row Level Security (RLS) policies.
5. Generate `docs/AI_WORKFLOW.md` defining how we will divide upcoming tasks across OpenCode, Cline.Ai, Hermes, and Frebuff.

Once you create these files, show me the summary of what was generated and ask me to confirm before we initialize the Flutter project inside `mobile_app/`.
