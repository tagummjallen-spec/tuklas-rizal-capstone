-- ============================================================================
-- supabase/seed.sql
-- TuklasRizal — Sample Seed Data for Live Supabase Database
--
-- Seeds barangays, events (status = 'approved'), and pois_logistics for
-- Angono, Binangonan, Taytay, Tanay, Antipolo, and Morong.
--
-- Run this in the Supabase SQL Editor AFTER executing
-- supabase/migrations/001_initial_schema.sql.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Helper: resolve municipality IDs by name (seeded in 001_initial_schema.sql)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  angono_id      uuid := (SELECT id FROM municipalities WHERE name = 'Angono' LIMIT 1);
  binangonan_id  uuid := (SELECT id FROM municipalities WHERE name = 'Binangonan' LIMIT 1);
  taytay_id      uuid := (SELECT id FROM municipalities WHERE name = 'Taytay' LIMIT 1);
  tanay_id       uuid := (SELECT id FROM municipalities WHERE name = 'Tanay' LIMIT 1);
  antipolo_id    uuid := (SELECT id FROM municipalities WHERE name = 'Antipolo' LIMIT 1);
  morong_id      uuid := (SELECT id FROM municipalities WHERE name = 'Morong' LIMIT 1);

  -- Category IDs
  cultural_id    uuid := (SELECT id FROM categories WHERE slug = 'cultural' LIMIT 1);
  festival_id    uuid := (SELECT id FROM categories WHERE slug = 'festival' LIMIT 1);
  foodheritage_id uuid := (SELECT id FROM categories WHERE slug = 'food-heritage' LIMIT 1);
  civic_id       uuid := (SELECT id FROM categories WHERE slug = 'civic' LIMIT 1);
BEGIN
  -- ----------------------------------------------------------------------------
  -- Barangays for each municipality
  -- ----------------------------------------------------------------------------
  INSERT INTO barangays (municipality_id, name, description, is_active) VALUES
    -- Angono
    (angono_id, 'San Isidro', 'Barangay in Angono known for Higantes Festival workshops.', true),
    (angono_id, 'San Vicente', 'Home of Balaw-Balaw delicacy restaurants.', true),
    (angono_id, 'Kalayaan', 'Residential barangay near the town proper.', true),
    (angono_id, 'Mahabang Parang', 'Upland barangay with scenic views.', true),
    -- Binangonan
    (binangonan_id, 'Malapad na Bato', 'Barangay near the Petroglyphs site.', true),
    (binangonan_id, 'Tatala', 'Commercial and residential barangay.', true),
    (binangonan_id, 'Pantok', 'Lakeshore barangay along Laguna de Bay.', true),
    (binangonan_id, 'Bining', 'Rural barangay with farmland.', true),
    -- Taytay
    (taytay_id, 'San Juan', 'Tiangge and garment industry hub.', true),
    (taytay_id, 'Santa Ana', 'Home of Santa Ana de Sapa Parish.', true),
    (taytay_id, 'Dolores', 'Residential barangay.', true),
    (taytay_id, 'Muzon', 'Commercial center near Manila East Road.', true),
    -- Tanay
    (tanay_id, 'San Andres', 'Downtown barangay near the town hall.', true),
    (tanay_id, 'Santa Ines', 'Barangay near Daraitan River.', true),
    (tanay_id, 'Patunhay', 'Upland barangay with mountain views.', true),
    (tanay_id, 'Tandang Kutyo', 'Barangay known for local crafts.', true),
    -- Antipolo
    (antipolo_id, 'San Jose', 'Barangay near the Antipolo Cathedral.', true),
    (antipolo_id, 'Santa Cruz', 'Pilgrimage site barangay.', true),
    (antipolo_id, 'Mambugan', 'Commercial barangay near the highway.', true),
    (antipolo_id, 'Mayamot', 'Residential barangay with scenic views.', true),
    -- Morong
    (morong_id, 'San Jose', 'Heritage barangay near the Spanish-era church.', true),
    (morong_id, 'San Pedro', 'Barangay near the Morong town proper.', true),
    (morong_id, 'Lagundi', 'Rural barangay.', true),
    (morong_id, 'Maybangcal', 'Upland barangay.', true)
  ON CONFLICT (municipality_id, name) DO NOTHING;

  -- ----------------------------------------------------------------------------
  -- Events (status = 'approved') for sample municipalities
  -- ----------------------------------------------------------------------------
  INSERT INTO events (
    title, description, short_summary, category_id, municipality_id, barangay_id,
    organizer_id, status, start_date, end_date, location, address, lat, lng,
    image_url, contact_person, contact_email, contact_phone, is_featured,
    promoted_rank, created_at, updated_at
  ) VALUES
    -- Angono — Higantes Festival
    (
      'Higantes Festival',
      'Angono’s iconic giant-puppet cultural festival held every November, featuring higantes paraded through the streets.',
      'Giant-puppet cultural festival in Angono.',
      festival_id, angono_id, NULL,
      'org-angono', 'approved',
      '2026-11-22 08:00:00+08', '2026-11-23 17:00:00+08',
      'Angono Town Proper', 'Angono, Rizal',
      14.5271, 121.1427,
      'https://via.placeholder.com/600x400?text=Higantes+Festival',
      'Angono Tourism Coordinator', 'tourism@angono.gov.ph', '+63 2 8xxx xxxx',
      true, 0, NOW(), NOW()
    ),
    -- Binangonan — Petroglyphs Heritage Walk
    (
      'Petroglyphs Heritage Walk',
      'Guided tour of the ancient Binangonan Petroglyphs, a National Cultural Treasure.',
      'Heritage walk to the Binangonan Petroglyphs.',
      cultural_id, binangonan_id, NULL,
      'org-binangonan', 'approved',
      '2026-11-28 09:00:00+08', '2026-11-28 16:00:00+08',
      'Binangonan Petroglyphs Site', 'Binangonan, Rizal',
      14.4750, 121.1883,
      'https://via.placeholder.com/600x400?text=Petroglyphs',
      'Binangonan Tourism Coordinator', 'tourism@binangonan.gov.ph', '+63 2 8xxx xxxx',
      false, 0, NOW(), NOW()
    ),
    -- Taytay — Tiangge Fair
    (
      'Taytay Tiangge Fair',
      'Weekend tiangge featuring local garments, fashion finds, and Rizal delicacies.',
      'Weekend tiangge marketplace in Taytay.',
      foodheritage_id, taytay_id, NULL,
      'org-taytay', 'approved',
      '2026-12-06 07:00:00+08', '2026-12-07 19:00:00+08',
      'Taytay Municipal Grounds', 'Taytay, Rizal',
      14.5608, 121.1347,
      'https://via.placeholder.com/600x400?text=Taytay+Tiangge',
      'Taytay Tourism Coordinator', 'tourism@taytay.gov.ph', '+63 2 8xxx xxxx',
      true, 0, NOW(), NOW()
    ),
    -- Tanay — Daraitan River Trek
    (
      'Daraitan River Trek',
      'Ecotourism trek to the scenic Daraitan River and Tinipak River rock formations.',
      'River trekking ecotourism adventure in Tanay.',
      cultural_id, tanay_id, NULL,
      'org-tanay', 'approved',
      '2026-12-13 06:00:00+08', '2026-12-13 15:00:00+08',
      'Daraitan, Tanay', 'Tanay, Rizal',
      14.5306, 121.2736,
      'https://via.placeholder.com/600x400?text=Daraitan+River',
      'Tanay Tourism Coordinator', 'tourism@tanay.gov.ph', '+63 2 8xxx xxxx',
      false, 0, NOW(), NOW()
    ),
    -- Antipolo — Pilgrimage to Antipolo Cathedral
    (
      'Pilgrimage to Antipolo Cathedral',
      'Religious pilgrimage to the National Shrine of Our Lady of Peace and Good Voyage.',
      'Religious pilgrimage event in Antipolo City.',
      civic_id, antipolo_id, NULL,
      'org-antipolo', 'approved',
      '2026-12-20 05:00:00+08', '2026-12-20 12:00:00+08',
      'Antipolo Cathedral', 'Antipolo City, Rizal',
      14.5913, 121.1743,
      'https://via.placeholder.com/600x400?text=Antipolo+Cathedral',
      'Antipolo Tourism Coordinator', 'tourism@antipolo.gov.ph', '+63 2 8xxx xxxx',
      false, 0, NOW(), NOW()
    ),
    -- Morong — Morong Heritage Town Tour
    (
      'Morong Heritage Town Tour',
      'Guided walking tour of Morong’s Spanish-era church and stone fortifications.',
      'Heritage walking tour of Morong town.',
      cultural_id, morong_id, NULL,
      'org-morong', 'approved',
      '2026-12-27 08:00:00+08', '2026-12-27 12:00:00+08',
      'Morong Town Proper', 'Morong, Rizal',
      14.4972, 121.3272,
      'https://via.placeholder.com/600x400?text=Morong+Heritage',
      'Morong Tourism Coordinator', 'tourism@morong.gov.ph', '+63 2 8xxx xxxx',
      false, 0, NOW(), NOW()
    )
  ON CONFLICT (id) DO NOTHING;

  -- ----------------------------------------------------------------------------
  -- Points of Interest & Logistics (pois_logistics)
  -- ----------------------------------------------------------------------------
  INSERT INTO pois_logistics (
    name, description, category_id, municipality_id, barangay_id,
    address, lat, lng, contact_person, contact_phone, image_url, is_active,
    created_at, updated_at
  ) VALUES
    -- Angono
    (
      'Angono Petroglyphs', 'Prehistoric rock engravings, the oldest known work of art in the Philippines.',
      cultural_id, angono_id, NULL,
      'Binangonan-Angono Road, Angono, Rizal', 14.5271, 121.1427,
      'Angono Tourism Coordinator', '+63 2 8xxx xxxx',
      'https://via.placeholder.com/600x400?text=Angono+Petroglyphs', true,
      NOW(), NOW()
    ),
    (
      'Balaw-Balaw Restaurant', 'Famous restaurant serving Angono’s exotic delicacy, balaw-balaw.',
      foodheritage_id, angono_id, NULL,
      'Angono, Rizal', 14.5200, 121.1400,
      'Angono Tourism Coordinator', '+63 2 8xxx xxxx',
      'https://via.placeholder.com/600x400?text=Balaw-Balaw', true,
      NOW(), NOW()
    ),
    -- Binangonan
    (
      'Binangonan Petroglyphs', 'Ancient petroglyphs on the lakeshore of Laguna de Bay.',
      cultural_id, binangonan_id, NULL,
      'Binangonan, Rizal', 14.4750, 121.1883,
      'Binangonan Tourism Coordinator', '+63 2 8xxx xxxx',
      'https://via.placeholder.com/600x400?text=Binangonan+Petroglyphs', true,
      NOW(), NOW()
    ),
    (
      'Binangonan Lakeshore', 'Scenic lakeshore area along Laguna de Bay for dining and relaxation.',
      foodheritage_id, binangonan_id, NULL,
      'Lakeshore, Binangonan, Rizal', 14.4800, 121.1900,
      'Binangonan Tourism Coordinator', '+63 2 8xxx xxxx',
      'https://via.placeholder.com/600x400?text=Binangonan+Lakeshore', true,
      NOW(), NOW()
    ),
    -- Taytay
    (
      'Santa Ana de Sapa Parish', 'Historic parish church in Taytay, Rizal.',
      cultural_id, taytay_id, NULL,
      'Taytay, Rizal', 14.5608, 121.1347,
      'Taytay Tourism Coordinator', '+63 2 8xxx xxxx',
      'https://via.placeholder.com/600x400?text=Santa+Ana+Church', true,
      NOW(), NOW()
    ),
    (
      'Taytay Tiangge', 'Weekend marketplace for local garments and Rizal delicacies.',
      foodheritage_id, taytay_id, NULL,
      'Taytay Municipal Grounds', 14.5600, 121.1350,
      'Taytay Tourism Coordinator', '+63 2 8xxx xxxx',
      'https://via.placeholder.com/600x400?text=Taytay+Tiangge', true,
      NOW(), NOW()
    ),
    -- Tanay
    (
      'Daraitan River', 'Scenic river popular for trekking and swimming.',
      cultural_id, tanay_id, NULL,
      'Daraitan, Tanay, Rizal', 14.5200, 121.2600,
      'Tanay Tourism Coordinator', '+63 2 8xxx xxxx',
      'https://via.placeholder.com/600x400?text=Daraitan+River', true,
      NOW(), NOW()
    ),
    (
      'Masungi Georeserve', 'Conservation area with limestone formations and rope courses.',
      cultural_id, tanay_id, NULL,
      'Baras/Tanay border, Rizal', 14.5500, 121.2800,
      'Tanay Tourism Coordinator', '+63 2 8xxx xxxx',
      'https://via.placeholder.com/600x400?text=Masungi+Georeserve', true,
      NOW(), NOW()
    ),
    -- Antipolo
    (
      'Antipolo Cathedral', 'National Shrine of Our Lady of Peace and Good Voyage.',
      civic_id, antipolo_id, NULL,
      'Antipolo City, Rizal', 14.5913, 121.1743,
      'Antipolo Tourism Coordinator', '+63 2 8xxx xxxx',
      'https://via.placeholder.com/600x400?text=Antipolo+Cathedral', true,
      NOW(), NOW()
    ),
    (
      'Hinulugang Taktak', 'National Landmark waterfall and park in Antipolo.',
      cultural_id, antipolo_id, NULL,
      'Antipolo City, Rizal', 14.5800, 121.1600,
      'Antipolo Tourism Coordinator', '+63 2 8xxx xxxx',
      'https://via.placeholder.com/600x400?text=Hinulugang+Taktak', true,
      NOW(), NOW()
    ),
    -- Morong
    (
      'Morong Church', 'Spanish-era church (Saint Jerome Parish Church) in Morong.',
      cultural_id, morong_id, NULL,
      'Morong, Rizal', 14.4972, 121.3272,
      'Morong Tourism Coordinator', '+63 2 8xxx xxxx',
      'https://via.placeholder.com/600x400?text=Morong+Church', true,
      NOW(), NOW()
    ),
    (
      'Morong Stone Fortifications', 'Historic stone fortifications from the Spanish colonial period.',
      cultural_id, morong_id, NULL,
      'Morong, Rizal', 14.5000, 121.3300,
      'Morong Tourism Coordinator', '+63 2 8xxx xxxx',
      'https://via.placeholder.com/600x400?text=Morong+Fortifications', true,
      NOW(), NOW()
    );
END $$;

-- ----------------------------------------------------------------------------
-- Seed complete.
-- ----------------------------------------------------------------------------
SELECT 'Seed data inserted for Angono, Binangonan, Taytay, Tanay, Antipolo, Morong.' AS status;
