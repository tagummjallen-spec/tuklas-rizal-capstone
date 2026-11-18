-- ============================================================================
-- TuklasRizal: Schema-Aligned Sample Seed Data
-- Matches 001_initial_schema.sql exact columns & slugs
-- ============================================================================

DO $$
DECLARE
    angono_id      uuid := (SELECT id FROM public.municipalities WHERE slug = 'angono' LIMIT 1);
    binangonan_id  uuid := (SELECT id FROM public.municipalities WHERE slug = 'binangonan' LIMIT 1);
    taytay_id      uuid := (SELECT id FROM public.municipalities WHERE slug = 'taytay' LIMIT 1);
    tanay_id       uuid := (SELECT id FROM public.municipalities WHERE slug = 'tanay' LIMIT 1);
    antipolo_id    uuid := (SELECT id FROM public.municipalities WHERE slug = 'antipolo' LIMIT 1);
    morong_id      uuid := (SELECT id FROM public.municipalities WHERE slug = 'morong' LIMIT 1);

    cultural_id    uuid := (SELECT id FROM public.categories WHERE slug = 'cultural-arts' LIMIT 1);
    festival_id    uuid := (SELECT id FROM public.categories WHERE slug = 'festival' LIMIT 1);
    food_id        uuid := (SELECT id FROM public.categories WHERE slug = 'food-heritage' LIMIT 1);
    eco_id         uuid := (SELECT id FROM public.categories WHERE slug = 'eco-tourism' LIMIT 1);
    civic_id       uuid := (SELECT id FROM public.categories WHERE slug = 'civic-community' LIMIT 1);
BEGIN
    -- 1. Barangays (matches public.barangays: municipality_id, name, latitude, longitude)
    INSERT INTO public.barangays (municipality_id, name, latitude, longitude) VALUES
        (angono_id, 'San Isidro', 14.5266, 121.1536),
        (angono_id, 'San Vicente', 14.5240, 121.1510),
        (angono_id, 'Kalayaan', 14.5295, 121.1560),
        (angono_id, 'Mahabang Parang', 14.5420, 121.1680),
        (binangonan_id, 'Malapad na Bato', 14.4620, 121.1950),
        (binangonan_id, 'Tatala', 14.4710, 121.1980),
        (binangonan_id, 'Pantok', 14.4820, 121.1860),
        (binangonan_id, 'Libid', 14.4514, 121.1920),
        (taytay_id, 'San Juan', 14.5586, 121.1328),
        (taytay_id, 'Santa Ana', 14.5530, 121.1310),
        (taytay_id, 'Dolores', 14.5650, 121.1390),
        (taytay_id, 'Muzon', 14.5410, 121.1480),
        (tanay_id, 'San Andres', 14.5450, 121.3120),
        (tanay_id, 'Daraitan', 14.6140, 121.4320),
        (tanay_id, 'Plaza Aldea', 14.4994, 121.2856),
        (antipolo_id, 'San Jose', 14.5842, 121.1763),
        (antipolo_id, 'Dela Paz', 14.5910, 121.1740),
        (antipolo_id, 'Beverly Hills', 14.5815, 121.1620),
        (morong_id, 'San Juan', 14.5181, 121.2392),
        (morong_id, 'San Pedro', 14.5150, 121.2410),
        (morong_id, 'Maybancal', 14.5050, 121.2490)
    ON CONFLICT (municipality_id, name) DO NOTHING;

    -- 2. Approved Events (matches public.events exact columns)
    INSERT INTO public.events (
        municipality_id, category_id, title, description, venue_name,
        how_to_get_there, latitude, longitude, start_date, end_date,
        status, is_featured, promotion_weight
    ) VALUES
    (
        angono_id, festival_id,
        'Higantes Festival Grand Parade',
        'Annual celebration honoring San Clemente featuring towering paper-mache giants, street dancing, and water splashing traditions in the Art Capital of the Philippines.',
        'Angono Municipal Plaza & Poblacion Streets',
        'Ride a jeepney or UV Express bound for Angono/Binangonan from Shaw Blvd or Cubao; alight at Angono Town Plaza.',
        14.5266, 121.1536,
        NOW() + INTERVAL '5 days', NOW() + INTERVAL '7 days',
        'approved', true, 1.30
    ),
    (
        binangonan_id, cultural_id,
        'Binangonan Lakeshore Heritage & Kalbaryo Walk',
        'Guided cultural walk from Santa Ursula Parish up to the historic Kalbaryo hilltop overlooking Laguna de Bay and Talim Island.',
        'Santa Ursula Parish & Kalbaryo Hilltop, Binangonan',
        'Take a Binangonan-bound jeepney via Manila East Road and get off at Binangonan Municipal Hall / Poblacion.',
        14.4514, 121.1920,
        NOW() + INTERVAL '10 days', NOW() + INTERVAL '10 days',
        'approved', true, 1.45
    ),
    (
        taytay_id, civic_id,
        'Taytay Tiangge Night Market & Hamaka Showcase',
        'Showcase of locally crafted garments, woodworks, and cultural performances celebrating Taytay craftsmanship.',
        'Taytay Municipal Tiangge Grounds, Brgy. San Juan',
        'Take a Taytay/Angono jeepney along Ortigas Avenue Extension; alight directly at Club Manila East / Taytay Tiangge.',
        14.5586, 121.1328,
        NOW() + INTERVAL '3 days', NOW() + INTERVAL '14 days',
        'approved', true, 1.20
    ),
    (
        tanay_id, eco_id,
        'Daranak Falls & Calinawan Cave Eco-Tour',
        'Community-guided eco-tourism expedition exploring Daranak Falls and the historic chambers of Calinawan Cave.',
        'Daranak Falls Nature Park, Brgy. Plaza Aldea, Tanay',
        'Ride a Tanay-bound jeepney from Shaw Blvd or Cubao to Tanay Public Market, then hire a tricycle to Daranak Falls.',
        14.5441, 121.3125,
        NOW() + INTERVAL '8 days', NOW() + INTERVAL '9 days',
        'approved', false, 1.25
    ),
    (
        antipolo_id, food_id,
        'Antipolo Suman, Mangga & Kasuy Culinary Fair',
        'Taste traditional Antipolo delicacies alongside local artisans near the historic Antipolo Cathedral.',
        'Sumulong Park & Antipolo Cathedral Grounds',
        'Take an Antipolo Simbahan UV Express or jeepney from Cubao or Ortigas; alight at Antipolo Cathedral.',
        14.5878, 121.1760,
        NOW() + INTERVAL '12 days', NOW() + INTERVAL '15 days',
        'approved', false, 1.15
    ),
    (
        morong_id, cultural_id,
        'St. Jerome Parish & Morong Heritage Tour',
        'Explore the iconic 17th-century Baroque facade of St. Jerome Parish Church and historic Morong town landmarks.',
        'St. Jerome Parish Church, Brgy. San Juan, Morong',
        'Ride a Morong/Tanay jeepney via Manila East Road and alight at Morong Town Plaza.',
        14.5181, 121.2392,
        NOW() + INTERVAL '18 days', NOW() + INTERVAL '19 days',
        'approved', true, 1.50
    );

    -- 3. POIs, Unique Foods & Logistics (matches public.pois_logistics exact columns)
    INSERT INTO public.pois_logistics (
        municipality_id, category_id, name, poi_type, description,
        address, how_to_get_there, operating_hours, entrance_fee,
        latitude, longitude, is_promoted
    ) VALUES
    (
        angono_id, cultural_id,
        'Angono-Binangonan Petroglyphs',
        'heritage_site',
        'Oldest known prehistoric rock engravings in the Philippines dating back to 3000 BC, declared a National Cultural Treasure.',
        'Brgy. San Isidro, Angono / Brgy. Malapad na Bato, Binangonan',
        'Accessible via Eastridge Avenue in Angono/Binangonan by private car or chartered tricycle from Angono Poblacion.',
        '8:00 AM - 4:00 PM (Tue-Sun)', 'Free',
        14.5322, 121.1869, true
    ),
    (
        angono_id, food_id,
        'Balaw-Balaw Specialty Restaurant & Art Gallery',
        'unique_food',
        'Iconic Angono art gallery and restaurant famous for traditional Rizal cuisine, fermented rice-shrimp relish (balaw-balaw), and crispy fried itik.',
        '14 Doña Justa Subdivision, Brgy. San Vicente, Angono, Rizal',
        'Along Manila East Road in Brgy. San Vicente, Angono; 5 minutes from Angono Town Plaza.',
        '10:00 AM - 9:00 PM Daily', 'Free Gallery Entry',
        14.5205, 121.1489, true
    ),
    (
        binangonan_id, food_id,
        'Binangonan Lakeshore Fresh Tilapia & Kinilaw Stalls',
        'unique_food',
        'Authentic lakeside dining offering freshly caught Laguna de Bay tilapia, ayungin, and traditional Rizal delicacies overlooking Talim Island.',
        'Brgy. Libid / Binangonan Port Area, Binangonan, Rizal',
        'Walk or take a short tricycle ride from Binangonan Poblacion down to the Laguna de Bay port pier.',
        '7:00 AM - 8:00 PM Daily', 'Free',
        14.4485, 121.1912, true
    ),
    (
        taytay_id, civic_id,
        'Taytay Tiangge Garments Capital Complex',
        'destination',
        'The largest wholesale and retail garments market in Rizal offering locally manufactured apparel at factory prices.',
        'Manila East Road, Brgy. San Juan, Taytay, Rizal',
        'Take any Taytay/Angono/Binangonan jeepney or UV Express from Ortigas or Cubao and alight at Taytay Tiangge.',
        '8:00 AM - 6:00 PM (Peak: Mon, Tue, Thu, Fri)', 'Free',
        14.5562, 121.1335, false
    ),
    (
        antipolo_id, eco_id,
        'Hinulugang Taktak Protected Landscape',
        'destination',
        'Historic waterfall park and national recreational landmark surrounded by lush gardens and picnic pavilions.',
        'Taktak Road, Brgy. Dela Paz, Antipolo City, Rizal',
        'Take a tricycle from Antipolo Cathedral or Robinsons Place Antipolo directly to Hinulugang Taktak.',
        '8:00 AM - 5:00 PM Daily', 'PHP 50',
        14.5956, 121.1672, false
    ),
    (
        morong_id, cultural_id,
        'St. Jerome Parish Church (Morong Church)',
        'heritage_site',
        'Famous for its intricate three-story Baroque facade crafted by Chinese artisans in the 1850s.',
        'T. Claudio St., Brgy. San Juan, Morong, Rizal',
        'Ride a Morong/Tanay jeepney from EDSA Shaw or Cubao and alight right at Morong Town Plaza.',
        '6:00 AM - 6:00 PM Daily', 'Free',
        14.5181, 121.2392, true
    );
END $$;