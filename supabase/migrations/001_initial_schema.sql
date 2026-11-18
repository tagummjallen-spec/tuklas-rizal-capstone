-- ============================================================================
-- supabase/migrations/001_initial_schema.sql
-- TuklasRizal — PostgreSQL + pgvector schema
--
-- RECONSTRUCTED FROM THE DEPLOYED PRODUCTION DATABASE.
-- The table and column definitions below were produced by introspecting the
-- live Supabase/PostgREST endpoint (selecting each column and rejecting the
-- ones PostgREST reports as unknown). They therefore match production column
-- names and types, and deliberately omit columns that do not exist there
-- (for example `municipalities.province`, `municipalities.is_active`,
-- `users.auth_user_id`, `users.phone`, `pois_logistics.updated_at`,
-- `events.organizer_id`, `events.short_summary`).
--
-- Limits of that introspection, stated plainly:
--   * NOT NULL constraints, column DEFAULTs, check constraints, index
--     definitions and RLS policies are not exposed through PostgREST. They are
--     reconstructed here from observed production behaviour and the app code,
--     and are labelled as reconstructed.
--   * Enum *labels* were verified by probing the API; enum *type names* were
--     not exposed, so the names used here are reconstructed.
--   * Seeding lives in `supabase/seed.sql` and `supabase/seed_full_rizal.sql`,
--     not in this migration.
--
-- Terminology: TuklasRizal, Tourism Coordinator, Promote Towns and Events.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- Enums (labels verified against production; type names reconstructed)
-- ----------------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE event_status AS ENUM ('draft', 'pending', 'approved', 'rejected', 'archived');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE participation_status AS ENUM ('going', 'interested', 'attended');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE inquiry_status AS ENUM ('open', 'in_progress', 'resolved', 'closed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ----------------------------------------------------------------------------
-- municipalities — the 14 municipalities of the Province of Rizal
-- Column order and names match production exactly.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.municipalities (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                     TEXT NOT NULL UNIQUE,
  slug                     TEXT NOT NULL UNIQUE,
  description              TEXT,
  latitude                 DOUBLE PRECISION,
  longitude                DOUBLE PRECISION,
  geofence_radius_meters   INTEGER DEFAULT 5000,
  tourism_office_name      TEXT,
  coordinator_contact_email TEXT,
  coordinator_contact_phone TEXT,
  tourism_office_address   TEXT,
  visitor_priority_boost   NUMERIC(4,2) DEFAULT 1.00,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  public.municipalities IS
  'Municipalities of Rizal; geofence centre + radius drive the visitor welcome alert.';
COMMENT ON COLUMN public.municipalities.visitor_priority_boost IS
  'Promote Towns and Events weighting (production values range 1.00-1.60).';

-- ----------------------------------------------------------------------------
-- barangays — barangays within each municipality (no description in prod)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.barangays (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  municipality_id UUID NOT NULL REFERENCES public.municipalities(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  latitude        DOUBLE PRECISION,
  longitude       DOUBLE PRECISION,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT barangays_municipality_id_name_key UNIQUE (municipality_id, name)
);

-- ----------------------------------------------------------------------------
-- categories — tourism categories used by the mobile filter chips
-- Production column is `icon_name` (not `icon`), and there is no `color`.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  slug        TEXT NOT NULL UNIQUE,
  icon_name   TEXT,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- users — LGU and visitor profiles. `id` is the Supabase Auth user id.
-- Production columns verified: no auth_user_id, phone, profile_image_url
-- (the avatar lives in `avatar_url`); role_tier is an INTEGER, not an enum.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
  id              UUID PRIMARY KEY,           -- = auth.users.id
  email           TEXT NOT NULL,
  full_name       TEXT NOT NULL,
  avatar_url      TEXT,
  role_tier       INTEGER NOT NULL DEFAULT 1, -- 1 Barangay, 2 Dept Head, 3 Mayor/IT, 4 Governor/Provincial
  role_title      TEXT,
  municipality_id UUID REFERENCES public.municipalities(id) ON DELETE SET NULL,
  barangay_id     UUID REFERENCES public.barangays(id) ON DELETE SET NULL,
  is_approved     BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- user_interests — user-selected tourism categories
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_interests (
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, category_id)
);

-- ----------------------------------------------------------------------------
-- events — created by Tourism Coordinators, published after approval
-- Production columns verified: `venue_name` and `how_to_get_there` replace the
-- old `location`/`address` fields; authors are `created_by` / `approved_by`.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.events (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  municipality_id  UUID NOT NULL REFERENCES public.municipalities(id) ON DELETE CASCADE,
  barangay_id      UUID REFERENCES public.barangays(id) ON DELETE SET NULL,
  category_id      UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  created_by       UUID REFERENCES public.users(id) ON DELETE SET NULL,
  approved_by      UUID REFERENCES public.users(id) ON DELETE SET NULL,
  title            TEXT NOT NULL,
  description      TEXT,
  venue_name       TEXT,
  how_to_get_there TEXT,
  latitude         DOUBLE PRECISION,
  longitude        DOUBLE PRECISION,
  start_date       TIMESTAMPTZ NOT NULL,
  end_date         TIMESTAMPTZ NOT NULL,
  image_url        TEXT,
  status           event_status NOT NULL DEFAULT 'draft',
  is_featured      BOOLEAN NOT NULL DEFAULT false,
  promotion_weight NUMERIC(4,2) DEFAULT 1.00,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT events_date_check CHECK (end_date >= start_date)
);

-- ----------------------------------------------------------------------------
-- event_embeddings — pgvector embeddings for RAG semantic search
-- Production has no `model` column.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.event_embeddings (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id   UUID NOT NULL UNIQUE REFERENCES public.events(id) ON DELETE CASCADE,
  embedding  VECTOR(768) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- event_participation — RSVP / attendance (column is `status`, not rsvp_status;
-- there is no participated_at, attendance is the 'attended' label)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.event_participation (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  event_id   UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  status     participation_status NOT NULL DEFAULT 'interested',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT event_participation_user_id_event_id_key UNIQUE (user_id, event_id)
);

-- ----------------------------------------------------------------------------
-- pois_logistics — heritage sites, unique Rizal foods, destinations
-- Production stores the category kind in `poi_type` (TEXT) and has
-- `how_to_get_there`, `operating_hours`, `entrance_fee`, `is_promoted`.
-- There is no updated_at.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pois_logistics (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  municipality_id  UUID NOT NULL REFERENCES public.municipalities(id) ON DELETE CASCADE,
  barangay_id      UUID REFERENCES public.barangays(id) ON DELETE SET NULL,
  category_id      UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  name             TEXT NOT NULL,
  description      TEXT,
  poi_type         TEXT,           -- heritage_site | unique_food | restaurant | destination
  address          TEXT,
  how_to_get_there TEXT,
  operating_hours  TEXT,
  entrance_fee     TEXT,
  latitude         DOUBLE PRECISION,
  longitude        DOUBLE PRECISION,
  image_url        TEXT,
  is_promoted      BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- coordinator_inquiries — visitor inquiries routed to the Tourism Coordinator
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.coordinator_inquiries (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  municipality_id  UUID NOT NULL REFERENCES public.municipalities(id) ON DELETE CASCADE,
  subject          TEXT NOT NULL,
  message          TEXT NOT NULL,
  coordinator_reply TEXT,
  status           inquiry_status NOT NULL DEFAULT 'open',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- Indexes (reconstructed; names follow the production foreign keys)
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_municipalities_slug          ON public.municipalities (slug);
CREATE INDEX IF NOT EXISTS idx_barangays_municipality       ON public.barangays (municipality_id);
CREATE INDEX IF NOT EXISTS idx_categories_slug              ON public.categories (slug);
CREATE INDEX IF NOT EXISTS idx_users_municipality           ON public.users (municipality_id);
CREATE INDEX IF NOT EXISTS idx_users_barangay               ON public.users (barangay_id);
CREATE INDEX IF NOT EXISTS idx_users_role_tier              ON public.users (role_tier);
CREATE INDEX IF NOT EXISTS idx_events_municipality          ON public.events (municipality_id);
CREATE INDEX IF NOT EXISTS idx_events_barangay              ON public.events (barangay_id);
CREATE INDEX IF NOT EXISTS idx_events_category              ON public.events (category_id);
CREATE INDEX IF NOT EXISTS idx_events_status                ON public.events (status);
CREATE INDEX IF NOT EXISTS idx_events_dates                 ON public.events (start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_event_embeddings_event       ON public.event_embeddings (event_id);
CREATE INDEX IF NOT EXISTS idx_event_participation_user     ON public.event_participation (user_id);
CREATE INDEX IF NOT EXISTS idx_event_participation_event    ON public.event_participation (event_id);
CREATE INDEX IF NOT EXISTS idx_pois_municipality            ON public.pois_logistics (municipality_id);
CREATE INDEX IF NOT EXISTS idx_pois_category                ON public.pois_logistics (category_id);
CREATE INDEX IF NOT EXISTS idx_inquiries_municipality       ON public.coordinator_inquiries (municipality_id);
CREATE INDEX IF NOT EXISTS idx_inquiries_user               ON public.coordinator_inquiries (user_id);

-- ============================================================================
-- Row Level Security
-- RECONSTRUCTED: policies are not visible through PostgREST. These reproduce
-- the access rules the apps rely on — anonymous visitors read approved events,
-- POIs, categories and municipalities; authenticated visitors read and manage
-- their own RSVPs, interests and inquiries; approved Tourism Coordinators
-- manage content for their own municipality; tier 4 manages everything.
-- ============================================================================
ALTER TABLE public.municipalities        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.barangays             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_interests        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_embeddings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_participation   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pois_logistics        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coordinator_inquiries ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.current_user_role_tier() RETURNS INTEGER AS $$
  SELECT role_tier FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION public.current_user_municipality_id() RETURNS UUID AS $$
  SELECT municipality_id FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION public.current_user_barangay_id() RETURNS UUID AS $$
  SELECT barangay_id FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION public.is_approved_staff() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND is_approved = true AND role_tier >= 2
  );
$$ LANGUAGE sql STABLE;

-- Public reference data -------------------------------------------------------
DROP POLICY IF EXISTS municipalities_select_public ON public.municipalities;
CREATE POLICY municipalities_select_public ON public.municipalities
  FOR SELECT USING (true);

DROP POLICY IF EXISTS municipalities_manage_tier34 ON public.municipalities;
CREATE POLICY municipalities_manage_tier34 ON public.municipalities
  FOR ALL USING (
    public.is_approved_staff() AND (
      public.current_user_role_tier() = 4
      OR id = public.current_user_municipality_id()
    )
  );

DROP POLICY IF EXISTS barangays_select_public ON public.barangays;
CREATE POLICY barangays_select_public ON public.barangays
  FOR SELECT USING (true);

DROP POLICY IF EXISTS barangays_manage_tier234 ON public.barangays;
CREATE POLICY barangays_manage_tier234 ON public.barangays
  FOR ALL USING (
    public.is_approved_staff() AND (
      public.current_user_role_tier() = 4
      OR municipality_id = public.current_user_municipality_id()
    )
  );

DROP POLICY IF EXISTS categories_select_public ON public.categories;
CREATE POLICY categories_select_public ON public.categories
  FOR SELECT USING (true);

DROP POLICY IF EXISTS categories_manage_tier4 ON public.categories;
CREATE POLICY categories_manage_tier4 ON public.categories
  FOR ALL USING (public.current_user_role_tier() = 4);

-- Profiles --------------------------------------------------------------------
DROP POLICY IF EXISTS users_select_own ON public.users;
CREATE POLICY users_select_own ON public.users
  FOR SELECT USING (id = auth.uid());

DROP POLICY IF EXISTS users_select_staff ON public.users;
CREATE POLICY users_select_staff ON public.users
  FOR SELECT USING (
    public.is_approved_staff() AND (
      public.current_user_role_tier() = 4
      OR municipality_id = public.current_user_municipality_id()
    )
  );

DROP POLICY IF EXISTS users_update_own ON public.users;
CREATE POLICY users_update_own ON public.users
  FOR UPDATE USING (id = auth.uid()) WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS users_insert_self ON public.users;
CREATE POLICY users_insert_self ON public.users
  FOR INSERT WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS user_interests_manage_own ON public.user_interests;
CREATE POLICY user_interests_manage_own ON public.user_interests
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Events ----------------------------------------------------------------------
-- Guests see only approved events; coordinators see and manage their own town.
DROP POLICY IF EXISTS events_select_approved ON public.events;
CREATE POLICY events_select_approved ON public.events
  FOR SELECT USING (
    status = 'approved'
    OR (public.is_approved_staff() AND (
          public.current_user_role_tier() = 4
          OR municipality_id = public.current_user_municipality_id()))
  );

DROP POLICY IF EXISTS events_manage_staff ON public.events;
CREATE POLICY events_manage_staff ON public.events
  FOR ALL USING (
    public.is_approved_staff() AND (
      public.current_user_role_tier() = 4
      OR municipality_id = public.current_user_municipality_id()
    )
  );

-- Embeddings stay internal to the RAG pipeline.
DROP POLICY IF EXISTS event_embeddings_staff ON public.event_embeddings;
CREATE POLICY event_embeddings_staff ON public.event_embeddings
  FOR ALL USING (public.is_approved_staff());

-- Participation ---------------------------------------------------------------
DROP POLICY IF EXISTS event_participation_select_own ON public.event_participation;
CREATE POLICY event_participation_select_own ON public.event_participation
  FOR SELECT USING (
    user_id = auth.uid()
    OR (public.is_approved_staff() AND (
          public.current_user_role_tier() = 4
          OR EXISTS (SELECT 1 FROM public.events e
                     WHERE e.id = event_id
                       AND e.municipality_id = public.current_user_municipality_id())))
  );

DROP POLICY IF EXISTS event_participation_manage_own ON public.event_participation;
CREATE POLICY event_participation_manage_own ON public.event_participation
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Points of interest ----------------------------------------------------------
DROP POLICY IF EXISTS pois_select_public ON public.pois_logistics;
CREATE POLICY pois_select_public ON public.pois_logistics
  FOR SELECT USING (true);

DROP POLICY IF EXISTS pois_manage_staff ON public.pois_logistics;
CREATE POLICY pois_manage_staff ON public.pois_logistics
  FOR ALL USING (
    public.is_approved_staff() AND (
      public.current_user_role_tier() = 4
      OR municipality_id = public.current_user_municipality_id()
    )
  );

-- Coordinator inquiries -------------------------------------------------------
DROP POLICY IF EXISTS inquiries_insert_own ON public.coordinator_inquiries;
CREATE POLICY inquiries_insert_own ON public.coordinator_inquiries
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS inquiries_select_own ON public.coordinator_inquiries;
CREATE POLICY inquiries_select_own ON public.coordinator_inquiries
  FOR SELECT USING (
    user_id = auth.uid()
    OR (public.is_approved_staff() AND (
          public.current_user_role_tier() = 4
          OR municipality_id = public.current_user_municipality_id()))
  );

DROP POLICY IF EXISTS inquiries_update_coordinator ON public.coordinator_inquiries;
CREATE POLICY inquiries_update_coordinator ON public.coordinator_inquiries
  FOR UPDATE USING (
    public.is_approved_staff() AND (
      public.current_user_role_tier() = 4
      OR municipality_id = public.current_user_municipality_id()
    )
  );

-- ============================================================================
-- Notes
-- ============================================================================
-- 1. `users.id` is the Supabase Auth user id; there is no secondary auth column
--    in production, so the helpers compare `id = auth.uid()`.
-- 2. `event_embeddings.embedding` is VECTOR(768); keep the dimension in step
--    with whichever embedding model the RAG pipeline uses.
-- 3. Data seeding is intentionally not part of this migration. Use
--    supabase/seed_full_rizal.sql (idempotent, all 14 municipalities) or the
--    smaller supabase/seed.sql demo set.
-- 4. No "RZL" acronym; LGU title is Tourism Coordinator; the promotion feature
--    is Promote Towns and Events (`municipalities.visitor_priority_boost`,
--    `events.promotion_weight`, `pois_logistics.is_promoted`).
