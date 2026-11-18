-- ============================================================================
-- supabase/seed_full_rizal.sql
-- TuklasRizal — Full Province of Rizal tourism seed (14 municipalities)
--
-- Target schema: the LIVE deployed Supabase/PostgREST database, verified by
-- introspecting the production endpoint:
--   municipalities (id, name, slug, description, latitude, longitude,
--     geofence_radius_meters, tourism_office_name, coordinator_contact_email,
--     coordinator_contact_phone, tourism_office_address,
--     visitor_priority_boost, created_at)
--   categories     (id, name, slug, icon_name, description, created_at)
--   events         (id, municipality_id, barangay_id, category_id, created_by,
--     approved_by, title, description, venue_name, how_to_get_there, latitude,
--     longitude, start_date, end_date, image_url, status, is_featured,
--     promotion_weight, created_at, updated_at)
--   pois_logistics (id, municipality_id, barangay_id, category_id, name,
--     description, poi_type, address, how_to_get_there, operating_hours,
--     entrance_fee, latitude, longitude, image_url, is_promoted, created_at)
--
-- IDEMPOTENT: municipalities and categories upsert on their verified unique
-- `slug`; events and POIs insert only when the same title/name does not already
-- exist in that municipality. Re-running never duplicates rows.
--
-- Content notes:
--   * Tourism office names/contacts/addresses follow official LGU, provincial
--     tourism and 2026 Citizen's Charter sources where published. Details that
--     could not be verified are left NULL rather than invented.
--   * Festival dates follow published municipal/provincial calendars where
--     available; dates for festivals without a published annual schedule are
--     illustrative 2026–2027 schedules for the capstone demo.
--   * All events are seeded with status = 'approved' so they are visible to
--     guests in the mobile app (RLS exposes approved events publicly).
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Tourism categories (upsert on verified unique slug)
-- ----------------------------------------------------------------------------
INSERT INTO public.categories (name, slug, icon_name, description)
SELECT v.name, v.slug, v.icon_name, v.description
FROM (VALUES
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
) AS v(name, slug, icon_name, description)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  icon_name = EXCLUDED.icon_name,
  description = EXCLUDED.description;

-- ----------------------------------------------------------------------------
-- 2. All 14 municipalities of the Province of Rizal
--    Coordinates follow the municipal centres already used by the deployed
--    geofence configuration (Cardona corrected to its town centre).
-- ----------------------------------------------------------------------------
INSERT INTO public.municipalities (
  name, slug, description, latitude, longitude, geofence_radius_meters,
  tourism_office_name, coordinator_contact_email, coordinator_contact_phone,
  tourism_office_address, visitor_priority_boost
)
SELECT
  v.name, v.slug, v.description, v.latitude, v.longitude, v.radius,
  v.office_name, v.email, v.phone, v.address, v.boost
FROM (VALUES
  ('Angono', 'angono',
   'Art Capital of the Philippines; home of the Higantes Festival and the Angono–Binangonan Petroglyphs.',
   14.5266, 121.1536, 3500,
   'Angono Municipal Tourism, Culture and the Arts Office',
   'angonotourismoffice@gmail.com', '(02) 8661-3646',
   'Beside the Municipal Building, Brgy. San Isidro, Angono, Rizal', 1.10),
  ('Antipolo', 'antipolo',
   'Pilgrimage Capital of the Philippines; home of the Antipolo Cathedral, Hinulugang Taktak and the SuMaKaH Festival.',
   14.5842, 121.1763, 3500,
   'Antipolo City Culture, Arts and Tourism Promotions Office (AnCCATPO)',
   'antipolotourism@gmail.com', NULL,
   NULL, 1.00),
  ('Baras', 'baras',
   'Riverside town known for the 1686 St. Joseph Parish, the Tromba Festival and Masungi Georeserve.',
   14.5233, 121.2672, 3500,
   'Baras Municipal Tourism Office',
   NULL, NULL,
   'Sitio Soro-soro, Brgy. Santiago, Baras, Rizal', 1.45),
  ('Binangonan', 'binangonan',
   'Lakeshore town facing Talim Island, known for the Petroglyphs, Santa Ursula Parish and buro at kanduli.',
   14.4514, 121.1920, 3500,
   'Binangonan Municipal Tourism Office',
   'brcc@binangonan.gov.ph', '(02) 8579-3407',
   'Manila East Road, Brgy. Calumpang, Binangonan, Rizal 1940', 1.25),
  ('Cainta', 'cainta',
   'Gateway town and bibingka capital, home of the SumBingTik Festival and Our Lady of Light Parish.',
   14.5778, 121.1222, 3500,
   'Cainta Municipal Tourism, Culture and Arts Office (MTCAO)',
   'tourism@cainta.gov.ph', '(02) 8696-2584',
   'No. 73 A. Bonifacio Ave., Brgy. Sto. Domingo, Cainta, Rizal 1900', 1.15),
  ('Cardona', 'cardona',
   'Lakeside fishing town known for the Kaluskos bamboo-arch festival and the Cardona Rock Garden.',
   14.4369, 121.2480, 3500,
   'Cardona Municipal Tourism Office',
   'cardonatourism@gmail.com', NULL,
   'Cardona Municipal Hall, Cardona, Rizal', 1.50),
  ('Jalajala', 'jalajala',
   'Peninsula municipality on Laguna de Bay, known for the D''Dalaylay Festival and Santong Lugar.',
   14.3547, 121.3247, 5000,
   'Jalajala Municipal Tourism Office',
   NULL, NULL,
   'National Road, Brgy. Special District, Jalajala, Rizal', 1.60),
  ('Morong', 'morong',
   'Heritage town of the 1615 St. Jerome Parish, the Sanrok sa Ringring Festival and the Commandancia.',
   14.5178, 121.2400, 3500,
   'Morong Municipal Tourism Office',
   NULL, '(02) 8537-5000',
   '2/F GAD Building, Morong Municipal Compound, Morong, Rizal', 1.35),
  ('Pililla', 'pililla',
   'Lakeshore town home to the Pililla Wind Farm, the 1670s St. Mary Magdalene Church and the Magsolangtan Festival.',
   14.4853, 121.3064, 3500,
   'Pililla Municipal Tourism Office',
   'tourismpililla1910@gmail.com', '(02) 8654-1093',
   'M.A. Roxas St., Brgy. Bagumbayan, Pililla, Rizal', 1.30),
  ('Rodriguez', 'rodriguez',
   'Sierra Madre gateway known for Wawa Gorge, Pamitinan Cave and the Montalban/Pamitinan Festival.',
   14.7601, 121.1996, 3500,
   'Rodriguez Municipal Tourism and Cultural Affairs Office (MTCAO)',
   'montalbantourism@gmail.com', NULL,
   'JP Rizal St., Brgy. Balite, Rodriguez, Rizal', 1.20),
  ('San Mateo', 'san-mateo',
   'Home of the Our Lady of Aranzazu Shrine, the Kakanin Festival and the Timberland bike trails.',
   14.6969, 121.1219, 3500,
   'San Mateo Municipal Tourism Office',
   NULL, '(02) 8297-8100 loc. 106',
   'Gen. Luna Ave., Brgy. Guitnang Bayan I, San Mateo, Rizal 1850', 1.30),
  ('Tanay', 'tanay',
   'Eco-tourism capital of Rizal: Daranak Falls, Tinipak River, Regina RICA and the Hane Festival.',
   14.4972, 121.2864, 5000,
   'Tanay Municipal Tourism Office',
   'lgutourismtanay2020@gmail.com', '0968 556 5335',
   '2/F Tanay Municipal Hall, M.H. del Pilar St., Tanay, Rizal 1980', 1.05),
  ('Taytay', 'taytay',
   'Garments Capital of the Philippines, home of the Tiangge, the Hamaka Festival and Basaan.',
   14.5586, 121.1328, 3500,
   'Taytay Municipal Tourism and Cultural Affairs Office',
   'tourism@taytayrizal.gov.ph', '+63 2 8284-4786',
   '4/F Taytay Municipal Hall, Don Hilario Cruz Ave., CME Compound, Brgy. San Juan, Taytay, Rizal', 1.10),
  ('Teresa', 'teresa',
   'Upland agricultural town known for St. Rose of Lima Parish, the AMARA Festival and Turumba.',
   14.5611, 121.2075, 3500,
   'Teresa Municipal Tourism Office',
   'teresarizaltourism@yahoo.com', '(02) 8250-6800',
   'Teresa Municipal Hall, Corazon C. Aquino Ave., Teresa, Rizal', 1.50)
) AS v(name, slug, description, latitude, longitude, radius,
       office_name, email, phone, address, boost)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  geofence_radius_meters = EXCLUDED.geofence_radius_meters,
  tourism_office_name = EXCLUDED.tourism_office_name,
  coordinator_contact_email = EXCLUDED.coordinator_contact_email,
  coordinator_contact_phone = EXCLUDED.coordinator_contact_phone,
  tourism_office_address = EXCLUDED.tourism_office_address,
  visitor_priority_boost = EXCLUDED.visitor_priority_boost;

-- ----------------------------------------------------------------------------
-- 3. Approved cultural, festival and eco-tourism events
--    Inserted only when the same title is not already present in that
--    municipality, so re-runs are safe.
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
  ('angono', 'festival', 'Higantes Festival 2026: Giants of San Clemente',
   'Angono''s iconic thanksgiving festival fills the Art Capital''s streets with towering papier-mâché higantes, brass bands and water-splashing crowds in honor of San Clemente. The 2026 edition coincides with the town fiesta on November 22–23.',
   'Angono Municipal Plaza & Poblacion Streets',
   'From Shaw Blvd or Cubao, take a UV Express or jeepney bound for Angono and alight at Angono Town Plaza. The parade route runs through the Poblacion streets around the municipal plaza.',
   14.5266, 121.1536, '2026-11-22T07:00:00+08:00', '2026-11-23T21:00:00+08:00', true, 1.40),

  ('antipolo', 'festival', 'SuMaKaH Festival 2027 (Maytime Festival)',
   'Antipolo''s month-long Maytime celebration of suman, mangga, kasoy and hamaka opens on May 1 with street dancing, food fairs and cultural performances. Local producers line Sumulong Park and the City Hall grounds for the whole month.',
   'Sumulong Park & Antipolo City Hall grounds',
   'Take a UV Express or jeepney from Cubao or Ortigas bound for Antipolo Cathedral, then walk to Sumulong Park beside the City Hall.',
   14.5878, 121.1760, '2027-05-01T06:00:00+08:00', '2027-05-31T22:00:00+08:00', true, 1.30),

  ('antipolo', 'cultural-arts', 'Antipolo Pilgrimage & Cathedral Heritage Walk',
   'A guided cultural walk through the National Shrine of Our Lady of Peace and Good Voyage, the centuries-old pilgrimage church that made Antipolo the Pilgrimage Capital of the Philippines. Includes a heritage briefing on the image''s galleon voyages and the city''s May pilgrimage season.',
   'National Shrine of Our Lady of Peace and Good Voyage, Antipolo',
   'From the Antipolo Cathedral jeepney terminal, walk to the shrine; tricycles from Robinsons Antipolo also drop off at the cathedral.',
   14.5875, 121.1767, '2027-05-08T06:00:00+08:00', '2027-05-08T17:00:00+08:00', false, 1.15),

  ('baras', 'festival', 'Tromba Festival 2027',
   'Baras honors Nuestra Señora de Turumba with a river procession (tromba) along the Baras River followed by street dancing and a community feast. One of Rizal''s most distinctive fluvial fiestas.',
   'Baras River & Poblacion, Baras',
   'From Antipolo or Tanay, ride a jeepney along Manila East Road and alight at Baras town proper; the procession starts at the Baras River.',
   14.5233, 121.2672, '2027-05-04T06:00:00+08:00', '2027-05-05T20:00:00+08:00', false, 1.45),

  ('baras', 'cultural-arts', 'St. Joseph Parish Heritage Day',
   'Open-house heritage day at the 1686 Diocesan Shrine and Parish of St. Joseph, one of the oldest Baroque churches in Rizal, with guided tours of its retablo and church museum.',
   'Diocesan Shrine and Parish of St. Joseph, Baras',
   'Jeepneys from Antipolo to Baras stop in front of the church; travel time is about 25 minutes.',
   14.5236, 121.2669, '2027-03-19T08:00:00+08:00', '2027-03-19T16:00:00+08:00', false, 1.20),

  ('binangonan', 'festival', 'Binalayan Festival 2027',
   'Binangonan''s "BINAngonan sa LAwa at kawaYAN" festival showcases bamboo crafts, lakeshore products and the town''s fishing heritage through street dancing and trade fairs. Barangay delegations perform along the municipal grounds facing Laguna de Bay.',
   'Binangonan Municipal Grounds, Brgy. Calumpang',
   'Take a Binangonan-bound jeepney or UV Express via Manila East Road and alight at Binangonan Municipal Hall.',
   14.4514, 121.1920, '2027-04-18T08:00:00+08:00', '2027-04-18T20:00:00+08:00', false, 1.35),

  ('binangonan', 'eco-tourism', 'Talim Island & Mt. Tagapo Community Trek',
   'A community-guided day hike to Mt. Tagapo on Talim Island, with views over Laguna de Bay and a lakeside lunch of buro at kanduli prepared by island households.',
   'Binangonan Port to Talim Island (Brgy. Janosa jump-off)',
   'Board a passenger banca at Binangonan Port for Talim Island (about 30 minutes), then register at the Brgy. Janosa jump-off for Mt. Tagapo.',
   14.4700, 121.2100, '2027-02-20T05:30:00+08:00', '2027-02-20T17:00:00+08:00', false, 1.30),

  ('cainta', 'festival', 'SumBingTik Festival 2026',
   'Cainta''s kakanin festival named for suman, bibingka and latik, staged around the town''s founding anniversary and the feast of Our Lady of Light. Expect week-long kakanin showcases, cooking demos and a grand parade.',
   'Cainta Municipal Grounds & Our Lady of Light Parish',
   'From Ortigas, ride a Cainta-bound jeepney or UV Express along Ortigas Avenue Extension and alight at Cainta Junction; the municipal grounds are a short walk away.',
   14.5778, 121.1222, '2026-12-01T08:00:00+08:00', '2026-12-07T21:00:00+08:00', true, 1.20),

  ('cainta', 'cultural-arts', 'Cainta Lenten Senakulo & Heritage Walk',
   'A traditional Lenten senakulo staged by local parishes, paired with a heritage walk to the Bantayog ng mga Bayani memorial honoring the Hunters ROTC guerrillas of World War II.',
   'Bantayog ng mga Bayani & Our Lady of Light Parish grounds, Cainta',
   'Jeepneys along A. Bonifacio Avenue stop at the parish; from Cainta Junction take a tricycle to the Bantayog.',
   14.5780, 121.1225, '2027-03-26T17:00:00+08:00', '2027-03-26T22:00:00+08:00', false, 1.10),

  ('cardona', 'festival', 'Kaluskos Festival 2026',
   'Cardona lights its handcrafted bamboo arches for the Kaluskos Festival, named for the kuskos sound of a bolo shaping bamboo. The first week of December brings street dancing, arch-lighting ceremonies and lakeshore food stalls.',
   'Cardona Poblacion & Lakeshore Park',
   'From Binangonan or Morong, ride a jeepney to Cardona town proper; the bamboo arches line the Poblacion streets near the municipal hall.',
   14.4369, 121.2480, '2026-12-01T08:00:00+08:00', '2026-12-07T21:00:00+08:00', false, 1.50),

  ('cardona', 'festival', 'Pagoda Festival sa Lawa 2027',
   'A lakeside thanksgiving procession on Laguna de Bay, where a decorated pagoda carries the town''s patron image while fishing families offer prayers for a bountiful catch.',
   'Laguna de Bay shoreline, Cardona',
   'Take a jeepney to Cardona Municipal Hall, then walk to the lakeshore where the pagoda procession boards.',
   14.4369, 121.2480, '2027-10-04T06:00:00+08:00', '2027-10-04T16:00:00+08:00', false, 1.40),

  ('jalajala', 'festival', 'D''Dalaylay Festival 2027',
   'Jalajala''s barangay and school groups parade in ingenious costumes for the feast of St. Michael the Archangel, filling the peninsula''s main road with street dancing and live music.',
   'Jalajala Municipal Grounds & St. Michael the Archangel Parish',
   'Ride a jeepney from Binangonan or Tanay to Jalajala Poblacion; the street dance passes the St. Michael the Archangel Parish.',
   14.3547, 121.3247, '2027-09-29T08:00:00+08:00', '2027-09-29T20:00:00+08:00', false, 1.60),

  ('jalajala', 'eco-tourism', 'Santong Lugar Pilgrimage & Dragon Fruit Farm Tour',
   'A morning pilgrimage to the hillside Santong Lugar site linked to the image of Our Lady of Maulawin, followed by a dragon fruit and carabao-milk farm tour with Jalajala''s agricultural cooperatives.',
   'Santong Lugar, Brgy. Bagumbong, Jalajala',
   'From Jalajala Poblacion, hire a tricycle to Brgy. Bagumbong and ask for the Santong Lugar trail; farm tours can be arranged at the municipal tourism office.',
   14.3600, 121.3300, '2027-04-10T06:00:00+08:00', '2027-04-10T17:00:00+08:00', false, 1.55),

  ('morong', 'festival', 'Sanrok sa Ringring Festival 2027',
   'Morong celebrates its local D-to-R dialect with the Sanrok sa Ringring Festival, where "sandok" becomes sanrok and "dingding" becomes ringring. The town fiesta brings street dancing, heritage exhibits and a food fair around St. Jerome Parish.',
   'Morong Municipal Plaza & Poblacion',
   'Ride a Morong-bound jeepney via Manila East Road and alight at Morong Town Plaza; the festival grounds are beside St. Jerome Parish.',
   14.5178, 121.2400, '2027-02-20T08:00:00+08:00', '2027-02-21T21:00:00+08:00', false, 1.35),

  ('morong', 'cultural-arts', 'Commandancia Museum & Heritage Walk',
   'A guided walk through the Museong Pambayan at the Commandancia, the former seat of the Distrito Politico-Militar de Morong, and the 1615 Chinese-Baroque St. Jerome Parish.',
   'Museong Pambayan (Commandancia), Morong',
   'From Morong Town Plaza, walk two minutes to the Commandancia building beside St. Jerome Parish; tricycles from the public market also pass by.',
   14.5175, 121.2395, '2027-05-15T08:00:00+08:00', '2027-05-15T16:00:00+08:00', false, 1.25),

  ('pililla', 'festival', 'Magsolangtan Festival 2027',
   'Pililla''s town fiesta and founding-anniversary celebration features street dancing, agri-tourism booths and lakeside concerts, with July 22 declared a special non-working day for the municipality.',
   'Pililla Municipal Grounds & Poblacion',
   'Take a Pililla-bound jeepney from Tanay or Antipolo via Manila East Road and alight at the Pililla Municipal Hall.',
   14.4853, 121.3064, '2027-07-22T07:00:00+08:00', '2027-07-22T21:00:00+08:00', false, 1.30),

  ('pililla', 'eco-tourism', 'Pililla Wind Farm & Lakeshore Viewing Tour',
   'An afternoon at the Pililla Wind Farm ridge, where turbines overlook Laguna de Bay and the Pililla coastline, followed by a lakeside grilled-fish dinner.',
   'Pililla Wind Farm, Brgy. Halayhayin',
   'From Pililla Poblacion, hire a tricycle to the wind farm viewing deck in Brgy. Halayhayin; sunset viewing is best from the lakeside ridge.',
   14.4700, 121.2900, '2027-01-23T15:00:00+08:00', '2027-01-23T19:00:00+08:00', false, 1.25),

  ('rodriguez', 'festival', 'Pamitinan Festival 2026',
   'Rodriguez commemorates the 1895 Katipunan meeting at Pamitinan Cave with a week of heritage treks, cultural shows and a trade fair at the foot of the Sierra Madre.',
   'Pamitinan Cave & Wawa Gorge, Rodriguez',
   'From Cubao or Marikina, ride a Rodriguez/Montalban-bound jeepney and alight at the Wawa terminal, then take a tricycle to the Pamitinan jump-off.',
   14.7300, 121.1900, '2026-12-17T08:00:00+08:00', '2026-12-23T21:00:00+08:00', false, 1.20),

  ('rodriguez', 'eco-tourism', 'Wawa Gorge & Pamitinan Cave Heritage Trek',
   'A guided trek through the Wawa Gorge limestone formations to Pamitinan Cave, the declared historical site of the 1895 Katipunan assembly, with a river-side picnic stop.',
   'Wawa Gorge, Brgy. Wawa, Rodriguez',
   'Take a jeepney to Rodriguez Poblacion then a tricycle to Brgy. Wawa; register at the Wawa tourism desk before the trek.',
   14.7300, 121.1900, '2027-03-06T05:30:00+08:00', '2027-03-06T15:00:00+08:00', false, 1.15),

  ('san-mateo', 'festival', 'Kakanin Festival 2027',
   'San Mateo''s kakanin festival at the Diocesan Shrine of Our Lady of Aranzazu features floats and free samples of suman, puto, kutsinta, sapin-sapin, biko and bibingka after the fiesta Mass.',
   'Diocesan Shrine of Our Lady of Aranzazu, San Mateo',
   'From Batasan or Marikina, ride a San Mateo-bound jeepney along Gen. Luna Avenue and alight at the Aranzazu Shrine.',
   14.6969, 121.1219, '2027-09-09T08:00:00+08:00', '2027-09-09T18:00:00+08:00', false, 1.30),

  ('san-mateo', 'eco-tourism', 'Timberland Ridge Bike & Hiking Day',
   'A community ride and hike across the Timberland Heights ridge, Rizal''s long-running mountain-bike destination, with beginner and advanced trail groups and a ridge-top market.',
   'Timberland Heights, San Mateo',
   'From San Mateo Poblacion, take a tricycle to Timberland Heights; private vehicles may park at the Timberland clubhouse.',
   14.7100, 121.1400, '2027-02-14T05:00:00+08:00', '2027-02-14T12:00:00+08:00', false, 1.25),

  ('tanay', 'festival', 'Hane Festival 2027',
   'Tanay''s founding-anniversary festival celebrating agri-eco tourism, arts and culture, named after the Tanayan expression "hane." Expect farm tours, cultural performances and a harvest fair across the municipal grounds.',
   'Tanay Municipal Plaza & Poblacion',
   'Take a Tanay-bound jeepney or UV Express from Shaw Blvd or Cubao and alight at Tanay Public Market; the plaza is a short walk away.',
   14.4972, 121.2864, '2027-11-12T08:00:00+08:00', '2027-11-20T21:00:00+08:00', true, 1.35),

  ('tanay', 'festival', 'Tanay Rodeo Festival 2027',
   'A rodeo and agri-eco tourism festival tied to Tanay''s January town fiesta, with cattle-herding exhibitions, horseback demonstrations and a livestock and produce fair.',
   'Tanay Rodeo Arena, Tanay',
   'From Tanay Public Market, take a tricycle to the Rodeo Arena near the municipal grounds.',
   14.5000, 121.2870, '2027-01-16T08:00:00+08:00', '2027-01-17T18:00:00+08:00', false, 1.30),

  ('tanay', 'eco-tourism', 'Tinipak River & Daraitan Community Trek',
   'A community-guided trek to the marble boulders and clear pools of Tinipak River in Brgy. Daraitan, with a Sierra Madre ridge viewpoint and locally prepared lunch.',
   'Brgy. Daraitan, Tanay',
   'From Tanay Public Market, ride a jeepney to Brgy. Daraitan (about 45 minutes), then register at the barangay tourism desk before hiking to Tinipak River.',
   14.6100, 121.4300, '2027-02-27T05:00:00+08:00', '2027-02-27T16:00:00+08:00', false, 1.40),

  ('taytay', 'festival', 'Hamaka Festival 2027',
   'Taytay''s week-long Hamaka Festival celebrates hamba (woodwork), makina (sewing machines) and kabuhayan (livelihood) with a Tiangge fashion show, craft demonstrations and street dancing.',
   'Taytay Municipal Hall & Tiangge grounds',
   'Take a Taytay-bound jeepney along Ortigas Avenue Extension and alight at Club Manila East / Taytay Tiangge; the municipal hall is walking distance.',
   14.5586, 121.1328, '2027-02-15T08:00:00+08:00', '2027-02-21T21:00:00+08:00', true, 1.25),

  ('taytay', 'festival', 'Basaan sa Taytay 2027',
   'The Feast of St. John the Baptist turns Taytay''s Poblacion into a water-splashing celebration, with a morning procession from St. John the Baptist Parish and street revelry.',
   'St. John the Baptist Parish & Poblacion streets, Taytay',
   'From Taytay Municipal Hall, walk to St. John the Baptist Parish; expect water splashing along the Poblacion route.',
   14.5586, 121.1328, '2027-06-24T08:00:00+08:00', '2027-06-24T17:00:00+08:00', false, 1.15),

  ('teresa', 'festival', 'AMARA Festival 2027',
   'Teresa''s town fiesta honors St. Rose of Lima with a week of street dancing, adobe-and-marble craft exhibits and community cooking, under the AMARA name drawn from adobe, marmol and apog.',
   'Teresa Municipal Grounds & Poblacion',
   'From Antipolo or Tanay, ride a jeepney to Teresa town proper and alight at the municipal hall.',
   14.5611, 121.2075, '2027-03-01T08:00:00+08:00', '2027-03-07T21:00:00+08:00', false, 1.50),

  ('teresa', 'festival', 'Turumba sa Santa Rosa 2027',
   'Costumed street dancers move from the Saint Rose of Lima Parish through Teresa''s barangays in the Turumba devotion to the town''s patroness, with an evening cultural program at the plaza.',
   'Saint Rose of Lima Parish, Teresa',
   'Jeepneys from Antipolo pass along Teresa Poblacion; ask the driver to drop you at the Saint Rose of Lima Parish.',
   14.5611, 121.2075, '2027-08-23T08:00:00+08:00', '2027-08-23T18:00:00+08:00', false, 1.45)
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
);

-- ----------------------------------------------------------------------------
-- 4. Heritage sites, unique Rizal foods, destinations and logistics
--    Inserted only when the same POI name is not already present in that
--    municipality.
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
  ('angono', 'cultural-arts', 'Blanco Family Museum',
   'Home gallery of the Blanco family of painters, whose rural-life canvases document Angono''s artistic heritage across generations.',
   'heritage_site', 'I. Mendoza St., Brgy. San Roque, Angono, Rizal',
   'From Angono Town Plaza, take a tricycle to I. Mendoza Street; the museum is signposted.',
   '9:00 AM - 5:00 PM (Tue-Sun)', 'Guided tour fee applies', 14.5250, 121.1520, false),

  ('angono', 'cultural-arts', 'Nemiranda Arthouse & Atelier Gallery',
   'Studio-gallery of Nemiranda, filled with murals, sculptures and paintings of Rizal''s folklore and town life.',
   'heritage_site', '117 Doña Justa Subdivision, Brgy. San Vicente, Angono, Rizal',
   'Beside Balaw-Balaw Restaurant in Doña Justa Subdivision; five minutes by tricycle from the town plaza.',
   '9:00 AM - 6:00 PM Daily', 'Free entry', 14.5205, 121.1489, true),

  ('antipolo', 'cultural-arts', 'Pinto Art Museum',
   'A hillside complex of Mediterranean-inspired galleries showing contemporary Philippine art, with gardens and a chapel.',
   'destination', '1 Sierra Madre St., Grand Heights, Antipolo City',
   'From Antipolo Cathedral, take a tricycle to Grand Heights and ask for Pinto Art Museum; about 15 minutes.',
   '9:00 AM - 6:00 PM (Tue-Sun)', 'Entrance fee applies', 14.5960, 121.1560, true),

  ('antipolo', 'cultural-arts', 'Antipolo Cathedral (National Shrine of Our Lady of Peace and Good Voyage)',
   'The pilgrimage church that gave Antipolo its title as the Pilgrimage Capital of the Philippines, home of the venerated Virgin of Antipolo.',
   'heritage_site', 'P. Burgos St., Antipolo City',
   'From the Antipolo jeepney terminal, walk to the cathedral along P. Burgos Street; tricycles also drop off at the plaza.',
   '5:00 AM - 8:00 PM Daily', 'Free', 14.5875, 121.1767, false),

  ('antipolo', 'food-heritage', 'Sumulong Park Suman, Mango & Kasoy Stalls',
   'Park-side stalls selling Antipolo''s SuMaKaH specialties: suman, ripe mangoes and roasted kasuy.',
   'unique_food', 'Sumulong Park, Antipolo City',
   'Beside Antipolo City Hall and Sumulong Park; walkable from the cathedral.',
   '6:00 AM - 8:00 PM Daily', 'Free entry', 14.5878, 121.1760, false),

  ('baras', 'cultural-arts', 'Diocesan Shrine and Parish of St. Joseph (Baras Church)',
   'A 1686 Baroque church and diocesan shrine, one of the oldest in Rizal, with a restored retablo and church museum.',
   'heritage_site', 'Brgy. San Jose, Baras, Rizal',
   'Jeepneys from Antipolo to Baras stop in front of the church; about 25 minutes from Antipolo.',
   '5:30 AM - 7:00 PM Daily', 'Free', 14.5236, 121.2669, true),

  ('baras', 'eco-tourism', 'Masungi Georeserve',
   'A protected limestone karst georeserve with rope-and-ladder trails, karst gardens and Sierra Madre views; visits are by guided reservation.',
   'destination', 'Km 47, Marcos Highway, Baras, Rizal',
   'Ride a jeepney or van along Marcos Highway toward Baras and alight at the Masungi trailhead; reservations are required before arrival.',
   'By reservation (Tue-Sun)', 'Reservation fee applies', 14.6100, 121.2900, false),

  ('binangonan', 'cultural-arts', 'Santa Ursula Parish',
   'Binangonan''s historic lakeside parish, the start of the town''s Kalbaryo pilgrimage and a landmark of its Spanish-era town center.',
   'heritage_site', 'Poblacion, Binangonan, Rizal',
   'From Binangonan Municipal Hall, walk to the Poblacion parish; tricycles from the public market also pass by.',
   '5:30 AM - 7:00 PM Daily', 'Free', 14.4514, 121.1920, false),

  ('binangonan', 'eco-tourism', 'Talim Island & Mt. Tagapo',
   'A lake island in Laguna de Bay with a community-managed trek to Mt. Tagapo and panoramic views of the lake and Rizal coastline.',
   'destination', 'Brgy. Janosa, Talim Island, Binangonan, Rizal',
   'Board a passenger banca at Binangonan Port for Talim Island (about 30 minutes), then register at the Brgy. Janosa jump-off.',
   'Day trips; register before 8:00 AM', 'Boat fare and guide fees apply', 14.4700, 121.2100, true),

  ('binangonan', 'food-heritage', 'Talim Island Buro at Kanduli Stalls',
   'Lakeside stalls serving buro, the fermented pink rice-fish preparation traditional to Talim Island, paired with fried kanduli.',
   'unique_food', 'Binangonan Port, Brgy. Libid, Binangonan, Rizal',
   'Walk or take a short tricycle ride from Binangonan Poblacion to the port area; the stalls line the banca landing.',
   '6:00 AM - 6:00 PM Daily', 'Free entry', 14.4485, 121.1912, false),

  ('cainta', 'cultural-arts', 'Our Lady of Light Parish (Cainta Church)',
   'The centuries-old parish church of Cainta and the devotional center of the SumBingTik and Lenten traditions.',
   'heritage_site', 'A. Bonifacio Ave., Brgy. Sto. Domingo, Cainta, Rizal',
   'Jeepneys along Ortigas Avenue Extension stop near Cainta Junction; the church is a short walk along A. Bonifacio Avenue.',
   '5:00 AM - 8:00 PM Daily', 'Free', 14.5780, 121.1225, false),

  ('cainta', 'cultural-arts', 'Bantayog ng mga Bayani (Hunters ROTC Memorial)',
   'A sculptural memorial honoring the Hunters ROTC guerrillas, a key WWII resistance group organized in Rizal.',
   'heritage_site', 'Cainta Municipal Grounds, Cainta, Rizal',
   'From Cainta Junction, take a tricycle to the municipal grounds; the memorial stands beside the municipal hall.',
   'Open daily', 'Free', 14.5778, 121.1222, false),

  ('cainta', 'food-heritage', 'Aling Kika''s Bibingka',
   'A Cainta institution for sticky-rice bibingka topped with latik, the delicacy behind the town''s reputation as Rizal''s bibingka capital.',
   'unique_food', 'Cainta Public Market, Cainta, Rizal',
   'From Cainta Junction, walk to the public market and look for the Aling Kika''s stall.',
   '6:00 AM - 7:00 PM Daily', 'Free entry', 14.5775, 121.1220, true),

  ('cardona', 'eco-tourism', 'Cardona Rock Garden',
   'A lakeside field of large naturally shaped boulders, cited as one of Rizal''s unique geological sites and a favorite sunset stop.',
   'destination', 'Lakeshore, Cardona, Rizal',
   'From Cardona Municipal Hall, take a tricycle toward the lakeshore and ask for the Rock Garden.',
   'Open daily', 'Free', 14.4400, 121.2450, false),

  ('cardona', 'eco-tourism', 'Cardona Lakeshore & Fishing Village',
   'A working fishing village on Laguna de Bay where visitors can buy fresh catch and watch traditional lake fishing methods.',
   'destination', 'Brgy. Looc, Cardona, Rizal',
   'Take a jeepney to Cardona Poblacion, then a tricycle to Brgy. Looc lakeshore.',
   'Open daily', 'Free', 14.4369, 121.2480, false),

  ('jalajala', 'cultural-arts', 'Santong Lugar',
   'A hillside pilgrimage site in Brgy. Bagumbong linked to the image of Our Lady of Maulawin, with Stations of the Cross and lake views.',
   'heritage_site', 'Brgy. Bagumbong, Jalajala, Rizal',
   'From Jalajala Poblacion, hire a tricycle to Brgy. Bagumbong and ask for the Santong Lugar trail.',
   'Open daily; best visited in the morning', 'Free', 14.3600, 121.3300, true),

  ('jalajala', 'cultural-arts', 'St. Michael the Archangel Parish',
   'A 1733 stone church and the devotional center of Jalajala, where the D''Dalaylay Festival procession begins.',
   'heritage_site', 'Poblacion, Jalajala, Rizal',
   'From Jalajala Municipal Hall, walk to the Poblacion parish along the national road.',
   '5:30 AM - 7:00 PM Daily', 'Free', 14.3547, 121.3247, false),

  ('jalajala', 'eco-tourism', 'Dragon Wellness Farm',
   'An agri-tourism farm producing white- and red-fleshed dragon fruit, with guided orchard walks and farm-fresh produce.',
   'destination', 'Jalajala, Rizal',
   'Arrange a farm visit through the Jalajala Municipal Tourism Office; tricycles from Poblacion can take visitors to the farm.',
   '8:00 AM - 5:00 PM Daily', 'Farm tour fee applies', 14.3500, 121.3200, false),

  ('morong', 'cultural-arts', 'Museong Pambayan (Commandancia)',
   'The former seat of the Distrito Politico-Militar de Morong, now a municipal museum of the town''s Spanish-era and revolutionary history.',
   'heritage_site', 'Morong Municipal Compound, Morong, Rizal',
   'From Morong Town Plaza, walk two minutes to the Commandancia building beside St. Jerome Parish.',
   '8:00 AM - 5:00 PM (Mon-Fri)', 'Free', 14.5175, 121.2395, true),

  ('morong', 'food-heritage', 'Emma''s Panciteria',
   'A long-running Morong eatery known for sinigang na kanduli and chuba, and a stop on the town''s heritage food walk.',
   'restaurant', 'T. Claudio St., Morong, Rizal',
   'Walk from Morong Town Plaza along T. Claudio Street; the panciteria is beside the heritage houses.',
   '9:00 AM - 8:00 PM Daily', 'Free entry', 14.5178, 121.2400, false),

  ('pililla', 'cultural-arts', 'Simbahan ng Pililla (St. Mary Magdalene Parish)',
   'A 1670s stone church with an NHCP historical marker, one of the oldest parishes on the Laguna de Bay shoreline.',
   'heritage_site', 'M.A. Roxas St., Brgy. Bagumbayan, Pililla, Rizal',
   'From Pililla Municipal Hall, walk along M.A. Roxas Street to the church.',
   '5:30 AM - 7:00 PM Daily', 'Free', 14.4853, 121.3064, false),

  ('pililla', 'eco-tourism', 'Pililla Wind Farm',
   'A ridge-top wind farm of tall turbines overlooking Laguna de Bay, Talim Island and the Pililla coastline, popular for sunset viewing.',
   'destination', 'Brgy. Halayhayin, Pililla, Rizal',
   'From Pililla Poblacion, hire a tricycle to the wind farm viewing deck in Brgy. Halayhayin.',
   'Open daily; sunset viewing', 'Free', 14.4700, 121.2900, true),

  ('pililla', 'cultural-arts', 'Bahay na Bato ng Pililla',
   'A Spanish-era stone-and-timber house beside the parish church, used as a filming location and preserved as a heritage landmark.',
   'heritage_site', 'Beside St. Mary Magdalene Parish, Pililla, Rizal',
   'The house stands beside the parish church in Brgy. Bagumbayan; walk from the municipal hall.',
   'Viewing from outside daily', 'Free', 14.4853, 121.3064, false),

  ('rodriguez', 'cultural-arts', 'Pamitinan Cave & Wawa Gorge',
   'A limestone cave within the Pamitinan Protected Landscape, declared a historical site for the 1895 Katipunan assembly led by Andres Bonifacio.',
   'heritage_site', 'Brgy. Wawa, Rodriguez, Rizal',
   'From Rodriguez Poblacion, take a tricycle to Brgy. Wawa and register at the Wawa tourism desk; guides are required for the cave.',
   '6:00 AM - 5:00 PM Daily', 'Guide and registration fees apply', 14.7300, 121.1900, true),

  ('rodriguez', 'eco-tourism', 'Avilon Zoo',
   'One of the country''s largest zoological parks, home to Philippine and exotic wildlife in a forested Sierra Madre foothill setting.',
   'destination', 'Brgy. San Isidro, Rodriguez, Rizal',
   'From Rodriguez Poblacion, take a tricycle or jeepney to Brgy. San Isidro and ask for Avilon Zoo.',
   '8:00 AM - 5:00 PM (Tue-Sun)', 'Entrance fee applies', 14.7400, 121.1700, false),

  ('san-mateo', 'cultural-arts', 'Diocesan Shrine of Our Lady of Aranzazu',
   'The Marian shrine of San Mateo and the center of its September Kakanin Festival, drawing pilgrims from across Rizal and Metro Manila.',
   'heritage_site', 'Gen. Luna Ave., Brgy. Guitnang Bayan I, San Mateo, Rizal',
   'Ride a San Mateo-bound jeepney along Gen. Luna Avenue and alight at the Aranzazu Shrine.',
   '5:00 AM - 8:00 PM Daily', 'Free', 14.6969, 121.1219, false),

  ('san-mateo', 'eco-tourism', 'Timberland Heights Bike Trails',
   'A ridge trail network above San Mateo used for mountain biking, trail running and hiking, with views toward Metro Manila.',
   'destination', 'Timberland Heights, San Mateo, Rizal',
   'From San Mateo Poblacion, take a tricycle to Timberland Heights; private vehicles may park at the clubhouse.',
   '5:00 AM - 6:00 PM Daily', 'Trail fees may apply', 14.7100, 121.1400, false),

  ('san-mateo', 'food-heritage', 'San Mateo Kakanin Stalls',
   'Market stalls selling the kakanin celebrated by the town''s festival: puto, kutsinta, sapin-sapin, biko and puto-bungbong.',
   'unique_food', 'San Mateo Public Market, San Mateo, Rizal',
   'From the Aranzazu Shrine, take a tricycle to the public market; the kakanin stalls are in the market''s food section.',
   '6:00 AM - 7:00 PM Daily', 'Free entry', 14.6960, 121.1210, true),

  ('tanay', 'eco-tourism', 'Tinipak River & Daraitan',
   'A clear river framed by white marble boulders in Brgy. Daraitan, reached by a community-guided trek through Sierra Madre foothills.',
   'destination', 'Brgy. Daraitan, Tanay, Rizal',
   'From Tanay Public Market, ride a jeepney to Brgy. Daraitan (about 45 minutes), then register at the barangay tourism desk.',
   'Day trips; register at barangay desk', 'Environmental and guide fees apply', 14.6100, 121.4300, true),

  ('tanay', 'eco-tourism', 'Regina RICA',
   'The Regina Rosarii Institute for Contemplation in Asia, a hilltop pilgrimage and contemplation center with a giant Dominican statue and gardens.',
   'destination', 'Brgy. Sampaloc, Tanay, Rizal',
   'From Tanay Poblacion, take a tricycle or jeepney toward Brgy. Sampaloc and ask for Regina RICA.',
   '8:00 AM - 5:00 PM (Tue-Sun)', 'Free entry', 14.5400, 121.3100, false),

  ('tanay', 'food-heritage', 'Tanay Highlands Coffee & Suman Stalls',
   'Roadside and market stalls selling Tanay''s highland coffee, suman, kalamay and kasoy produced in the Sierra Madre foothills.',
   'unique_food', 'Tanay Public Market, Tanay, Rizal',
   'From Tanay Municipal Hall, walk to the public market; coffee and kakanin stalls line the highway approach.',
   '6:00 AM - 7:00 PM Daily', 'Free entry', 14.4972, 121.2864, false),

  ('taytay', 'cultural-arts', 'St. John the Baptist Parish',
   'Taytay''s historic parish church and the starting point of the June 24 Basaan water-splashing feast.',
   'heritage_site', 'Poblacion, Taytay, Rizal',
   'From Taytay Municipal Hall, walk to the Poblacion parish; tricycles from the tiangge also pass by.',
   '5:30 AM - 8:00 PM Daily', 'Free', 14.5586, 121.1328, false),

  ('taytay', 'cultural-arts', 'Taytay Woodworks & Hamaka Craft Shops',
   'Workshops and showrooms producing Taytay''s carved furniture, home decor and garments, the "hamba" and "makina" behind the Hamaka Festival.',
   'destination', 'Brgy. San Juan, Taytay, Rizal',
   'From Taytay Municipal Hall, take a tricycle to the woodworks shops along Manila East Road; ask for the Hamaka craft strip.',
   '8:00 AM - 6:00 PM (Mon-Sat)', 'Free entry', 14.5580, 121.1330, false),

  ('teresa', 'cultural-arts', 'Saint Rose of Lima Parish',
   'The camalig-style parish church of Teresa and the center of the Turumba devotion to St. Rose of Lima.',
   'heritage_site', 'Poblacion, Teresa, Rizal',
   'Jeepneys from Antipolo pass along Teresa Poblacion; ask the driver to drop you at the parish.',
   '5:30 AM - 7:00 PM Daily', 'Free', 14.5611, 121.2075, false),

  ('teresa', 'eco-tourism', 'Rancho Bravo (Bravo''s Farm)',
   'A farm-tourism destination with animals, trekking paths and pools set against Teresa''s limestone hills.',
   'destination', 'Brgy. Dalig, Teresa, Rizal',
   'From Teresa Poblacion, hire a tricycle to Brgy. Dalig and ask for Rancho Bravo.',
   '8:00 AM - 5:00 PM Daily', 'Entrance fee applies', 14.5500, 121.2100, false),

  ('teresa', 'eco-tourism', 'Sarian Farm',
   'A working farm and garden destination in Teresa offering orchard walks, farm produce and hillside views.',
   'destination', 'Teresa, Rizal',
   'Arrange the visit through the Teresa Municipal Tourism Office; tricycles from Poblacion can take visitors to the farm.',
   '8:00 AM - 5:00 PM Daily', 'Entrance fee applies', 14.5550, 121.2000, false)
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
);

COMMIT;

-- ----------------------------------------------------------------------------
-- 5. Verification summary (safe to ignore when running via psql)
-- ----------------------------------------------------------------------------
SELECT
  (SELECT count(*) FROM public.municipalities) AS municipalities,
  (SELECT count(*) FROM public.categories)     AS categories,
  (SELECT count(*) FROM public.events WHERE status = 'approved') AS approved_events,
  (SELECT count(*) FROM public.pois_logistics) AS pois,
  (SELECT count(DISTINCT municipality_id) FROM public.events) AS municipalities_with_events;
