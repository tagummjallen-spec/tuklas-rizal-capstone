-- ============================================================================
-- supabase/migrations/001_initial_schema.sql
-- TuklasRizal — Initial PostgreSQL + pgvector Schema (Row Level Security enabled)
--
-- Covers: municipalities (14 Rizal towns), barangays, categories,
-- users (4-tier RBAC), user_interests, events, event_embeddings,
-- event_participation, pois_logistics, coordinator_inquiries.
--
-- Form I rules applied:
--   - No "RZL" acronym (use "TuklasRizal" / "Rizal")
--   - LGU title "Tourism Coordinator" (not generic "Admin")
--   - Feature "Promote Towns and Events" (not "Recommendations")
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Enable pgvector extension (for RAG semantic search embeddings)
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS vector;

-- ----------------------------------------------------------------------------
-- Enums
-- ----------------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE user_role_tier AS ENUM ('1','2','3','4');
EXCEPTION WHEN duplicate_object THEN NULL END $$;

DO $$ BEGIN
  CREATE TYPE event_status AS ENUM ('draft','published','archived','cancelled');
EXCEPTION WHEN duplicate_object THEN NULL END $$;

DO $$ BEGIN
  CREATE TYPE rsvp_status AS ENUM ('going','interested','declined');
EXCEPTION WHEN duplicate_object THEN NULL END $$;

DO $$ BEGIN
  CREATE TYPE inquiry_status AS ENUM ('open','in_progress','resolved','closed');
EXCEPTION WHEN duplicate_object THEN NULL END $$;

-- ----------------------------------------------------------------------------
-- core.municipalities — all 14 municipalities of the Province of Rizal
-- ----------------------------------------------------------------------------
CREATE TABLE municipalities (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL UNIQUE,                 -- e.g., "Angono", "Antipolo"
  province        TEXT NOT NULL DEFAULT 'Rizal',
  description     TEXT,
  geofence_lat    DOUBLE PRECISION,
  geofence_lng    DOUBLE PRECISION,
  geofence_radius_m INTEGER DEFAULT 5000,               -- welcome-alert radius (meters)
  tourism_office_contact TEXT,                          -- Tourism Coordinator office contact
  tourism_office_email  TEXT,
  website         TEXT,
  image_url       TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed: all 14 municipalities of the Province of Rizal
INSERT INTO municipalities (name, description, geofence_lat, geofence_lng, geofence_radius_m, tourism_office_contact, website) VALUES
('Angono',        'Art capital of the Philippines; home of the Higantes Festival.', 14.5271, 121.1427, 5000, 'Angono Municipal Tourism Office', NULL),
('Antipolo',      'Provincial capital; pilgrimage site and viewing deck of Metro Manila.', 14.5913, 121.1743, 5000, 'Antipolo City Tourism Office', NULL),
('Baras',         'Rural municipality known for agriculture and nature trails.', 14.4594, 121.2759, 5000, 'Baras Municipal Tourism Office', NULL),
('Binangonan',    'Lakeshore town on Laguna de Bay; site of the Binangonan Petroglyphs.', 14.4750, 121.1883, 5000, 'Binangonan Municipal Tourism Office', NULL),
('Cainta',        'Gateway town to Rizal; known for delicacies and commercial hubs.', 14.5383, 121.1272, 5000, 'Cainta Municipal Tourism Office', NULL),
('Cardona',       'Lakeside municipality along Laguna de Bay.', 14.4367, 121.2486, 5000, 'Cardona Municipal Tourism Office', NULL),
('Jala-Jala',     'Island municipality on Laguna de Bay.', 14.3750, 121.3286, 5000, 'Jala-Jala Municipal Tourism Office', NULL),
('Morong',        'Heritage town with Spanish-era church and stone fortifications.', 14.4972, 121.3272, 5000, 'Morong Municipal Tourism Office', NULL),
('Pililla',       'Wind farm and lake-view municipality.', 14.4406, 121.3422, 5000, 'Pililla Municipal Tourism Office', NULL),
('Rodriguez',     'Formerly Montalban; gateway to the Sierra Madre mountains.', 14.6667, 121.2667, 5000, 'Rodriguez Municipal Tourism Office', NULL),
('San Mateo',     'Residential town along the Marikina River.', 14.6136, 121.1303, 5000, 'San Mateo Municipal Tourism Office', NULL),
('Tanay',         'Mountain resort town; flagship ecotourism destination of Rizal.', 14.5306, 121.2736, 5000, 'Tanay Municipal Tourism Office', NULL),
('Taytay',        'Garment and tiangge capital; Santa Ana de Sapa Parish.', 14.5608, 121.1347, 5000, 'Taytay Municipal Tourism Office', NULL),
('Teresa',        'Small upland municipality with waterfalls and nature spots.', 14.5067, 121.2458, 5000, 'Teresa Municipal Tourism Office', NULL)
ON CONFLICT (name) DO NOTHING;

-- ----------------------------------------------------------------------------
-- core.barangays — barangays within each municipality
-- ----------------------------------------------------------------------------
CREATE TABLE barangays (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  municipality_id UUID NOT NULL REFERENCES municipalities(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  description    TEXT,
  is_active      BOOLEAN NOT NULL DEFAULT true,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT barangays_municipality_name_unique UNIQUE (municipality_id, name)
);

-- ----------------------------------------------------------------------------
-- core.categories — tourism categories (mirrors mobile app filter chips)
-- ----------------------------------------------------------------------------
CREATE TABLE categories (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name      TEXT NOT NULL UNIQUE,        -- Cultural, Festival, Civic, Sports, Health, Food/Heritage
  slug      TEXT NOT NULL UNIQUE,
  description TEXT,
  color     TEXT,
  icon      TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO categories (name, slug, description, color, icon) VALUES
('Cultural',        'cultural',        'Cultural and heritage sites and experiences', '#033300', NULL),
('Festival',        'festival',        'Town festivals and celebrations',            '#ffc800', NULL),
('Civic',           'civic',           'Civic activities and community events',       '#033300', NULL),
('Sports',          'sports',          'Sports events and activities',                '#ffc800', NULL),
('Health',          'health',          'Health and wellness tourism',                 '#033300', NULL),
('Food/Heritage',   'food-heritage',   'Unique Rizal delicacies and food heritage',   '#ffc800', NULL)
ON CONFLICT (name) DO NOTHING;

-- ----------------------------------------------------------------------------
-- auth.users reference (Supabase Auth). We extend with profiles in `users`.
-- ----------------------------------------------------------------------------
CREATE TABLE users (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id      UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  email             TEXT NOT NULL,
  full_name         TEXT NOT NULL,
  role_tier         user_role_tier NOT NULL DEFAULT '1',     -- 1 Barangay, 2 Dept Head, 3 Mayor/IT, 4 Governor/Provincial
  municipality_id   UUID REFERENCES municipalities(id) ON DELETE SET NULL,
  barangay_id       UUID REFERENCES barangays(id) ON DELETE SET NULL,
  phone             TEXT,
  profile_image_url TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT users_role_scope_check CHECK (
    (role_tier IN ('1','2','3') AND municipality_id IS NOT NULL) OR
    (role_tier = '4') OR
    (role_tier = '1' AND barangay_id IS NOT NULL)
  )
);

-- ----------------------------------------------------------------------------
-- core.user_interests — user-selected tourism categories (USER_INTERESTS)
-- ----------------------------------------------------------------------------
CREATE TABLE user_interests (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, category_id)
);

-- ----------------------------------------------------------------------------
-- core.events — events owned/managed by LGU Tourism Coordinators
-- ----------------------------------------------------------------------------
CREATE TABLE events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title           TEXT NOT NULL,
  description     TEXT,
  short_summary   TEXT,
  category_id     UUID REFERENCES categories(id) ON DELETE SET NULL,
  municipality_id UUID NOT NULL REFERENCES municipalities(id) ON DELETE CASCADE,
  barangay_id     UUID REFERENCES barangays(id) ON DELETE SET NULL,
  organizer_id    UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  status          event_status NOT NULL DEFAULT 'draft',
  start_date      TIMESTAMPTZ NOT NULL,
  end_date        TIMESTAMPTZ NOT NULL,
  location        TEXT,
  address         TEXT,
  lat             DOUBLE PRECISION,
  lng             DOUBLE PRECISION,
  image_url       TEXT,
  contact_person  TEXT,              -- Tourism Coordinator contact
  contact_email   TEXT,
  contact_phone   TEXT,
  is_featured     BOOLEAN NOT NULL DEFAULT false,
  promoted_rank   INTEGER DEFAULT 0, -- Rule-Based AI "Promote Towns and Events" boost rank
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT events_date_check CHECK (end_date >= start_date)
);

-- ----------------------------------------------------------------------------
-- core.event_embeddings — pgvector embeddings for RAG semantic search
-- ----------------------------------------------------------------------------
CREATE TABLE event_embeddings (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id  UUID NOT NULL UNIQUE REFERENCES events(id) ON DELETE CASCADE,
  embedding VECTOR(768) NOT NULL,    -- Llama/text-embedding dimension
  model     TEXT NOT NULL DEFAULT 'llama-rag',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- core.event_participation — RSVP / attendance tracking (EVENT_PARTICIPATION)
-- ----------------------------------------------------------------------------
CREATE TABLE event_participation (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id       UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  rsvp_status    rsvp_status NOT NULL DEFAULT 'interested',
  participated_at TIMESTAMPTZ,             -- set when user checks in / attends
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT event_participation_unique UNIQUE (user_id, event_id)
);

-- ----------------------------------------------------------------------------
-- core.pois_logistics — points of interest & logistics (heritage, restaurants, delicacies)
-- ----------------------------------------------------------------------------
CREATE TABLE pois_logistics (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name           TEXT NOT NULL,
  description    TEXT,
  category_id    UUID REFERENCES categories(id) ON DELETE SET NULL,
  municipality_id UUID NOT NULL REFERENCES municipalities(id) ON DELETE CASCADE,
  barangay_id    UUID REFERENCES barangays(id) ON DELETE SET NULL,
  address        TEXT,
  lat            DOUBLE PRECISION,
  lng            DOUBLE PRECISION,
  contact_person TEXT,              -- Tourism Coordinator / establishment contact
  contact_phone  TEXT,
  image_url      TEXT,
  is_active      BOOLEAN NOT NULL DEFAULT true,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- core.coordinator_inquiries — user inquiries routed to municipal Tourism Coordinators
-- ----------------------------------------------------------------------------
CREATE TABLE coordinator_inquiries (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  municipality_id UUID NOT NULL REFERENCES municipalities(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject        TEXT NOT NULL,
  message        TEXT NOT NULL,
  status         inquiry_status NOT NULL DEFAULT 'open',
  responded_at   TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- Indexes
-- ============================================================================
CREATE INDEX idx_municipalities_active ON municipalities(is_active);
CREATE INDEX idx_barangays_municipality ON barangays(municipality_id);
CREATE INDEX idx_categories_active ON categories(is_active);
CREATE INDEX idx_users_auth_user ON users(auth_user_id);
CREATE INDEX idx_users_municipality ON users(municipality_id);
CREATE INDEX idx_users_barangay ON users(barangay_id);
CREATE INDEX idx_users_role_tier ON users(role_tier);
CREATE INDEX idx_events_municipality ON events(municipality_id);
CREATE INDEX idx_events_barangay ON events(barangay_id);
CREATE INDEX idx_events_category ON events(category_id);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_dates ON events(start_date, end_date);
CREATE INDEX idx_event_embeddings_event ON event_embeddings(event_id);
CREATE INDEX idx_event_participation_user ON event_participation(user_id);
CREATE INDEX idx_event_participation_event ON event_participation(event_id);
CREATE INDEX idx_pois_municipality ON pois_logistics(municipality_id);
CREATE INDEX idx_pois_category ON pois_logistics(category_id);
CREATE INDEX idx_inquiries_municipality ON coordinator_inquiries(municipality_id);
CREATE INDEX idx_inquiries_user ON coordinator_inquiries(user_id);

-- pgvector index for RAG semantic search (cosine distance)
CREATE INDEX idx_event_embeddings_cosine ON event_embeddings
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 10);

-- ============================================================================
-- Row Level Security (RLS)
-- ============================================================================
ALTER TABLE municipalities ENABLE ROW LEVEL SECURITY;
ALTER TABLE barangays ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_interests ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_participation ENABLE ROW LEVEL SECURITY;
ALTER TABLE pois_logistics ENABLE ROW LEVEL SECURITY;
ALTER TABLE coordinator_inquiries ENABLE ROW LEVEL SECURITY;

-- Helper: current user's role tier (reads from auth.uid() -> users.role_tier)
CREATE OR REPLACE FUNCTION current_user_role_tier() RETURNS user_role_tier AS $$
  SELECT role_tier FROM users WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION current_user_municipality_id() RETURNS UUID AS $$
  SELECT municipality_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION current_user_barangay_id() RETURNS UUID AS $$
  SELECT barangay_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE;

-- ----------------------------------------------------------------------------
-- municipalities: public read; tiers 3/4 write scoped; tier 4 all
-- ----------------------------------------------------------------------------
CREATE POLICY municipalities_select_public ON municipalities
  FOR SELECT USING (is_active = true);

CREATE POLICY municipalities_insert_tier4 ON municipalities
  FOR INSERT WITH CHECK (current_user_role_tier() = '4');

CREATE POLICY municipalities_update_tier34 ON municipalities
  FOR UPDATE USING (
    current_user_role_tier() IN ('3','4') AND
    (current_user_role_tier() = '3' AND id = current_user_municipality_id() OR current_user_role_tier() = '4')
  );

CREATE POLICY municipalities_delete_tier4 ON municipalities
  FOR DELETE USING (current_user_role_tier() = '4');

-- ----------------------------------------------------------------------------
-- barangays: public read; tier 2+ manage own municipality; tier 4 all
-- ----------------------------------------------------------------------------
CREATE POLICY barangays_select_public ON barangays
  FOR SELECT USING (is_active = true);

CREATE POLICY barangays_manage_tier234 ON barangays
  FOR ALL USING (
    current_user_role_tier() IN ('2','3','4') AND
    (
      municipality_id = current_user_municipality_id() OR
      current_user_role_tier() = '4'
    )
  );

-- ----------------------------------------------------------------------------
-- categories: public read; tier 4 write
-- ----------------------------------------------------------------------------
CREATE POLICY categories_select_public ON categories
  FOR SELECT USING (is_active = true);

CREATE POLICY categories_manage_tier4 ON categories
  FOR ALL USING (current_user_role_tier() = '4');

-- ----------------------------------------------------------------------------
-- users: read own profile; tier 4 read all; manage own profile
-- ----------------------------------------------------------------------------
CREATE POLICY users_select_own ON users
  FOR SELECT USING (auth_user_id = auth.uid());

CREATE POLICY users_select_tier4 ON users
  FOR SELECT USING (current_user_role_tier() = '4');

CREATE POLICY users_update_own ON users
  FOR UPDATE USING (auth_user_id = auth.uid());

CREATE POLICY users_insert_self ON users
  FOR INSERT WITH CHECK (auth_user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- user_interests: users manage their own interests
-- ----------------------------------------------------------------------------
CREATE POLICY user_interests_manage_own ON user_interests
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

-- ----------------------------------------------------------------------------
-- events: public read published; tiers 2+ manage own municipality; tier 4 all
-- ----------------------------------------------------------------------------
CREATE POLICY events_select_public ON events
  FOR SELECT USING (status = 'published' AND is_active_event());

CREATE OR REPLACE FUNCTION is_active_event() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM municipalities m
    WHERE m.id = events.municipality_id AND m.is_active = true
  );
$$ LANGUAGE sql STABLE;

CREATE POLICY events_manage_tier234 ON events
  FOR ALL USING (
    current_user_role_tier() IN ('2','3','4') AND
    (
      municipality_id = current_user_municipality_id() OR
      current_user_role_tier() = '4'
    )
  );

-- ----------------------------------------------------------------------------
-- event_embeddings: service role / tier 4 only (internal RAG)
-- ----------------------------------------------------------------------------
CREATE POLICY event_embeddings_tier4 ON event_embeddings
  FOR ALL USING (current_user_role_tier() = '4');

-- ----------------------------------------------------------------------------
-- event_participation: users manage their own RSVPs
-- ----------------------------------------------------------------------------
CREATE POLICY event_participation_manage_own ON event_participation
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

-- ----------------------------------------------------------------------------
-- pois_logistics: public read; tier 2+ manage own municipality; tier 4 all
-- ----------------------------------------------------------------------------
CREATE POLICY pois_select_public ON pois_logistics
  FOR SELECT USING (is_active = true);

CREATE POLICY pois_manage_tier234 ON pois_logistics
  FOR ALL USING (
    current_user_role_tier() IN ('2','3','4') AND
    (
      municipality_id = current_user_municipality_id() OR
      current_user_role_tier() = '4'
    )
  );

-- ----------------------------------------------------------------------------
-- coordinator_inquiries: users create own; tiers 2+ read own municipality; tier 4 all
-- ----------------------------------------------------------------------------
CREATE POLICY inquiries_insert_own ON coordinator_inquiries
  FOR INSERT WITH CHECK (
    user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

CREATE POLICY inquiries_select_own ON coordinator_inquiries
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

CREATE POLICY inquiries_select_municipality_tier234 ON coordinator_inquiries
  FOR SELECT USING (
    current_user_role_tier() IN ('2','3','4') AND
    (
      municipality_id = current_user_municipality_id() OR
      current_user_role_tier() = '4'
    )
  );

CREATE POLICY inquiries_update_tier234 ON coordinator_inquiries
  FOR UPDATE USING (
    current_user_role_tier() IN ('2','3','4') AND
    (
      municipality_id = current_user_municipality_id() OR
      current_user_role_tier() = '4'
    )
  );

-- ============================================================================
-- Notes
-- ============================================================================
-- 1. All 14 Rizal municipalities are seeded; barangays can be populated later
--    from LGU interviews / official PSGC lists.
-- 2. `event_embeddings.embedding` uses VECTOR(768); adjust dimension to match
--    the chosen Llama embedding model when the real RAG pipeline is wired up.
-- 3. RLS policies enforce the 4-tier RBAC hierarchy from CAPSTONE_REQUIREMENTS.md.
--    Level 1 (Barangay) users can only read public data and manage their own
--    profile/interests; Draft event creation by Level 1 is enforced at the app
--    layer (Supabase `status` default = 'draft' with organizer role_tier '1').
-- 4. No "RZL" acronym used anywhere; LGU title "Tourism Coordinator" used.
--    Feature named "Promote Towns and Events" via `events.promoted_rank`.
