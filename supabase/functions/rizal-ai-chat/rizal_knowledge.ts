// ============================================================================
// rizal_knowledge.ts — TuklasRizal verified tourism reference guide.
//
// A static, hand-compiled reference module that complements the LIVE Supabase
// RAG rows (events / pois_logistics / municipalities). It gives the AI Tour
// Guide practical, verified answers for commute corridors, fee & hour
// benchmarks, the DOT FFAAN pillars, cultural etiquette, town-by-town food /
// pasalubong, and proximity-based multi-town loops.
//
// GROUNDING POLICY (matches the system prompt's "zero guessing" rule):
//   * Every fact below was compiled on 2026-11-20 from official / primary
//     sources (Province of Rizal, DOT, LRTA, municipal tourism offices) and
//     reputable published guides. Source URLs are listed in comments above
//     each block — these comments ARE the grounding mechanism for this data
//     module (no numbered citations in application code).
//   * Peso amounts and minute counts are BENCHMARKS, not guarantees. They are
//     labelled as approximate and the assistant must tell visitors to confirm
//     current rates / hours / trail status with the Municipal Tourism Office
//     before travelling. Where no reliable figure exists, the entry says so
//     and points to the tourism office instead of inventing a number.
//   * Municipal tourism office contacts mirror the verified directory in
//     supabase/seed_full_rizal.sql (official LGU / provincial / Citizen's
//     Charter sources). Unpublished fields are null, never guessed.
//
// This module exports pure data + a topic-selecting context builder. It has no
// runtime dependencies and no network calls, so it is safe to bundle into the
// Deno Edge Function.
// ============================================================================

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface TourismOfficeContact {
  name: string;
  email: string | null;
  phone: string | null;
  address: string | null;
}

export interface MunicipalityReference {
  name: string;
  slug: string;
  /** Lowercased alternate spellings used for message matching. */
  aliases: string[];
  tagline: string;
  /** FFAAN pillar tags this town is strongest in. */
  pillars: string[];
  highlights: string[];
  foodPasalubong: string[];
  commute: string;
  office: TourismOfficeContact;
  /** Why an under-represented town is worth pairing with a popular hub. */
  hiddenGemNote: string;
}

export interface CommuteCorridor {
  hub: string;
  routes: string[];
  note: string;
}

export interface FeeHoursBenchmark {
  spot: string;
  municipality: string;
  hours: string;
  fees: string;
  notes: string;
}

export interface MultiTownLoop {
  name: string;
  towns: string[];
  theme: string;
  route: string;
  highlights: string;
  hiddenGem: string;
}

// ---------------------------------------------------------------------------
// Provincial Tourism Office (verified: rizalprovince.ph/pages/tourism-contactus.html
// and mobile_app/lib/core/constants/app_constants.dart, both fetched 2026-11-19/20).
// ---------------------------------------------------------------------------

export const PROVINCIAL_TOURISM_OFFICE: TourismOfficeContact & { hours: string } = {
  name: "Rizal Provincial Tourism Office",
  email: "tourismoffice@rizalprovincialgov.ph",
  phone: "(02) 8256-3000 local 4241 / 4242 (trunkline (8) 256-3000)",
  address:
    "3/F Rizal Provincial Capitol, Circumferencial Road cor. P. Oliveros St., " +
    "Ynares Center Complex, Antipolo City, 1870",
  hours: "Monday–Friday, 8:00 AM–5:00 PM",
};

export const REFERENCE_GUIDE_SOURCE =
  "TuklasRizal verified reference guide (rizalprovince.ph / DOT / LRTA / LGU tourism offices)";

// ---------------------------------------------------------------------------
// Rizal's 5 Tourism Pillars — FFAAN.
// Verified: DOT Green Corridor Initiative "Rizal Faith, Food, Art, Adventure
// and Nature (FFAAN) Experience" circuit (Antipolo, Angono, Taytay, Cainta).
//   https://mb.com.ph/2021/10/07/new-tourism-circuit-eyed-for-rizals-recovery/
//   https://beta.tourism.gov.ph/news_and_updates/dot-supports-rizal-tourism-circuit-on-food-faith-art-adventure-and-nature/
// The five pillars are used province-wide as the guide's thematic framework.
// ---------------------------------------------------------------------------

export const FFAAN_PILLARS: Array<{ key: string; label: string; blurb: string }> = [
  { key: "faith", label: "Faith", blurb: "Pilgrimage churches and shrines — Antipolo Cathedral, Regina RICA, St. Clement (Angono), St. Jerome (Morong), Our Lady of Aranzazu (San Mateo)." },
  { key: "food", label: "Food", blurb: "Kakanin and lake cuisine — Antipolo suman/kasuy/mangga, Cainta bibingka, Angono balaw-balaw, Morong sinigang na kanduli, San Mateo kakanin." },
  { key: "art", label: "Art", blurb: "Angono (Art Capital): Blanco Family Museum, Botong Francisco murals, Nemiranda, the Petroglyphs; Pinto Art Museum in Antipolo." },
  { key: "adventure", label: "Adventure", blurb: "Mt. Daraitan & Tinipak River, Calinawan Cave, Pamitinan Cave & Wawa Gorge, Masungi Georeserve, Timberland bike trails." },
  { key: "nature", label: "Nature", blurb: "Daranak & Batlag Falls, Hinulugang Taktak, Pililla Wind Farm, Talim Island, Laguna de Bay lakeshore." },
];

// ---------------------------------------------------------------------------
// Cultural etiquette & trail/cave/waterfall safety.
// Verified: Regina RICA dress code & SULOD rules (benjielayug.com/2017/04/regina-rica-tanay-rizal.html,
// traveling-up.com/regina-rica-in-tanay-rizal/); Mt. Daraitan registration /
// carrying capacity / Leave-No-Trace (davestravelcorner.com, tripzilla.ph/mount-daraitan-climb-guide/11381);
// Hinulugang Taktak no-swimming rule (2hottravellers.com/hinulugang-taktak-falls/, rappler.com).
// ---------------------------------------------------------------------------

export const ETIQUETTE_AND_SAFETY: string[] = [
  "Pilgrimage churches & shrines (Antipolo Cathedral, Regina RICA, St. Clement, St. Jerome, Aranzazu): dress modestly — no short shorts, sleeveless/spaghetti-strap or revealing tops; keep silence and respect worshippers. At Regina RICA, remove shoes before entering the SULOD chapel and no photos inside it.",
  "Trails & caves (Mt. Daraitan, Tinipak, Calinawan, Pamitinan, Masungi): register at the barangay/tourism desk, sign the manifest/waiver, and hire the mandatory local guide; respect daily carrying-capacity limits (e.g. Mt. Daraitan summit caps around 300 hikers/day). Wear closed-toe shoes, bring a headlamp for caves, and follow Leave No Trace.",
  "Waterfalls & rivers: check the weather and LGU trail advisories before heading out — flash floods are a real risk in the Sierra Madre. Do not swim where it is banned (Hinulugang Taktak's natural basin is permanently closed; use the treated-water pool). No alcohol at falls; never use soap/shampoo in Tinipak River (a Dumagat community water source).",
  "Always confirm current opening hours, fees, and trail/road status with the Municipal Tourism Office or the Rizal Provincial Tourism Office before travelling, especially on holidays and during the rainy season.",
];

// ---------------------------------------------------------------------------
// Town-by-town reference (all 14 municipalities).
// Sights/commute/contacts: supabase/seed_full_rizal.sql + seed_enriched_rizal.sql
//   (verified from rizalprovince.ph tourism pages, fetched 2026-11-19).
// Food/pasalubong: rizalprovince.ph/pages/tourism-foods.html; thesmartlocal.ph/rizal/;
//   lumina.com.ph signature-dish series; pdfcoffee.com "Rizal Province" locality
//   specialties (lauya=Taytay, binarutak/okoy=Pililla, nilasing na hipon=Cardona,
//   adobong matanda=Teresa/Morong, abnoy=Binangonan); OTOP Philippines listing.
// Municipal office contacts mirror the verified seed directory.
// ---------------------------------------------------------------------------

export const MUNICIPALITIES: MunicipalityReference[] = [
  {
    name: "Angono", slug: "angono", aliases: ["angono"],
    tagline: "Art Capital of the Philippines; home of the Higantes Festival and the Angono–Binangonan Petroglyphs.",
    pillars: ["art", "food", "faith"],
    highlights: ["Angono–Binangonan Petroglyphs (circa 3000 B.C.)", "Blanco Family Museum", "Botong Francisco Museum & Street Murals", "Nemiranda Arthouse", "St. Clement Parish (Diocesan Shrine)", "Higantes Festival (Nov)"],
    foodPasalubong: ["Balaw-balaw / buro (fermented rice-fish)", "Fried itik (duck)", "Minaluto (Rizal-style paella)", "Dinilawang kanduli sa alagaw", "12 kinds of sinigang; ginataang kuhol; sinabawang balut (Balaw-Balaw Restaurant, Doña Justa St.)"],
    commute: "From EDSA Shaw/Starmall or Cubao, take a UV Express or jeepney bound for Angono via Manila East Road and alight at Angono Town Plaza (~45 min–1 hr, traffic-dependent). From Pasig Palengke, ride an Angono-bound jeepney.",
    office: { name: "Angono Municipal Tourism, Culture and the Arts Office", email: "angonotourismoffice@gmail.com", phone: "(02) 8661-3646", address: "Beside the Municipal Building, Brgy. San Isidro, Angono, Rizal" },
    hiddenGemNote: "Pair with Antipolo for the Art & Pilgrimage loop — Angono adds National Artist heritage (Botong Francisco, Lucio San Pedro) and the ancient Petroglyphs most day-trippers skip.",
  },
  {
    name: "Antipolo", slug: "antipolo", aliases: ["antipolo", "antipolo city"],
    tagline: "Pilgrimage Capital of the Philippines; Antipolo Cathedral, Hinulugang Taktak, Pinto Art Museum and the SuMaKaH Festival.",
    pillars: ["faith", "art", "food", "nature"],
    highlights: ["Antipolo Cathedral (National Shrine of Our Lady of Peace and Good Voyage)", "Pinto Art Museum", "Hinulugang Taktak Falls", "Casa Santa Museum / Jardin de Miramar", "Boso-Boso Church", "SuMaKaH / Maytime Festival (May)"],
    foodPasalubong: ["Suman sa ibos", "Kasuy (cashew nuts)", "Ripe Antipolo mangoes", "Stalls outside the Cathedral (~₱120/dozen suman; ~₱150/100g kasuy — benchmark)"],
    commute: "LRT-2 to Antipolo Station (SM Masinag), then jeepney/tricycle to the Cathedral (~30–40 min train from Recto + short ride). Or UV Express/jeepney from Cubao or Ortigas via Sumulong Highway/Marcos Highway to Antipolo Cathedral (~1–1.5 hr). From Pasig, jeepney/FX/van to Antipolo, alight Ynares Center.",
    office: { name: "Antipolo City Culture, Arts and Tourism Promotions Office (AnCCATPO)", email: "antipolotourism@gmail.com", phone: null, address: null },
    hiddenGemNote: "The usual gateway hub — pair it with Angono/Taytay (art & garments) or a lakeshore town so the trip is not just the Cathedral.",
  },
  {
    name: "Baras", slug: "baras", aliases: ["baras"],
    tagline: "Riverside town: 1686 St. Joseph Parish, the Tromba Festival, Masungi Georeserve and Palo Alto Falls.",
    pillars: ["faith", "adventure", "nature"],
    highlights: ["Diocesan Shrine & Parish of St. Joseph (1686 Baroque)", "Masungi Georeserve (by reservation)", "Palo Alto Falls (Brgy. Pinugay, Marcos Highway)", "Tromba Festival (fluvial procession)"],
    foodPasalubong: ["Lakeshore kakanin and Laguna de Bay fish (shared lakeshore tradition)", "No single signature delicacy is widely published — ask the tourism office for current pasalubong makers"],
    commute: "From Antipolo or Tanay, ride a jeepney along Manila East Road / Marcos Highway and alight at Baras town proper (~1.5–2 hr from Manila). For Palo Alto Falls, jeepneys from Antipolo/Masinag and Cogeo bound for Palo Alto pass the gate.",
    office: { name: "Baras Municipal Tourism Office", email: null, phone: null, address: "Sitio Soro-soro, Brgy. Santiago, Baras, Rizal" },
    hiddenGemNote: "An under-represented lakeshore town — pair with Morong/Cardona for heritage churches plus Masungi's karst trails, away from the Antipolo crowds.",
  },
  {
    name: "Binangonan", slug: "binangonan", aliases: ["binangonan"],
    tagline: "Lakeshore town facing Talim Island: Petroglyphs, Santa Ursula Parish, buro at kanduli.",
    pillars: ["food", "nature", "faith"],
    highlights: ["Angono–Binangonan Petroglyphs", "Santa Ursula Parish", "Talim Island & Mt. Tagapo (banca from Binangonan Port)", "Marian Hill", "Kalbaryo (288 steps)", "Binalayan Festival"],
    foodPasalubong: ["Buro at kanduli (Talim Island fermented rice-fish)", "Fried itik", "Abnoy (seasoned blighted eggs)", "Fresh Laguna de Bay catch"],
    commute: "From Pasig Palengke or Cubao, take a Binangonan-bound jeepney or UV Express via Manila East Road (~1–1.5 hr). At Binangonan Port, board a passenger banca to Talim Island (~30 min).",
    office: { name: "Binangonan Municipal Tourism Office", email: "brcc@binangonan.gov.ph", phone: "(02) 8579-3407", address: "Manila East Road, Brgy. Calumpang, Binangonan, Rizal 1940" },
    hiddenGemNote: "Pair with Cardona/Morong on the Lakeshore Heritage loop — Talim Island and the Petroglyphs are a quiet alternative to the usual Antipolo day trip.",
  },
  {
    name: "Cainta", slug: "cainta", aliases: ["cainta"],
    tagline: "Bibingka Capital; home of the SumBingTik Festival and Our Lady of Light Parish.",
    pillars: ["food", "faith"],
    highlights: ["Our Lady of Light Parish (Cainta Church)", "Bantayog ng mga Bayani (Hunters ROTC Memorial)", "Tahanang Walang Hagdan", "Aling Kika's bibingka", "SumBingTik Festival (Dec 1)"],
    foodPasalubong: ["Bibingka with latik (Aling Kika's, 101 A. Bonifacio Ave., Sto. Domingo; ~4AM–5:30PM; (02) 655-0029)", "Sapin-sapin, kutsinta, kalamay, budin/cassava cake", "Coco jam (matamis na bao)", "Suman and latik"],
    commute: "From Ortigas or EDSA Shaw, ride a Cainta-bound jeepney or UV Express along Ortigas Avenue Extension and alight at Cainta Junction (~45 min–1 hr). From Pasig Palengke, jeepney along Ortigas Ext.",
    office: { name: "Cainta Municipal Tourism, Culture and Arts Office (MTCAO)", email: "tourism@cainta.gov.ph", phone: "(02) 8696-2584", address: "No. 73 A. Bonifacio Ave., Brgy. Sto. Domingo, Cainta, Rizal 1900" },
    hiddenGemNote: "A quick food stop on the Art & Pilgrimage loop — add it to Antipolo/Angono/Taytay for the province's best bibingka and kakanin.",
  },
  {
    name: "Cardona", slug: "cardona", aliases: ["cardona"],
    tagline: "Lakeside fishing town: Kaluskos bamboo-arch festival, Cardona Rock Garden, nilasing na hipon.",
    pillars: ["food", "nature", "faith"],
    highlights: ["Cardona Rock Garden", "Cardona Lakeshore & Fishing Village", "Our Lady of the Holy Rosary Parish (1872)", "Kaluskos Festival (Dec)", "Pagoda Festival sa Lawa"],
    foodPasalubong: ["Nilasing na hipon (sweet-tangy 'drunken shrimp', a fiesta treat)", "Fresh Laguna de Bay catch", "Lakeshore kakanin"],
    commute: "From Binangonan or Morong, ride a jeepney along Manila East Road to Cardona town proper (~1–1.5 hr from Manila). From Pasig Palengke, a Cardona-bound jeepney via Manila East Road.",
    office: { name: "Cardona Municipal Tourism Office", email: "cardonatourism@gmail.com", phone: null, address: "Cardona Municipal Hall, Cardona, Rizal" },
    hiddenGemNote: "A genuinely under-represented lakeshore town — pair with Binangonan/Morong for the Rock Garden, fishing-village life and the Kaluskos bamboo arches.",
  },
  {
    name: "Jala-Jala", slug: "jalajala", aliases: ["jala-jala", "jalajala", "jala jala"],
    tagline: "Peninsula town on Laguna de Bay: D'Dalaylay Festival, Santong Lugar, dragon fruit and carabao milk.",
    pillars: ["nature", "food", "faith"],
    highlights: ["Santong Lugar (hillside pilgrimage)", "St. Michael the Archangel Parish (1733)", "Dragon Wellness Farm / Sanchez Agrifarm (dragon fruit)", "Dairy Delights (Llano Farmers carabao-milk co-op)", "D'Dalaylay Festival (Sept 29)"],
    foodPasalubong: ["Dragon fruit (pitaya, white- and red-fleshed)", "Carabao milk and dairy (Dairy Delights, ~₱35/liter farm-gate — benchmark)", "Fresh lake produce"],
    commute: "From Binangonan or Tanay, ride a jeepney to Jala-Jala Poblacion (~2–2.5 hr from Manila, the farthest lakeshore town). From Tanay Public Market, jeepney/tricycle onward.",
    office: { name: "Jala-Jala Municipal Tourism Office", email: null, phone: null, address: "National Road, Brgy. Special District, Jala-Jala, Rizal" },
    hiddenGemNote: "The quiet end of the Highlands & Windmill loop — pair with Tanay/Pililla for dragon-fruit farms, carabao-milk dairy and the Santong Lugar pilgrimage without the crowds.",
  },
  {
    name: "Morong", slug: "morong", aliases: ["morong"],
    tagline: "Heritage town: 1615 St. Jerome Parish, the Commandancia, Sanrok sa Ringring Festival.",
    pillars: ["faith", "food", "art"],
    highlights: ["St. Jerome Parish Church (1615, Chinese-Baroque)", "Museong Pambayan (Commandancia)", "Morong Town Plaza & Tomas Claudio monument", "Sanrok sa Ringring Festival", "Emma's Panciteria"],
    foodPasalubong: ["Sinigang na kanduli (catfish sour soup)", "Chuba", "Pancit (Emma's Panciteria, T. Claudio St.)", "Adobong matanda (arobong matanra)", "Kakanin"],
    commute: "From Pasig Palengke or Cubao, ride a Morong-bound jeepney via Manila East Road and alight at Morong Town Plaza (~1–1.5 hr). The church and Commandancia are beside the plaza.",
    office: { name: "Morong Municipal Tourism Office", email: null, phone: "(02) 8537-5000", address: "2/F GAD Building, Morong Municipal Compound, Morong, Rizal" },
    hiddenGemNote: "An under-represented heritage town — pair with Cardona/Baras for the 1615 Chinese-Baroque church and the Commandancia museum, plus the best sinigang na kanduli.",
  },
  {
    name: "Pililla", slug: "pililla", aliases: ["pililla"],
    tagline: "Lakeshore town: Pililla Wind Farm, 1670s St. Mary Magdalene Church, Magsolangtan Festival, pineapple.",
    pillars: ["nature", "food", "faith"],
    highlights: ["Pililla Wind Farm (27 turbines, Brgy. Halayhayin)", "Simbahan ng Pililla (St. Mary Magdalene, 1670s)", "Bahay na Bato", "Kawayan Farm (bamboo)", "Magsolangtan Festival (July 22)"],
    foodPasalubong: ["Award-winning sweet pineapple", "Binarutak / pinugutan (sour-spicy shrimp) with okoy (shrimp-sweet-potato fritter) and spicy vinegar", "Tilapia and lake fish"],
    commute: "From Tanay or Antipolo, take a Pililla-bound jeepney via Manila East Road (~1.5–2 hr from Manila). From Pililla Poblacion, hire a tricycle to the wind farm viewing deck in Brgy. Halayhayin.",
    office: { name: "Pililla Municipal Tourism Office", email: "tourismpililla1910@gmail.com", phone: "(02) 8654-1093", address: "M.A. Roxas St., Brgy. Bagumbayan, Pililla, Rizal" },
    hiddenGemNote: "Pair with Tanay/Jala-Jala on the Highlands & Windmill loop — the free wind-farm sunset view and pineapple farms are a relaxed contrast to Tanay's hikes.",
  },
  {
    name: "Rodriguez", slug: "rodriguez", aliases: ["rodriguez", "montalban"],
    tagline: "Sierra Madre gateway: Wawa Gorge, Pamitinan Cave, Avilon Zoo, Montalban/Pamitinan Festival.",
    pillars: ["adventure", "nature", "faith"],
    highlights: ["Pamitinan Cave & Wawa Gorge (1895 Katipunan site)", "Avilon Zoo", "Payaran Falls (7 infinity pools, Brgy. Mascap)", "Mt. Ayaas / Mt. Pamitinan", "Our Lady of the Most Holy Rosary Parish", "Pamitinan Festival (Dec)"],
    foodPasalubong: ["Sierra Madre foothill produce and river/lake fish", "No single signature delicacy is widely published — ask the tourism office"],
    commute: "From Cubao or Marikina, ride a Rodriguez/Montalban-bound jeepney and alight at the Wawa terminal, then a tricycle to the jump-off (~1–1.5 hr). LRT-2 to Marikina-Pasig Station connects to Montalban jeepneys.",
    office: { name: "Rodriguez Municipal Tourism and Cultural Affairs Office (MTCAO)", email: "montalbantourism@gmail.com", phone: null, address: "JP Rizal St., Brgy. Balite, Rodriguez, Rizal" },
    hiddenGemNote: "The adventure gateway nearest Metro Manila — pair with a Tanay highland trip for caving and gorge trekking without the longer lakeshore drive.",
  },
  {
    name: "San Mateo", slug: "san-mateo", aliases: ["san mateo"],
    tagline: "Home of Our Lady of Aranzazu Shrine, the Kakanin Festival and Timberland bike trails.",
    pillars: ["food", "faith", "adventure"],
    highlights: ["Diocesan Shrine of Our Lady of Aranzazu", "Timberland Heights bike trails", "Camp Sinai (Mount Sinai) viewpoint", "Kakanin Festival (Sept 9)"],
    foodPasalubong: ["Kakanin: puto, kutsinta, sapin-sapin, biko, bibingka, puto-bungbong", "Suman with latik (Timberland area)", "Public-market kakanin stalls"],
    commute: "From Batasan or Marikina, ride a San Mateo-bound jeepney along Gen. Luna Avenue and alight at the Aranzazu Shrine (~45 min–1 hr). From Cubao, jeepney via Marikina.",
    office: { name: "San Mateo Municipal Tourism Office", email: null, phone: "(02) 8297-8100 loc. 106", address: "Gen. Luna Ave., Brgy. Guitnang Bayan I, San Mateo, Rizal 1850" },
    hiddenGemNote: "A quick kakanin-and-bike stop nearest the metro — pair with Rodriguez/Montalban for an adventure + food day without a long drive.",
  },
  {
    name: "Tanay", slug: "tanay", aliases: ["tanay"],
    tagline: "Eco-tourism capital: Daranak Falls, Tinipak River, Regina RICA, Calinawan Cave and the Hane Festival.",
    pillars: ["adventure", "nature", "faith", "food"],
    highlights: ["Daranak & Batlag Falls", "Tinipak River & Mt. Daraitan (Brgy. Daraitan)", "Regina RICA (71-ft Marian statue)", "Calinawan Cave", "San Ildefonso de Toledo Parish (1773–1783)", "Hane Festival (Nov) & Tanay Rodeo (Jan)"],
    foodPasalubong: ["Highland coffee (Tanay Hills Coffee Beanery, Sampaloc)", "Suman, kalamay, kasoy", "Kanduli dishes", "Kainan sa Tabing Lawa (lakeside restaurant since the 1960s, Marcos Hwy)"],
    commute: "From EDSA Shaw/Starmall or Cubao, take a Tanay-bound jeepney or UV Express and alight at Tanay Public Market (~1.5–2 hr). Tanay Public Market is the transfer hub: jeepney/tricycle to Brgy. Daraitan (~45 min–1 hr) for Tinipak/Mt. Daraitan, or to Daranak Falls, Regina RICA and the Sampaloc highlands.",
    office: { name: "Tanay Municipal Tourism Office", email: "lgutourismtanay2020@gmail.com", phone: "0968 556 5335", address: "2/F Tanay Municipal Hall, M.H. del Pilar St., Tanay, Rizal 1980" },
    hiddenGemNote: "The highland hub — pair it with Pililla/Jala-Jala so the trip includes the wind farm and dragon-fruit farms, not just the falls.",
  },
  {
    name: "Taytay", slug: "taytay", aliases: ["taytay"],
    tagline: "Garments Capital of the Philippines: the Tiangge, Hamaka Festival and Basaan.",
    pillars: ["art", "food", "faith"],
    highlights: ["Taytay Tiangge (garments/fabric, beside Club Manila East)", "Taytay Woodworks & Hamaka craft shops", "St. John the Baptist Parish", "Christ the King Parish ('Church in the Sky')", "Hamaka Festival (Feb) & Basaan (June 24)"],
    foodPasalubong: ["Lauya (beef/pork soup with achuete and cinnamon)", "Barutak / shrimp sinigang", "Garments, textiles and carved woodworks from the Tiangge (non-food pasalubong)"],
    commute: "From Ortigas or EDSA Shaw, take a Taytay-bound jeepney along Ortigas Avenue Extension and alight at Club Manila East / Taytay Tiangge (~45 min–1 hr). Busy tiangge market days: Monday, Thursday, Sunday.",
    office: { name: "Taytay Municipal Tourism and Cultural Affairs Office", email: "tourism@taytayrizal.gov.ph", phone: "+63 2 8284-4786", address: "4/F Taytay Municipal Hall, Don Hilario Cruz Ave., CME Compound, Brgy. San Juan, Taytay, Rizal" },
    hiddenGemNote: "Pair with Antipolo/Angono on the Art & Pilgrimage loop — the Tiangge and woodworks add shopping and craft heritage to the church-and-museum day.",
  },
  {
    name: "Teresa", slug: "teresa", aliases: ["teresa"],
    tagline: "Upland agricultural town: St. Rose of Lima Parish, the AMARA Festival and Turumba.",
    pillars: ["faith", "nature", "food"],
    highlights: ["Saint Rose of Lima Parish", "Rancho Bravo (Bravo's Farm)", "Sarian Farm", "Teresa Tourist Assistance Desk (Municipal Hall)", "AMARA Festival & Turumba sa Santa Rosa (Aug 23)"],
    foodPasalubong: ["Adobong matanda (arobong matanra), a local adobo variation", "Upland farm produce", "Mountain-resort dining (Villa Sampaguita / Real Cove area)"],
    commute: "From Antipolo or Tanay, ride a jeepney to Teresa town proper and alight at the Municipal Hall along Corazon C. Aquino Avenue (~1–1.5 hr). Via Ortigas Avenue Extension through Antipolo (not via Angono).",
    office: { name: "Teresa Municipal Tourism Office", email: "teresarizaltourism@yahoo.com", phone: "(02) 8250-6800", address: "Teresa Municipal Hall, Corazon C. Aquino Ave., Teresa, Rizal" },
    hiddenGemNote: "A quiet upland town between Antipolo and Tanay — pair it with either hub for farm tourism and the Turumba devotion away from the crowds.",
  },
];

// ---------------------------------------------------------------------------
// Commute corridors from Metro Manila (jeepney / UV Express / bus / LRT-2).
// Route descriptions: supabase/seed_full_rizal.sql how_to_get_there (verified
//   from rizalprovince.ph); Pinto commute (traveling-up.com/pinto-art-museum-antipolo-guide/);
// LRT-2 East Extension stations & travel time (lrta.gov.ph, pco.gov.ph,
//   ph.emb-japan.go.jp, ppp.gov.ph — Marikina-Pasig & Antipolo stations, opened
//   July 2021; Recto→Masinag ~30–40 min by train vs ~3 hr by road).
// Minute counts are APPROXIMATE and traffic-dependent — always labelled.
// ---------------------------------------------------------------------------

export const COMMUTE_CORRIDORS: CommuteCorridor[] = [
  {
    hub: "LRT-2 (Recto–Antipolo line)",
    routes: [
      "LRT-2 east extension stations: Marikina-Pasig (in front of Robinsons Metro East / Sta. Lucia, near Mayor Gil Fernando Ave., Marikina) and Antipolo (in front of SM Masinag, near Masinag Junction / Sumulong Highway, Antipolo).",
      "Recto → Antipolo (Masinag) is roughly 30–40 minutes by train (vs ~3 hours by bus/jeepney). Single-journey fare was around ₱30 at opening (2021) — confirm the current fare matrix with LRTA.",
      "From Antipolo Station, take a jeepney/tricycle to Antipolo Cathedral, Pinto Art Museum or Hinulugang Taktak. From Marikina-Pasig Station, connect to Rodriguez/Montalban and San Mateo jeepneys.",
      "Transfer to LRT-2 from MRT-3 Cubao (via LRT-2 Cubao) or LRT-1 Recto (via LRT-2 Doroteo Jose).",
    ],
    note: "Fastest rail gateway to Antipolo and the Marikina–Rodriguez corridor.",
  },
  {
    hub: "Cubao / Aurora Blvd (Quezon City)",
    routes: [
      "UV Express / jeepney to Antipolo (via Sumulong Highway or Marcos Highway), Tanay (via Manila East Road / Marcos Highway), Angono and Binangonan.",
      "Rodriguez/Montalban-bound jeepney via Marikina to the Wawa terminal (then tricycle to Pamitinan/Wawa).",
      "Jeepney to San Mateo via Marikina (Gen. Luna Avenue).",
    ],
    note: "Major northern hub; also reach it via MRT-3 Cubao or LRT-2 Cubao.",
  },
  {
    hub: "EDSA Shaw / Starmall (Mandaluyong)",
    routes: [
      "UV Express / jeepney to Angono, Antipolo, Tanay and Taytay/Cainta via Ortigas Avenue Extension and Manila East Road.",
      "Tanay-bound UV Express/jeepney alights at Tanay Public Market (highland transfer hub).",
    ],
    note: "Convenient southern-Metro Manila hub for the Ortigas Extension / Manila East Road corridors.",
  },
  {
    hub: "Pasig Palengke (Pasig City)",
    routes: [
      "Jeepney / UV Express along Manila East Road to Angono, Binangonan, Cardona, Morong, Baras, Pililla and Tanay (the lakeshore corridor).",
      "Jeepney along Ortigas Avenue Extension to Cainta and Taytay.",
    ],
    note: "Best jump-off for the lakeshore towns (Binangonan → Cardona → Morong → Baras → Pililla).",
  },
  {
    hub: "Key transfer hubs inside Rizal",
    routes: [
      "Tanay Public Market: jeepney/tricycle to Brgy. Daraitan (~45 min–1 hr) for Tinipak River & Mt. Daraitan; also to Daranak Falls, Regina RICA and the Sampaloc highlands.",
      "Binangonan Port and Cardona port: passenger banca to Talim Island (~30 min); register at the Brgy. Janosa jump-off for Mt. Tagapo.",
      "Antipolo Cathedral / Sumulong Park: tricycles to Pinto Art Museum (Grand Heights) and Hinulugang Taktak (Taktak Road).",
      "Masinag Junction (Antipolo): LRT-2 Antipolo Station; jeepneys up Sumulong Highway to the Cathedral.",
      "Tikling Junction (Ortigas Ave. Ext.): branch to Antipolo (up Sumulong) or continue to Taytay/Cainta.",
    ],
    note: "Manila East Road is the lakeshore spine; Ortigas Avenue Extension serves Cainta–Taytay–Antipolo; Marcos Highway (Marikina–Infanta) serves Antipolo–Baras–Tanay.",
  },
];

export const COMMUTE_TIME_NOTE =
  "Typical road travel times from Metro Manila (APPROXIMATE, traffic-dependent): " +
  "Cainta/Taytay/Angono/San Mateo ~45 min–1 hr; Antipolo/Teresa/Binangonan/Cardona/Morong/Rodriguez ~1–1.5 hr; " +
  "Baras/Pililla/Tanay ~1.5–2 hr; Jala-Jala ~2–2.5 hr. LRT-2 Recto→Antipolo ~30–40 min. " +
  "Always allow extra time on weekends/holidays and confirm current routes with the tourism office.";

// ---------------------------------------------------------------------------
// Entrance & guide fee benchmarks + operating hours for flagship spots.
// These are published BENCHMARKS (some traveler-reported), NOT guaranteed rates.
// Sources:
//   Pinto Art Museum — traveling-up.com/pinto-art-museum-antipolo-guide/ (fees
//     effective June 1, 2025; hours), pintoart.org (hours), airial.travel.
//   Hinulugang Taktak — 2hottravellers.com/hinulugang-taktak-falls/,
//     rappler.com/life-and-style/same-day-travel-weekend-ideas-luzon-philippines,
//     lakbaypinas.com/20-must-visit-antipolo-tourist-spot-guide-2025/, gmanetwork.com.
//   Daranak/Batlag/Calinawan — lakbaypinas.com/ultimate-guide-daranak-falls-in-tanay-rizal-2025/,
//     scribd.com/document/833796503/TANAY-DAY-TOUR-PACKAGE, tripadvisor/wanderlog reviews.
//   Mt. Daraitan & Tinipak — danielsecotravels.com/mt-daraitan-tinipak-river-hike/,
//     tripzilla.ph/mount-daraitan-climb-guide/11381, traveling-up.com/travel-guide-tanay-rizal/,
//     davestravelcorner.com (2025 registration/carrying capacity).
//   Regina RICA — traveling-up.com/regina-rica-in-tanay-rizal/,
//     benjielayug.com/2017/04/regina-rica-tanay-rizal.html, cityhillresort.com/journal/regina-rica-tanay-guide.
//   Pililla Wind Farm — rappler.com/life-and-style/travel/223096-list-nature-dates-trips-for-couples-and-groups/,
//     lakbaypinas.com/guide-to-pililla-wind-farm-in-tanay-rizal-2025/, tripadvisor reviews.
// ---------------------------------------------------------------------------

export const FEE_HOURS_BENCHMARKS: FeeHoursBenchmark[] = [
  {
    spot: "Pinto Art Museum", municipality: "Antipolo",
    hours: "Tue–Sun, 10:00 AM–6:00 PM; closed Mondays (holiday schedules may vary).",
    fees: "Benchmark (effective June 1, 2025): ₱300 adult; ₱240 senior/PWD; ₱150 student with valid ID; free 3 yrs & below. Private vehicles pay a ₱20 subdivision road user's fee; no parking fee at the museum.",
    notes: "Confirm current admission with the museum (pintoartmuseumph@gmail.com / (02) 8697-1015) before a special trip; rates have changed over the years.",
  },
  {
    spot: "Hinulugang Taktak Falls / National Park", municipality: "Antipolo",
    hours: "Roughly Tue–Sun, 7:00 AM–4:00 PM; closed Mondays for maintenance (some listings say 7 AM–3 PM — confirm).",
    fees: "Entrance FREE (registration required); swimming pool and adventure activities (spiderweb, canopy walk, rappelling) free. Parking benchmark: ₱20 motorcycle / ₱45 car. Park under rehabilitation; fees temporarily waived.",
    notes: "Swimming in the falls' natural basin is PERMANENTLY BANNED (water quality/safety) — use the separate treated-water pool. Confirm current access/hours with AnCCATPO.",
  },
  {
    spot: "Daranak Falls", municipality: "Tanay",
    hours: "Daily, 8:00 AM–5:00 PM.",
    fees: "Benchmark entrance ~₱50–₱75 per person (reports vary; recent combined reports ~₱175–₱180 with Batlag). Picnic shed ~₱300; picnic table ~₱100–₱200.",
    notes: "No overnight camping, no alcohol, no plastics/styrofoam, no pets. Confirm current rates with the Tanay Tourism Office / site reception.",
  },
  {
    spot: "Batlag Falls", municipality: "Tanay",
    hours: "Daily, roughly 8:00 AM–5:00 PM (accessed through Daranak).",
    fees: "Benchmark: separate ~₱100 per person day entrance (private property, on top of Daranak's fee); ~₱200 overnight camping (bring your own tent).",
    notes: "Quieter than Daranak; you still pay Daranak's entrance to pass through. Confirm current rates.",
  },
  {
    spot: "Calinawan Cave", municipality: "Tanay",
    hours: "Day visits; ~15–20 min tricycle/drive from Daranak Falls.",
    fees: "Benchmark: ~₱20 environmental fee + ~₱500 tour guide (per group). Five levels; ~30 min to explore with crouching through low passages.",
    notes: "Katipunan-era resistance stronghold. Hire the local guide; bring a headlamp. Confirm fees with the Tanay Tourism Office.",
  },
  {
    spot: "Mt. Daraitan & Tinipak River", municipality: "Tanay",
    hours: "Day hikes; register at the Brgy. Daraitan Hall jump-off (early starts common).",
    fees: "Benchmark community fees (vary by year/source): registration/barangay ~₱20–₱30; environmental ~₱20–₱100; mandatory guide ~₱500/day hike (good for ~5–10 pax; some report ~₱750/group of 5), ~₱1,250 overnight; parking ~₱50–₱100; bridge/raft crossing ~₱5. DIY budget ~₱800–₱1,500/person.",
    notes: "Register, submit a manifest, sign a waiver, and hire the mandatory local guide. Summit carrying capacity ~300/day with a 30-min summit limit; weekends may require prior booking. Leave No Trace; no soap/shampoo in Tinipak River (Dumagat water source). Confirm with Tanay Tourism (lgutourismtanay2020@gmail.com / 0968 556 5335).",
  },
  {
    spot: "Regina RICA (Regina Rosarii Institute for Contemplation in Asia)", municipality: "Tanay",
    hours: "8:00 AM–5:00 PM; CLOSED Tuesdays (except Tuesday of Holy Week). Mass ~11 AM Mon–Sat (not Tue); Sun 11 AM & 3:30 PM.",
    fees: "Entrance FREE; donations accepted. Parking benchmark ~₱50 car / ~₱20 motorcycle; restroom donation ~₱10.",
    notes: "71-ft Marian statue, Sitio Aguho, Brgy. Sampaloc (Marcos Highway). Modest dress; shoes off and no photos inside the SULOD chapel; keep silence. Confirm with reginarica.org / reginarica@yahoo.com.",
  },
  {
    spot: "Pililla Wind Farm", municipality: "Pililla",
    hours: "Open daily during daylight (roughly 7:00 AM–5:30/6:00 PM); best at sunset/golden hour.",
    fees: "Entrance FREE at the main viewing deck/visitor center (Brgy. Halayhayin, Manila East Road); parking free (optional donations). Some private hilltop viewpoints charge a minimal ~₱10.",
    notes: "27 turbines overlooking Laguna de Bay; short uphill walk to the view deck. Confirm access with the Pililla Tourism Office.",
  },
];

export const FEE_CONFIRM_NOTE =
  "All peso amounts and hours above are BENCHMARKS compiled from published sources and may change. " +
  "Before travelling, confirm current rates, hours and trail/road status with the specific Municipal Tourism Office " +
  "or the Rizal Provincial Tourism Office (tourismoffice@rizalprovincialgov.ph / (02) 8256-3000 local 4241/4242).";

// ---------------------------------------------------------------------------
// Proximity-based multi-town loops.
// Geography/contacts verified from the seed directory + rizalprovince.ph; the
// Art & Pilgrimage loop aligns with the DOT FFAAN circuit (Antipolo/Angono/
// Taytay/Cainta). Each loop pairs a popular hub with an under-represented town.
// ---------------------------------------------------------------------------

export const MULTI_TOWN_LOOPS: MultiTownLoop[] = [
  {
    name: "Art & Pilgrimage Loop",
    towns: ["Antipolo", "Angono", "Taytay"],
    theme: "Faith + Art + Food (the DOT FFAAN circuit; add Cainta for bibingka).",
    route: "Antipolo (Cathedral, Pinto Art Museum, Hinulugang Taktak) → Angono (Petroglyphs, Blanco/Botong/Nemiranda, Balaw-Balaw) → Taytay (Tiangge, Woodworks, St. John the Baptist). Via Ortigas Avenue Extension / Manila East Road; ~45 min–1.5 hr between hubs.",
    highlights: "Morning Mass/pilgrimage at Antipolo Cathedral; contemporary art at Pinto; National Artist heritage and the ancient Petroglyphs in Angono; garments/woodworks shopping in Taytay; lunch of balaw-balaw/fried itik (Angono) or lauya (Taytay).",
    hiddenGem: "Angono and Taytay are the under-represented pairings — Angono for its two National Artists and the Petroglyphs, Taytay for the Tiangge and craft heritage most Cathedral-only visitors miss. Optional Cainta stop for bibingka.",
  },
  {
    name: "Lakeshore Heritage Loop",
    towns: ["Binangonan", "Cardona", "Morong", "Baras"],
    theme: "Faith + Food + Nature along the Manila East Road lakeshore.",
    route: "Binangonan (Petroglyphs, Santa Ursula, Talim Island/buro) → Cardona (Rock Garden, fishing village, nilasing na hipon) → Morong (1615 St. Jerome, Commandancia, sinigang na kanduli) → Baras (1686 St. Joseph, Masungi/Palo Alto). All on Manila East Road; ~1–2 hr from Manila, short hops between towns.",
    highlights: "Lakeshore heritage churches, the Cardona Rock Garden and fishing-village life, Morong's Chinese-Baroque church and museum, and Baras' Masungi karst trails; buro/kanduli, nilasing na hipon and sinigang na kanduli food crawl.",
    hiddenGem: "Cardona, Morong and Baras are all under-represented — pair them with Binangonan for a quiet heritage-and-food lakeshore day far from the Antipolo crowds.",
  },
  {
    name: "Highlands & Windmill Loop",
    towns: ["Tanay", "Pililla", "Jala-Jala"],
    theme: "Adventure + Nature + Food (Sierra Madre foothills to the lake peninsula).",
    route: "Tanay (Daranak/Batlag, Tinipak/Mt. Daraitan, Regina RICA, Calinawan) → Pililla (Wind Farm sunset, Kawayan Farm, pineapple) → Jala-Jala (Santong Lugar, dragon-fruit farms, Dairy Delights). Via Manila East Road / Marcos Highway; Tanay Public Market is the transfer hub; ~1.5–2.5 hr from Manila.",
    highlights: "Waterfalls and caving in Tanay; the free Pililla wind-farm sunset view; Jala-Jala's dragon-fruit farms and carabao-milk dairy; highland coffee, suman and pineapple pasalubong.",
    hiddenGem: "Pililla and Jala-Jala are the under-represented pairings — pair them with Tanay so the trip includes the wind farm and farm tourism, not just the falls and hikes.",
  },
];

// ---------------------------------------------------------------------------
// Topic detection + context selection.
// ---------------------------------------------------------------------------

export interface KnowledgeTopics {
  commute: boolean;
  fees: boolean;
  food: boolean;
  etiquette: boolean;
  itinerary: boolean;
  pillars: boolean;
}

function norm(text: string): string {
  return text
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

const TOPIC_KEYWORDS: Record<keyof KnowledgeTopics, string[]> = {
  commute: ["commute", "commuting", "jeep", "jeepney", "uv", "express", "bus", "lrt", "mrt", "train", "station", "masinag", "marikina", "cubao", "shaw", "starmall", "palengke", "pasig", "ortigas", "highway", "route", "terminal", "tricycle", "trike", "banca", "boat", "port", "how to get", "papunta", "paano", "pumunta", "sakay", "sasakyan", "biyahe", "travel time", "orasan", "galing"],
  fees: ["fee", "fees", "entrance", "admission", "ticket", "price", "prices", "cost", "rate", "rates", "peso", "php", "magkano", "bayad", "environmental", "guide fee", "registration", "register", "permit", "hours", "open", "opening", "close", "closed", "schedule", "orasan", "bukas", "sarado", "libre", "free", "donation", "parking"],
  food: ["food", "eat", "eating", "restaurant", "carinderia", "delicacy", "delicacies", "pasalubong", "snack", "kakanin", "suman", "bibingka", "kasuy", "cashew", "mangga", "mango", "balaw", "buro", "itik", "duck", "kanduli", "sinigang", "lauya", "okoy", "binarutak", "hipon", "shrimp", "adobo", "abnoy", "coffee", "kape", "pineapple", "pinya", "dragon fruit", "pitaya", "carabao", "milk", "gatas", "kain", "kainan", "masarap", "ulam", "merienda", "almusal", "lunch", "dinner", "breakfast"],
  etiquette: ["etiquette", "dress", "dress code", "clothes", "attire", "modest", "church", "shrine", "pilgrimage", "mass", "simbahan", "safety", "safe", "trail", "hike", "hiking", "cave", "spelunking", "waterfall", "falls", "swim", "swimming", "weather", "bagyo", "typhoon", "flood", "advisory", "bawal", "prohibited", "rules", "respect", "mandatory", "capacity", "leave no trace", "sulod", "shoes", "guide"],
  itinerary: ["itinerary", "loop", "loops", "weekend", "day trip", "daytrip", "day tour", "plan", "planning", "multi-town", "hidden gem", "hidden gems", "off the beaten", "underrated", "lesser-visited", "away from crowds", "recommend", "recommendation", "suggest", "pasyal", "gala", "bakasyon", "libot", "ikot", "where should i go", "saang maganda"],
  pillars: ["ffaan", "pillar", "pillars", "circuit", "green corridor", "gci", "five pillars", "5 pillars"],
};

export function detectTopics(message: string): KnowledgeTopics {
  const haystack = norm(message);
  const result = {} as KnowledgeTopics;
  (Object.keys(TOPIC_KEYWORDS) as Array<keyof KnowledgeTopics>).forEach((topic) => {
    result[topic] = TOPIC_KEYWORDS[topic].some((kw) => {
      const k = norm(kw);
      // Short tokens (<=3 chars like "p", "uv") must match as whole words to
      // avoid false positives; longer tokens match as substrings.
      if (k.length <= 3) return new RegExp(`(^|\\s)${k}($|\\s)`).test(haystack);
      return haystack.includes(k);
    });
  });
  return result;
}

/** Municipalities whose name/alias appears in the message (or the explicit one). */
export function mentionedMunicipalities(message: string, explicit: string | null): MunicipalityReference[] {
  const haystack = norm(message);
  const found = MUNICIPALITIES.filter((m) => {
    const names = [m.name, m.slug, ...m.aliases].map(norm);
    return names.some((n) => n.length > 0 && haystack.includes(n));
  });
  if (explicit) {
    const e = norm(explicit);
    const match = MUNICIPALITIES.find((m) =>
      [m.name, m.slug, ...m.aliases].map(norm).some((n) => n === e || n.includes(e) || (e.length > 2 && e.includes(n)))
    );
    if (match && !found.includes(match)) found.unshift(match);
  }
  return found;
}

function officeLine(office: TourismOfficeContact): string {
  const parts: string[] = [office.name];
  if (office.email) parts.push(office.email);
  if (office.phone) parts.push(office.phone);
  if (office.address) parts.push(office.address);
  return parts.join(" | ");
}

function municipalityBlock(m: MunicipalityReference): string {
  return [
    `Municipality: ${m.name} — ${m.tagline}`,
    `  FFAAN pillars: ${m.pillars.join(", ")}`,
    `  Highlights: ${m.highlights.join("; ")}`,
    `  Food & pasalubong: ${m.foodPasalubong.join("; ")}`,
    `  Commute: ${m.commute}`,
    `  Tourism office: ${officeLine(m.office)}`,
    `  Hidden-gem angle: ${m.hiddenGemNote}`,
  ].join("\n");
}

// Hard character budget for the reference-guide block. Together with the
// (bounded) live DB context this keeps the whole prompt inside the Groq
// on-demand tier's ~8000 tokens-per-minute request ceiling.
const KNOWLEDGE_CHAR_BUDGET = 7500;

/**
 * Build the relevant verified-reference context for a visitor message.
 * Budget-aware: sections are added in priority order until the character
 * budget is reached, so the prompt never balloons past the LLM tier limit.
 * Always keeps the provincial office, a safety/confirm reminder, and any
 * mentioned towns; then the requested topic (fees / commute / food / loops).
 */
export function buildKnowledgeContext(message: string, explicitMunicipality: string | null): string {
  const topics = detectTopics(message);
  const towns = mentionedMunicipalities(message, explicitMunicipality);
  const general = towns.length === 0; // province-wide / open-ended question
  const haystack = norm(message);
  const strongEtiquette = ["dress", "church", "shrine", "simbahan", "safety", "trail", "hike", "cave", "waterfall", "falls", "swim", "weather", "bagyo", "bawal", "pilgrimage", "mass"].some((k) => haystack.includes(k));

  const header = "=== VERIFIED REFERENCE GUIDE (static, compiled from official sources) ===\n" +
    "Use these verified facts alongside the live database records. Peso amounts and travel times are BENCHMARKS — tell visitors to confirm current rates/hours/status before travelling.";

  const provincial = `[PROVINCIAL TOURISM OFFICE]\n${officeLine(PROVINCIAL_TOURISM_OFFICE)} | Hours: ${PROVINCIAL_TOURISM_OFFICE.hours}`;
  const safetyCompact = "[SAFETY & CONFIRMATION REMINDER]\n" +
    "- Confirm current fees, hours and trail/road status with the Municipal Tourism Office before travelling. Hikers/cavers/waterfall visitors: check weather and LGU advisories, register and hire the mandatory guide where required, follow Leave No Trace and site rules (no swimming in banned basins). Modest dress at churches/shrines.";
  const townBlock = towns.length > 0 ? "[MUNICIPALITY REFERENCE — towns mentioned]\n" + towns.map(municipalityBlock).join("\n\n") : "";

  const feeRelevant = towns.length > 0
    ? FEE_HOURS_BENCHMARKS.filter((f) => towns.some((t) => norm(t.name) === norm(f.municipality)))
    : FEE_HOURS_BENCHMARKS;
  const feeList = feeRelevant.length > 0 ? feeRelevant : FEE_HOURS_BENCHMARKS;
  const feeBlock = "[ENTRANCE / GUIDE FEE BENCHMARKS & OPERATING HOURS (confirm before travel)]\n" +
    feeList.map((f) => `- ${f.spot} (${f.municipality}) | Hours: ${f.hours} | Fees: ${f.fees} | Notes: ${f.notes}`).join("\n") +
    "\n" + FEE_CONFIRM_NOTE;
  const commuteBlock = "[COMMUTE CORRIDORS FROM METRO MANILA]\n" +
    COMMUTE_CORRIDORS.map((c) => `${c.hub}:\n${c.routes.map((r) => `  - ${r}`).join("\n")}`).join("\n") +
    "\n" + COMMUTE_TIME_NOTE;
  const foodBlock = "[TOWN-BY-TOWN FOOD & PASALUBONG GUIDE]\n" +
    MUNICIPALITIES.map((m) => `- ${m.name}: ${m.foodPasalubong.join("; ")}`).join("\n");
  const loopsBlock = "[PROXIMITY-BASED MULTI-TOWN LOOPS — pair a popular hub with an under-represented town]\n" +
    MULTI_TOWN_LOOPS.map((l) => `- ${l.name} (${l.towns.join(" → ")}) | Theme: ${l.theme} | Route: ${l.route} | Hidden gem: ${l.hiddenGem}`).join("\n");
  const pillarsBlock = "[RIZAL'S 5 TOURISM PILLARS — FFAAN (DOT Green Corridor Initiative)]\n" +
    FFAAN_PILLARS.map((p) => `- ${p.label}: ${p.blurb}`).join("\n");
  const etiquetteBlock = "[CULTURAL ETIQUETTE & TRAIL/CAVE/WATERFALL SAFETY]\n" +
    ETIQUETTE_AND_SAFETY.map((e) => `- ${e}`).join("\n");

  // Priority 0 = always keep; 1 = requested topic; 2 = nice-to-have context.
  const sections: Array<{ priority: number; text: string }> = [
    { priority: 0, text: provincial },
    { priority: 0, text: safetyCompact },
  ];
  if (townBlock) sections.push({ priority: 0, text: townBlock });
  if (topics.fees) sections.push({ priority: 1, text: feeBlock });
  if (topics.commute || general) sections.push({ priority: 1, text: commuteBlock });
  if (topics.itinerary || general) sections.push({ priority: 1, text: loopsBlock });
  if (topics.food && general) sections.push({ priority: 1, text: foodBlock });
  if (strongEtiquette) sections.push({ priority: 1, text: etiquetteBlock });
  if (topics.pillars || general) sections.push({ priority: 2, text: pillarsBlock });

  sections.sort((a, b) => a.priority - b.priority);
  const kept: string[] = [];
  let used = header.length;
  for (const s of sections) {
    if (!s.text) continue;
    // Always keep priority-0 sections; fit the rest within the budget.
    if (s.priority > 0 && used + s.text.length > KNOWLEDGE_CHAR_BUDGET) continue;
    kept.push(s.text);
    used += s.text.length;
  }

  return [header, ...kept, "=== END VERIFIED REFERENCE GUIDE ==="].join("\n\n");
}
