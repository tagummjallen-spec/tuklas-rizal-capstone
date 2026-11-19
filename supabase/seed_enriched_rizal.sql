-- ============================================================================
-- supabase/seed_enriched_rizal.sql
-- TuklasRizal — Enriched Province of Rizal tourism seed (verified public data)
--
-- Adds 20 NEW points of interest (one or more per municipality, all 14 covered)
-- and 2 NEW upcoming cultural/civic events that are NOT in seed_full_rizal.sql.
-- Every fact below was gathered on 2026-11-19 from the official Province of
-- Rizal website (rizalprovince.ph), official municipal websites, the Official
-- Gazette, the Supreme Court E-Library, the Department of Tourism, and the
-- Manila Bulletin report sourced from the Angono Tourism Office. Source URLs
-- are listed in comments above each block and each row.
--
-- PREREQUISITE: run supabase/seed_full_rizal.sql first (municipalities and
-- categories must exist). Rows referencing a missing municipality/category
-- are skipped, never invented.
--
-- IDEMPOTENT: safe to re-run in the Supabase SQL Editor.
--   * categories upsert with ON CONFLICT (slug) DO NOTHING;
--   * events/POIs insert only when the same title/name is not already present
--     in that municipality (WHERE NOT EXISTS), plus ON CONFLICT DO NOTHING as
--     a safety net. Re-running never duplicates rows and never overwrites
--     existing data.
--
-- DATA POLICY (no invented details):
--   * Phone numbers, emails, addresses, hours, fees and dates appear ONLY as
--     published by the cited sources. Fields without a published value are
--     left NULL rather than guessed.
--   * Municipal tourism office contacts reused from seed_full_rizal.sql,
--     which documents its official LGU / provincial / Citizen's Charter
--     sources. Where a municipality has no published email/phone, the
--     verified Rizal Provincial Tourism Office is given as coordination
--     point: tourismoffice@rizalprovincialgov.ph / 8256-3000 loc. 4241/4242
--     (Ms. Marielle R. Ludovico), per
--     https://rizalprovince.ph/pages/tourism-contactus.html (fetched 2026-11-19).
--   * Coordinates follow the municipal-centre convention of
--     seed_full_rizal.sql (approximate; the deployed geofence uses the same
--     centres). Two exceptions reuse the seed's published cluster coords:
--     Payaran Falls (Wawa area) and Kawayan Farm (Halayhayin wind-farm area).
--   * Event dates: National Arts Month is February of EVERY year by
--     Proclamation No. 683, s. 1991; Angono Day is August 19 (municipal
--     independence, 1938). The 2027 editions below follow those verified
--     annual schedules; exact day-by-day programs are published by the LGU
--     nearer the date.
--
-- VERIFIED BUT EXCLUDED (honesty notes):
--   * Antipolo's 400th anniversary of the arrival of Nuestra Senora de la Paz
--     y Buen Viaje (1626-2026) was commemorated June 19, 2026 (antipolo.ph) —
--     already past, so not seeded as an upcoming event.
--   * 33rd Anniversary of Guronasyon launched August 2026 (rizalprovince.ph
--     news) — already past.
--   * All other municipal festivals listed on the provincial festival page
--     (Higantes, SuMaKaH/Maytime, Tromba, Binalayan, SumBingTik, Kaluskos,
--     D'Dalaylay, Pamitinan, Kakanin, Hane, Rodeo) are ALREADY in
--     seed_full_rizal.sql and are not duplicated here.
--   * tanay.gov.ph and binangonan.gov.ph are Cloudflare-gated and could not
--     be fetched; morong.gov.ph is Morong, BATAAN (not Rizal) and was not used.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Categories — idempotent re-assert of the six existing categories.
--    Same values as seed_full_rizal.sql; ON CONFLICT (slug) DO NOTHING keeps
--    any existing rows untouched.
-- ----------------------------------------------------------------------------
INSERT INTO public.categories (name, slug, icon_name, description)
VALUES
  ('Cultural & Arts', 'cultural-arts', 'palette',
   'Museums, galleries, petroglyphs, local artisans and heritage landmarks.'),
  ('Festival', 'festival', 'celebration',
   'Town fiestas, Higantes Festival, Hamaka Festival and cultural parades.'),
  ('Food & Heritage', 'food-heritage', 'restaurant',
   'Unique Rizal delicacies, suman, kasuy, bibingka and lakeside restaurants.'),
  ('Eco-Tourism & Nature', 'eco-tourism', 'landscape',
   'Waterfalls, mountain trails, wind farms, caves and nature reserves.'),
  ('Civic & Community', 'civic-community', 'account_balance',
   'Municipal civic programs, heritage walks and community exhibits.'),
  ('Sports & Recreation', 'sports-recreation', 'directions_bike',
   'Mountain biking trails, marathons and outdoor adventure activities.')
ON CONFLICT (slug) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. NEW upcoming cultural / civic events (not in seed_full_rizal.sql)
-- ----------------------------------------------------------------------------
INSERT INTO public.events (
  municipality_id, barangay_id, category_id, title, description, venue_name,
  how_to_get_there, latitude, longitude, start_date, end_date, image_url,
  status, is_featured, promotion_weight
)
SELECT
  m.id, NULL, c.id, v.title, v.description, v.venue_name,
  v.how_to_get_there, v.latitude, v.longitude,
  v.start_date::timestamptz, v.end_date::timestamptz, NULL,
  'approved', v.is_featured, v.promotion_weight
FROM (VALUES
  -- [E1] National Arts Month 2027 sa Angono (February 1-28, 2027)
  -- Sources (fetched 2026-11-19):
  --   https://www.officialgazette.gov.ph/1991/01/28/proclamation-no-683/
  --     (Proclamation No. 683, s. 1991: February of EVERY year is National
  --      Arts Month; all government agencies enjoined to hold activities)
  --   https://angono.gov.ph/about-angono-tourism/
  --     (Angono Tourism lists National Arts Month among its annual celebrations)
  --   https://angono.gov.ph/national-arts-month-2025-celebration/
  --     (2025 municipal calendar of activities, theme "Ani ng Sining, Diwa
  --      at Damdamin")
  -- Dates follow the statutory February schedule; the LGU publishes the
  -- day-by-day calendar nearer the date.
  ('angono', 'cultural-arts', 'National Arts Month 2027 sa Angono',
   'February is National Arts Month by virtue of Proclamation No. 683, s. 1991, and the Art Capital of the Philippines marks it every year with a municipal calendar of activities. Angono — the only town to produce two National Artists, Carlos "Botong" Francisco (Visual Arts) and Lucio San Pedro (Music) — celebrates with art exhibits, painting and sketching workshops, theater and musical performances across its galleries, museums and public spaces. The 2025 municipal edition carried the theme "Ani ng Sining, Diwa at Damdamin". Tourism office: Angono Municipal Tourism, Culture and the Arts Office, angonotourismoffice@gmail.com / (02) 8661-3646.',
   'Angono Municipal Grounds, galleries and museums (Blanco Family Museum, Botong Francisco Museum, Nemiranda Arthouse)',
   'From Shaw Blvd or Cubao, take a UV Express or jeepney bound for Angono and alight at Angono Town Plaza; the galleries and museums are reached by tricycle from the plaza.',
   14.5266, 121.1536, '2027-02-01T08:00:00+08:00', '2027-02-28T21:00:00+08:00', false, 1.10),

  -- [E2] Angono Day 2027: 89th Founding Anniversary & Cultural Night (Aug 19, 2027)
  -- Sources (fetched 2026-11-19):
  --   https://mb.com.ph/2026/08/20/angono-marks-88th-founding-anniversary-with-monthlong-cultural-festivities
  --     (Manila Bulletin, Aug 20, 2026; photos/program from the Angono Tourism
  --      Office: Angono Day Aug 19, 2026 = 88th anniversary of independence as
  --      a municipality on Aug 19, 1938 by executive order of Pres. Manuel L.
  --      Quezon; pueblo since 1766. Month-long August cultural festivities:
  --      morning Mass at St. Clement, flower/seedling offering at the Quezon
  --      monument, parade along M.L. Quezon Street, cultural night and Angono
  --      Concert Band concert at the municipal gymnasium.)
  --   https://angono.gov.ph/about-angono-tourism/
  --     (lists "Angono Day & Cultural Night" among annual celebrations)
  --   https://en.wikipedia.org/wiki/List_of_festivals_in_the_Philippines
  --     (Quezon Day / Angono Day, August 19)
  -- 2027 = 89th anniversary (2027 - 1938). Main day seeded; the month-long
  -- August pattern follows the 2026 edition reported above.
  ('angono', 'civic-community', 'Angono Day 2027: 89th Founding Anniversary & Cultural Night',
   'Angono Day marks the town''s establishment as an independent municipality on August 19, 1938 through an executive order signed by President Manuel L. Quezon (Angono was first created as a pueblo in 1766). The 2026 edition — the 88th anniversary — was a month-long August celebration led by the Municipal Tourism Office: a morning Mass at the Diocesan Shrine and Parish of St. Clement, offering of flowers and fruit-tree seedlings at the Quezon monument fronting the town hall, a parade along M.L. Quezon Street, art exhibits, theater performances, workshops, and a cultural night and thanksgiving plus an Angono Concert Band concert at the municipal gymnasium. The 2027 edition marks the 89th anniversary. Tourism office: Angono Municipal Tourism, Culture and the Arts Office, angonotourismoffice@gmail.com / (02) 8661-3646.',
   'Angono Municipal Hall, Plaza Rizal & Angono Municipal Gymnasium',
   'From Shaw Blvd or Cubao, take a UV Express or jeepney bound for Angono and alight at Angono Town Plaza; the municipal hall, Quezon monument and gymnasium are in the Poblacion around the plaza.',
   14.5266, 121.1536, '2027-08-19T06:00:00+08:00', '2027-08-19T21:00:00+08:00', true, 1.20)
) AS v(municipality_slug, category_slug, title, description, venue_name,
       how_to_get_there, latitude, longitude, start_date, end_date,
       is_featured, promotion_weight)
JOIN public.municipalities m ON m.slug = v.municipality_slug
LEFT JOIN public.categories c ON c.slug = v.category_slug
WHERE NOT EXISTS (
  SELECT 1
  FROM public.events e
  WHERE e.municipality_id = m.id
    AND e.title = v.title
)
ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. NEW points of interest — 20 verified POIs across all 14 municipalities.
--    None of these names exists in seed_full_rizal.sql.
-- ----------------------------------------------------------------------------
INSERT INTO public.pois_logistics (
  municipality_id, barangay_id, category_id, name, description, poi_type,
  address, how_to_get_there, operating_hours, entrance_fee, latitude, longitude,
  image_url, is_promoted
)
SELECT
  m.id, NULL, c.id, v.name, v.description, v.poi_type, v.address,
  v.how_to_get_there, v.operating_hours, v.entrance_fee, v.latitude, v.longitude,
  NULL, v.is_promoted
FROM (VALUES
  -- [P01] ANGONO — Angono-Binangonan Petroglyphs
  -- Sources: https://rizalprovince.ph/pages/tourism-nature.html and
  --          https://rizalprovince.ph/pages/trade%20and%20commerce.html
  -- (127 human/animal figures, circa 3000 B.C., "most ancient Filipino relic
  --  ever discovered"; 45-minute drive from the provincial capitol, maintained
  --  access roads.) Coordinates: Angono municipal centre (approximate).
  ('angono', 'cultural-arts', 'Angono-Binangonan Petroglyphs',
   'The most ancient Filipino relic ever discovered, according to the Provincial Government of Rizal: about 127 drawings of human and animal figures engraved on a rock wall at the Angono-Binangonan boundary, dated to circa 3000 B.C. The site is about a 45-minute drive from the Rizal Provincial Capitol, with fully maintained access roads. Tourism office: Angono Municipal Tourism, Culture and the Arts Office, angonotourismoffice@gmail.com / (02) 8661-3646.',
   'heritage_site', 'Angono-Binangonan boundary, Rizal',
   'From Antipolo, ride a Binangonan-bound jeepney or UV Express via Manila East Road and alight at the petroglyphs site on the Angono-Binangonan boundary; the provincial tourism office notes it is about 45 minutes from the Rizal Provincial Capitol by car.',
   NULL, NULL, 14.5266, 121.1536, true),

  -- [P02] ANGONO — Botong Francisco Museum & Street Murals
  -- Sources: https://rizalprovince.ph/pages/tourism.html and
  --          https://rizalprovince.ph/pages/tourism-museum.html
  -- (265A Doña Aurora St; murals along Doña Aurora St, Brgy. Poblacion Itaas;
  --  10 minutes from Blanco Family Museum; listed works.)
  ('angono', 'cultural-arts', 'Botong Francisco Museum & Street Murals',
   'Museum and street-mural gallery honoring Carlos "Botong" Francisco, one of the greatest Filipino visual artists and muralists, at 265A Doña Aurora St. His historical pieces — Blood Compact, First Mass at Limasawa, The Martyrdom of Rizal, Bayanihan, Magpupukot, Fiesta and Sandugo — are represented in murals of rural life along Doña Aurora Street of Brgy. Poblacion Itaas, about 10 minutes from the Blanco Family Museum. Tourism office: Angono Municipal Tourism, Culture and the Arts Office, angonotourismoffice@gmail.com / (02) 8661-3646.',
   'heritage_site', '265A Doña Aurora St., Brgy. Poblacion Itaas, Angono, Rizal',
   'From Angono Town Plaza, walk or take a tricycle to Doña Aurora Street in Brgy. Poblacion Itaas; the museum is at 265A and the street murals line the same street.',
   NULL, NULL, 14.5266, 121.1536, true),

  -- [P03] ANGONO — St. Clement Parish Church
  -- Sources: https://rizalprovince.ph/pages/tourism-churches.html
  -- (parish established 1933; records of a chapel back to 1571) and
  -- https://mb.com.ph/2026/08/20/angono-marks-88th-founding-anniversary-with-monthlong-cultural-festivities
  -- (Diocesan Shrine and Parish of St. Clement; Angono Day morning Mass.)
  ('angono', 'cultural-arts', 'St. Clement Parish Church (Diocesan Shrine)',
   'The parish church of Angono, officially established in 1933, though records of a visita, chapel or church in the area go back to 1571, when Angono was first mentioned in Fray Gaspar San Andres'' "Conquistas delas Islas Filipinas". Now a diocesan shrine, it is the seat of the San Clemente devotion honored by the Higantes Festival and the starting point of the Angono Day morning Mass. Tourism office: Angono Municipal Tourism, Culture and the Arts Office, angonotourismoffice@gmail.com / (02) 8661-3646.',
   'heritage_site', 'Doña Aurora St., Angono, Rizal',
   'From Shaw Blvd or Cubao, take a UV Express or jeepney bound for Angono and alight at Angono Town Plaza; the church stands on Doña Aurora Street in the Poblacion.',
   NULL, 'Free', 14.5266, 121.1536, false),

  -- [P04] ANGONO — Balaw-Balaw Specialty Restaurant
  -- Source: https://rizalprovince.ph/pages/tourism-foods.html
  -- (Doña Justa St; 12 kinds of sinigang; kanduli, hito, dalag; itik,
  --  ginataang kuhol, sinabawang balut; trademark Minaluto; kare-kare,
  --  ihaw-ihaw, kaldereta.) Name verified from the page heading
  -- "BALAW BALAW SPECIALTY RESTAURANT".
  ('angono', 'food-heritage', 'Balaw-Balaw Specialty Restaurant',
   'Angono''s specialty restaurant on Doña Justa Street, listed by the provincial tourism office for authentic Filipino cuisine cooked the traditional way: an impressive array of 12 kinds of sinigang, lake fishes native to Angono such as kanduli, hito and dalag, exotic fare like itik (native duck), ginataang kuhol and sinabawang balut, and the trademark Minaluto, alongside classics like kare-kare, ihaw-ihaw and kaldereta. Tourism office: Angono Municipal Tourism, Culture and the Arts Office, angonotourismoffice@gmail.com / (02) 8661-3646.',
   'restaurant', 'Doña Justa St., Angono, Rizal',
   'From Angono Town Plaza, take a tricycle to Doña Justa Subdivision (about five minutes); Balaw-Balaw is beside the Nemiranda Arthouse.',
   NULL, NULL, 14.5266, 121.1536, true),

  -- [P05] ANTIPOLO — Hinulugang Taktak Falls
  -- Sources: https://rizalprovince.ph/pages/tourism-nature.html
  -- (Taktak Road, Brgy. Dela Paz; bell legend; one of the most important
  --  landscapes in Rizal) and
  -- https://rizalprovince.ph/pages/hinulugangtaktak.html
  -- (provincial "Save Hinulugang Taktak" rehabilitation program.)
  ('antipolo', 'eco-tourism', 'Hinulugang Taktak Falls',
   'A waterfall on Taktak Road, Brgy. Dela Paz, considered one of the most important landscapes in the Province of Rizal and part of Antipolo''s natural and cultural heritage. Legend has it that in the 16th century a local priest was forced by the people to drop the church bell into the river because of its harsh, unbearably loud sound during the Angelus — hence "Hinulugan Taktak", literally "where the bell was dropped". Once a popular summer destination, it is the subject of the provincial government''s Save Hinulugang Taktak rehabilitation program. Tourism office: Antipolo City Culture, Arts and Tourism Promotions Office (AnCCATPO), antipolotourism@gmail.com.',
   'destination', 'Taktak Road, Brgy. Dela Paz, Antipolo City',
   'From Antipolo Cathedral or Sumulong Park, hire a tricycle to the Hinulugang Taktak entrance on Taktak Road, Brgy. Dela Paz.',
   NULL, NULL, 14.5842, 121.1763, true),

  -- [P06] ANTIPOLO — Boso-Boso Church
  -- Source: https://rizalprovince.ph/pages/tourism-churches.html
  -- (Nuestra Señora de la Annunciata Parish Church, Sitio Old Boso-Boso,
  --  Brgy. San Jose, Antipolo City.)
  ('antipolo', 'cultural-arts', 'Boso-Boso Church (Nuestra Señora de la Annunciata Parish)',
   'The Nuestra Señora de la Annunciata Parish Church, also known as Bosoboso Church or Boso-Boso Church, is a Roman Catholic parish church in Sitio Old Boso-Boso, Barangay San Jose, Antipolo City — a historic church of the upland villages outside the city proper. Tourism office: Antipolo City Culture, Arts and Tourism Promotions Office (AnCCATPO), antipolotourism@gmail.com.',
   'heritage_site', 'Sitio Old Boso-Boso, Brgy. San Jose, Antipolo City',
   'From Antipolo City proper, travel to Brgy. San Jose and ask for Sitio Old Boso-Boso; hire a tricycle for the final leg to the church.',
   NULL, 'Free', 14.5842, 121.1763, false),

  -- [P07] BARAS — Palo Alto Falls
  -- Source: https://rizalprovince.ph/pages/tourism-nature.html
  -- (Brgy. Pinugay; Valle St; along Marcos Highway near Baras-Tanay boundary;
  --  60-foot cascade into a wide pool draining to Laguna Lake; 249 steps;
  --  public jeepneys from Antipolo City / Masinag and Cogeo to Palo Alto pass
  --  the gate.)
  ('baras', 'eco-tourism', 'Palo Alto Falls',
   'A waterfall at the foot of the Sierra Madre Mountain Range in Brgy. Pinugay, Baras, along Marcos Highway near the Baras-Tanay boundary, about an hour from Metropolitan Manila. Cold water cascades from a height of 60 feet into a wide concreted pool and on to a rocky stream that drains to Laguna Lake; visitors climb 249 steps at almost 1,000 feet high to reach the falls. Tourism office: Baras Municipal Tourism Office, Sitio Soro-soro, Brgy. Santiago (no published email/phone; provincial coordination: tourismoffice@rizalprovincialgov.ph / 8256-3000 loc. 4241).',
   'destination', 'Valle St., Brgy. Pinugay, Baras, Rizal (Marcos Highway near Baras-Tanay boundary)',
   'Public jeepneys from Antipolo City / Masinag and Cogeo bound for Palo Alto pass by the gate of the falls area along Marcos Highway (per the provincial tourism office).',
   NULL, NULL, 14.5233, 121.2672, true),

  -- [P08] BINANGONAN — Marian Hill
  -- Source: https://rizalprovince.ph/pages/tourism-nature.html
  -- (one-hectare hilltop prayer garden; panoramic Laguna de Bay views and
  --  sunsets; four mysteries of the Rosary; tributes to Mary, the Holy Family,
  --  St. Michael and St. Francis.)
  ('binangonan', 'cultural-arts', 'Marian Hill',
   'A one-hectare hilltop prayer garden in Binangonan, built as a labor of love on private property, offering panoramic views of historic Laguna de Bay and a daily show of magnificent sunsets across the bay. A walk through rugged terrain between natural rock formations and centuries-old trees leads through the four mysteries of the Most Holy Rosary — Joyful, Luminous, Sorrowful and Glorious — with tributes to the Virgin Mary, the Holy Family, St. Michael the Archangel and St. Francis of Assisi. Tourism office: Binangonan Municipal Tourism Office, brcc@binangonan.gov.ph / (02) 8579-3407.',
   'heritage_site', 'Binangonan, Rizal (hilltop prayer garden)',
   'From Binangonan Poblacion, hire a tricycle to Marian Hill; the garden sits on a hilltop overlooking Laguna de Bay.',
   NULL, NULL, 14.4514, 121.1920, false),

  -- [P09] BINANGONAN — Kalbaryo (Mt. Calvary)
  -- Source: https://rizalprovince.ph/pages/tourism-others.html
  -- (Brgy. Libid; approximately 288 steps from foot to holy cross; image of
  --  the Most Holy of Calvary at the summit; page cites binangonan.gov.ph.)
  ('binangonan', 'cultural-arts', 'Kalbaryo (Mt. Calvary)',
   'Binangonan''s Kalbaryo pilgrimage in Brgy. Libid: approximately 288 steps from the foot to the holy cross at the summit, where pilgrims are welcomed by the image of the Most Holy of Calvary. A Lenten walk-and-prayer destination near the town''s port area, where visitors reflect as they slowly thread their way to the top. Tourism office: Binangonan Municipal Tourism Office, brcc@binangonan.gov.ph / (02) 8579-3407.',
   'heritage_site', 'Brgy. Libid, Binangonan, Rizal',
   'From Binangonan Poblacion, walk or take a tricycle to Brgy. Libid and climb the approximately 288 steps to the summit cross.',
   NULL, 'Free', 14.4514, 121.1920, false),

  -- [P10] CAINTA — Tahanang Walang Hagdan
  -- Source: https://rizalprovince.ph/pages/tourism-others.html
  -- (175 Aida Street, Marick Subdivision, Brgy. Santo Domingo; founded by
  --  Sr. Ma. Paula Valeriana Baerts, ICM, Belgian nun of the Missionary
  --  Sisters of the Immaculate Heart of Mary, sent to the Philippines in 1965
  --  and assigned to the Philippine Orthopedic Center, where she saw the
  --  plight of persons with disability and made improving their lives her
  --  mission.)
  ('cainta', 'civic-community', 'Tahanang Walang Hagdan',
   'A Cainta institution founded by Sr. Ma. Paula Valeriana Baerts, ICM, a Belgian nun of the Missionary Sisters of the Immaculate Heart of Mary who was sent to the Philippines in 1965 and assigned to the Philippine Orthopedic Center. During her hospital service she saw the miserable plight of persons with disability, which brought about her eagerness to improve their lives — her real mission in life. The home stands at 175 Aida Street, Marick Subdivision, Brgy. Santo Domingo. Tourism office: Cainta Municipal Tourism, Culture and Arts Office (MTCAO), tourism@cainta.gov.ph / (02) 8696-2584.',
   'destination', '175 Aida St., Marick Subdivision, Brgy. Santo Domingo, Cainta, Rizal',
   'From Cainta Junction, take a tricycle to Marick Subdivision, Brgy. Santo Domingo and ask for Tahanang Walang Hagdan on Aida Street.',
   NULL, NULL, 14.5778, 121.1222, false),

  -- [P11] CARDONA — Our Lady of the Holy Rosary Parish
  -- Source: https://rizalprovince.ph/pages/tourism-churches.html
  -- (founded 1872 by Franciscan missionaries stationed in Morong; amorseco
  --  legend of the disappearing/returning image; address Real, Cardona.)
  ('cardona', 'cultural-arts', 'Our Lady of the Holy Rosary Parish (Cardona Church)',
   'The parish of Our Lady of the Holy Rosary in Cardona was founded in 1872 by Franciscan missionaries who had been stationed in Morong since the 16th century and established mission centers along the shores of Laguna de Bay. Local tradition tells that when Cardona was still a sitio of Morong, the image of Our Lady of the Holy Rosary kept in the main church would sometimes mysteriously disappear and return with amorseco — a grass weed abundant in the area known as Sapao — leading the faithful to conclude that the Blessed Mother herself had chosen where her image should be enshrined. Tourism office: Cardona Municipal Tourism Office, cardonatourism@gmail.com.',
   'heritage_site', 'Real St., Cardona, Rizal',
   'From Cardona Municipal Hall, walk to the parish church on Real Street in the Poblacion; jeepneys from Binangonan or Morong alight at Cardona town proper.',
   NULL, 'Free', 14.4369, 121.2480, false),

  -- [P12] JALAJALA — Dairy Delights (Llano Farmers Cooperative)
  -- Source: https://rizalprovince.ph/pages/tourism-foods.html
  -- (G. Paz Street, Sitio Llano Village, Brgy. Bayugo; Llano Farmers
  --  Multi-Purpose Cooperative, Inc.; 90 members, 20 with carabao holdings;
  --  ~100 liters/day peak, 20 liters dry season; farm-gate Php 35.00/liter;
  --  marketed as far as Manila during trade fairs.)
  ('jalajala', 'food-heritage', 'Dairy Delights (Llano Farmers Cooperative)',
   'Carabao-milk dairy delights from the Llano Farmers Multi-Purpose Cooperative, Inc. in Sitio Llano Village, Brgy. Bayugo. The cooperative has 90 members, twenty of them with carabao holdings, producing roughly a hundred liters of milk per day during peak season (as little as twenty liters in the dry season). The published farm-gate price is Php 35.00 per liter, and the produce is marketed in the vicinity and as far as Manila during national trade fairs. Tourism office: Jalajala Municipal Tourism Office, National Road, Brgy. Special District (no published email/phone; provincial coordination: tourismoffice@rizalprovincialgov.ph / 8256-3000 loc. 4241).',
   'unique_food', 'G. Paz St., Sitio Llano Village, Brgy. Bayugo, Jalajala, Rizal',
   'From Jalajala Poblacion, hire a tricycle to Sitio Llano Village, Brgy. Bayugo and ask for the Llano Farmers cooperative (Dairy Delights).',
   NULL, NULL, 14.3547, 121.3247, true),

  -- [P13] MORONG — St. Jerome Parish Church
  -- Source: https://rizalprovince.ph/pages/tourism-churches.html
  -- (built 1615 by Chinese artisans, stone and mortar; Chinese-Baroque;
  --  two Chinese lion sculptures at the entrance; octagonal bell tower.)
  -- Distinct from the seeded Museong Pambayan (Commandancia) POI.
  ('morong', 'cultural-arts', 'St. Jerome Parish Church (Morong Church)',
   'Morong''s St. Jerome church was built by Chinese artisans in 1615 with stone and mortars, in a design distinct for its Chinese-Baroque architecture. It has two Chinese lion sculptures at the entrance serving the storey façade, and an octagonal bell tower. The church stands beside the Commandancia in the town plaza area, the historic seat of the Distrito Politico-Militar de Morong. Tourism office: Morong Municipal Tourism Office, (02) 8537-5000, 2/F GAD Building, Morong Municipal Compound.',
   'heritage_site', 'Morong Town Plaza, Morong, Rizal',
   'Ride a Morong-bound jeepney via Manila East Road and alight at Morong Town Plaza; the church is beside the Commandancia museum, a two-minute walk from the plaza.',
   NULL, 'Free', 14.5178, 121.2400, true),

  -- [P14] PILILLA — Kawayan Farm
  -- Source: https://rizalprovince.ph/pages/tourism-nature.html
  -- (Brgy. Halayhayin; Rizal St; 150-200 bamboo poles/year; orange, green,
  --  black and giant bamboo; sold to Laguna Lake fishpen operators; harvest
  --  from September/October onwards.) Coordinates reuse the seed's
  -- Halayhayin wind-farm cluster (same barangay).
  ('pililla', 'eco-tourism', 'Kawayan Farm',
   'A bamboo farm in Brgy. Halayhayin, Pililla producing around 150-200 bamboo poles per year — orange bamboo, regular green bamboo, black bamboo and giant bamboo — sold mainly to fishpen operators at Laguna Lake. The nursery is a place of cultivation and plant harvesting, and harvest time normally starts during the colder months of September or October onwards. Tourism office: Pililla Municipal Tourism Office, tourismpililla1910@gmail.com / (02) 8654-1093.',
   'destination', 'Rizal St., Brgy. Halayhayin, Pililla, Rizal',
   'From Pililla Poblacion, hire a tricycle to Brgy. Halayhayin (the same barangay as the Pililla Wind Farm viewing deck) and ask for Kawayan Farm.',
   NULL, NULL, 14.4700, 121.2900, false),

  -- [P15] RODRIGUEZ — Payaran Falls (7 Infinity Pools)
  -- Source: https://rizalprovince.ph/pages/tourism.html
  -- (Sitio Payaran, Brgy. Mascap; seven layered falls; mountain wall climbing
  --  and vigorous trekking to reach the topmost falls.) Coordinates reuse the
  -- seed's Wawa cluster (approximate; adjacent Sierra Madre foothill area).
  ('rodriguez', 'eco-tourism', 'Payaran Falls (7 Infinity Pools)',
   'A natural attraction at Sitio Payaran, Barangay Mascap consisting of seven layered falls. Reaching the topmost falls takes endurance — mountain wall climbing and vigorous trekking — after which refreshing, cool waterfalls come your way. A favorite of mountaineers and mountain bikers exploring the Rodriguez Sierra Madre foothills. Tourism office: Rodriguez Municipal Tourism and Cultural Affairs Office (MTCAO), montalbantourism@gmail.com, JP Rizal St., Brgy. Balite.',
   'destination', 'Sitio Payaran, Brgy. Mascap, Rodriguez, Rizal',
   'From Rodriguez Poblacion, take a jeepney or tricycle to the Brgy. Mascap jump-off, then trek to Sitio Payaran; allow time for climbing the layered falls.',
   NULL, NULL, 14.7300, 121.1900, true),

  -- [P16] SAN MATEO — Camp Sinai (Mount Sinai)
  -- Source: https://rizalprovince.ph/pages/tourism-nature.html
  -- (Pintong Bukawe, just past Giant in Maarat; views of Sierra Madre,
  --  Laguna de Bay and the metro; world-record largest 10 Commandments;
  --  jump-off for Casile and Wawa Gorge rides.)
  ('san-mateo', 'sports-recreation', 'Camp Sinai (Mount Sinai)',
   'A ridge viewpoint nestled in the heart of Pintong Bukawe, just past Giant in Maarat, with a magnificent view stretching from the Sierra Madre mountains to Laguna de Bay and the metro. It holds the current world record for the largest Ten Commandments monument — according to locals, a gift from Israel — and serves as a jump-off point for rides to Casile or Wawa Gorge, a perfect cap to a weekend ride. Tourism office: San Mateo Municipal Tourism Office, (02) 8297-8100 loc. 106, Gen. Luna Ave., Brgy. Guitnang Bayan I.',
   'destination', 'Pintong Bukawe (Maarat area), San Mateo, Rizal',
   'From San Mateo Poblacion, head to Brgy. Pintong Bukawe via the Maarat area; Camp Sinai is just past the Giant landmark and is a jump-off for Casile and Wawa Gorge rides.',
   NULL, NULL, 14.6969, 121.1219, false),

  -- [P17] TANAY — Daranak Falls
  -- Sources: https://rizalprovince.ph/pages/tourism-nature.html and
  --          https://rizalprovince.ph/pages/tourism.html
  -- (Daranak Falls Rd; foot of the Tanay mountain range; summer haven) and
  -- https://www.tourism.gov.ph/destination/calabarzon/rizal/
  -- (DOT: curtain of water into a jade pool; lush natural environment.)
  ('tanay', 'eco-tourism', 'Daranak Falls',
   'A haven getaway for local and foreign tourists, especially during the summer months: Daranak is nestled quietly at the foot of the Tanay mountain range, preserved with natural vegetation, forest trees and flowering wild plants, complemented by beautiful cascading waterfalls, streams and ditches. The Department of Tourism features its delicate curtain of water shimmering down into a jade pool that invites a rewarding dip. Tourism office: Tanay Municipal Tourism Office, lgutourismtanay2020@gmail.com / 0968 556 5335, 2/F Tanay Municipal Hall, M.H. del Pilar St.',
   'destination', 'Daranak Falls Rd, Tanay, Rizal',
   'From Tanay Public Market or Poblacion, hire a tricycle to Daranak Falls Road at the foot of the Tanay mountain range.',
   NULL, NULL, 14.4972, 121.2864, true),

  -- [P18] TANAY — San Ildefonso de Toledo Parish Church
  -- Source: https://rizalprovince.ph/pages/tourism-churches.html
  -- (M.H. Del Pilar St, Plaza Aldea; first stone church 1680 at the site of
  --  today's Tanay Park; present church 1773-1783; early Renaissance;
  --  retablos, 14 Via Crucis bas-reliefs; rare Rococo artwork.)
  ('tanay', 'cultural-arts', 'San Ildefonso de Toledo Parish Church (Tanay Church)',
   'Tanay''s historic parish church on M.H. Del Pilar St., Plaza Aldea. The first stone church of Tanay was built in 1680 at the location of Tanay Park today; the present church was constructed from 1773 and completed in 1783, an example of early Renaissance architecture. It is famous for its beautiful retablos (altars), 14 Via Crucis or Stations of the Cross carved in bass relief of wood, and other antiques — and as one of the very few churches in the country featuring Rococo artwork, the 18th-century style of curves and gold leaf. Tourism office: Tanay Municipal Tourism Office, lgutourismtanay2020@gmail.com / 0968 556 5335.',
   'heritage_site', 'M.H. Del Pilar St., Plaza Aldea, Tanay, Rizal',
   'From Tanay Public Market, walk to Plaza Aldea along M.H. Del Pilar Street; the church faces the plaza.',
   NULL, 'Free', 14.4972, 121.2864, true),

  -- [P19] TAYTAY — Taytay Tiangge
  -- Sources: https://rizalprovince.ph/pages/tourism.html and
  --          https://rizalprovince.ph/pages/tourism-others.html
  -- (beside Club Manila East; about an hour from the Antipolo capitol;
  --  fabric sold per kilo, ~6 yards per kilo; Tutuban/Greenhills resellers;
  --  bulk discounts) and
  -- https://rizalprovince.ph/pages/trade%20and%20commerce.html
  -- (shoppers visit every Monday, Thursday and Sunday.)
  ('taytay', 'cultural-arts', 'Taytay Tiangge',
   'The garments market beside Club Manila East that anchors Taytay''s title as the Garments Capital of the Philippines — one of the largest garments producers in the province. A succession of stores sells fabric, clothes and curtains; fabric shops traditionally sell per kilo rather than per yard (about 6 yards of fabric per kilo), which is why Tutuban Mall and Greenhills shops buy here, with large discounts for bulk purchases. The provincial government notes that many shoppers visit the tiangge every Monday, Thursday and Sunday. Tourism office: Taytay Municipal Tourism and Cultural Affairs Office, tourism@taytayrizal.gov.ph / +63 2 8284-4786, 4/F Taytay Municipal Hall, CME Compound, Brgy. San Juan.',
   'destination', 'Beside Club Manila East, Taytay, Rizal',
   'Take a Taytay-bound jeepney along Ortigas Avenue Extension and alight at Club Manila East / Taytay Tiangge; travel time from the Antipolo provincial capitol is about an hour.',
   'Busy market days: Monday, Thursday and Sunday (per Province of Rizal)', NULL, 14.5586, 121.1328, true),

  -- [P20] TERESA — Teresa Tourist Assistance Desk
  -- Sources: https://www.scribd.com/document/636170643/EO-NO-8B-TOURISM-ASSISTANCE-DESK
  -- (Executive Order of the Mayor of Teresa creating the Tourist Assistance
  --  Desk under the Municipal Tourism Office and Municipal Tourism Council,
  --  citing the Tourism Act of 2009; provides information on tourism
  --  activities, destinations, transportation and other relevant data) and
  -- https://teresarizal.gov.ph/ (Municipal Hall, Corazon C. Aquino Ave.,
  --  Poblacion) and https://elibrary.judiciary.gov.ph/thebookshelf/showdocs/2/9305
  -- (RA 9593 Sec. 43: LGUs shall establish tourist information and
  --  assistance centers.)
  ('teresa', 'civic-community', 'Teresa Tourist Assistance Desk',
   'The visitor assistance desk at the Teresa Municipal Hall, created by executive order of the Mayor under the supervision of the Municipal Tourism Office and Municipal Tourism Council, in line with the Tourism Act of 2009 (RA 9593, Sec. 43). It gathers, compiles and makes available records on Teresa''s tourism activities, destinations, potentials and transportation schedules for visitors. Tourism office: Teresa Municipal Tourism Office, teresarizaltourism@yahoo.com / (02) 8250-6800, Teresa Municipal Hall, Corazon C. Aquino Ave.',
   'destination', 'Teresa Municipal Hall, Corazon C. Aquino Ave., Brgy. Poblacion, Teresa, Rizal',
   'From Antipolo or Tanay, ride a jeepney to Teresa town proper and alight at the Municipal Hall along Corazon C. Aquino Avenue.',
   NULL, 'Free', 14.5611, 121.2075, false)
) AS v(municipality_slug, category_slug, name, description, poi_type, address,
       how_to_get_there, operating_hours, entrance_fee, latitude, longitude,
       is_promoted)
JOIN public.municipalities m ON m.slug = v.municipality_slug
LEFT JOIN public.categories c ON c.slug = v.category_slug
WHERE NOT EXISTS (
  SELECT 1
  FROM public.pois_logistics p
  WHERE p.municipality_id = m.id
    AND p.name = v.name
)
ON CONFLICT DO NOTHING;

COMMIT;

-- ----------------------------------------------------------------------------
-- 4. Verification summary (safe to ignore when running via psql)
--    Expected after first run on top of seed_full_rizal.sql:
--      pois = 55 (35 existing + 20 new), approved_events = 29 (27 + 2).
-- ----------------------------------------------------------------------------
SELECT
  (SELECT count(*) FROM public.municipalities) AS municipalities,
  (SELECT count(*) FROM public.categories)     AS categories,
  (SELECT count(*) FROM public.events WHERE status = 'approved') AS approved_events,
  (SELECT count(*) FROM public.pois_logistics) AS pois,
  (SELECT count(*) FROM public.pois_logistics
    WHERE name IN (
      'Angono-Binangonan Petroglyphs',
      'Botong Francisco Museum & Street Murals',
      'St. Clement Parish Church (Diocesan Shrine)',
      'Balaw-Balaw Specialty Restaurant',
      'Hinulugang Taktak Falls',
      'Boso-Boso Church (Nuestra Señora de la Annunciata Parish)',
      'Palo Alto Falls',
      'Marian Hill',
      'Kalbaryo (Mt. Calvary)',
      'Tahanang Walang Hagdan',
      'Our Lady of the Holy Rosary Parish (Cardona Church)',
      'Dairy Delights (Llano Farmers Cooperative)',
      'St. Jerome Parish Church (Morong Church)',
      'Kawayan Farm',
      'Payaran Falls (7 Infinity Pools)',
      'Camp Sinai (Mount Sinai)',
      'Daranak Falls',
      'San Ildefonso de Toledo Parish Church (Tanay Church)',
      'Taytay Tiangge',
      'Teresa Tourist Assistance Desk'
    )) AS enriched_pois_present,
  (SELECT count(*) FROM public.events
    WHERE title IN (
      'National Arts Month 2027 sa Angono',
      'Angono Day 2027: 89th Founding Anniversary & Cultural Night'
    )) AS enriched_events_present;
