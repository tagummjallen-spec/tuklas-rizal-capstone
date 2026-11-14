/// All 14 municipalities of the Province of Rizal.
///
/// Form I: Never use the acronym "RZL". Always use "TuklasRizal" or "Rizal".
class RizalMunicipality {
  final String id;
  final String name;
  final String description;
  final double geofenceLat;
  final double geofenceLng;
  final int geofenceRadiusMeters;
  final String tourismOfficeContact;
  final String? tourismOfficeEmail;
  final String? website;
  final String imageAsset;

  const RizalMunicipality({
    required this.id,
    required this.name,
    required this.description,
    required this.geofenceLat,
    required this.geofenceLng,
    required this.geofenceRadiusMeters,
    required this.tourismOfficeContact,
    this.tourismOfficeEmail,
    this.website,
    required this.imageAsset,
  });
}

/// Seed data mirroring `supabase/migrations/001_initial_schema.sql` `municipalities` table.
class RizalMunicipalities {
  static const List<RizalMunicipality> all = [
    RizalMunicipality(
      id: 'angono',
      name: 'Angono',
      description: 'Art capital of the Philippines; home of the Higantes Festival.',
      geofenceLat: 14.5271,
      geofenceLng: 121.1427,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Angono Municipal Tourism Office',
      imageAsset: 'assets/images/angono.png',
    ),
    RizalMunicipality(
      id: 'antipolo',
      name: 'Antipolo',
      description: 'Provincial capital; pilgrimage site and viewing deck of Metro Manila.',
      geofenceLat: 14.5913,
      geofenceLng: 121.1743,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Antipolo City Tourism Office',
      imageAsset: 'assets/images/antipolo.png',
    ),
    RizalMunicipality(
      id: 'baras',
      name: 'Baras',
      description: 'Rural municipality known for agriculture and nature trails.',
      geofenceLat: 14.4594,
      geofenceLng: 121.2759,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Baras Municipal Tourism Office',
      imageAsset: 'assets/images/baras.png',
    ),
    RizalMunicipality(
      id: 'binangonan',
      name: 'Binangonan',
      description: 'Lakeshore town on Laguna de Bay; site of the Binangonan Petroglyphs.',
      geofenceLat: 14.4750,
      geofenceLng: 121.1883,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Binangonan Municipal Tourism Office',
      imageAsset: 'assets/images/binangonan.png',
    ),
    RizalMunicipality(
      id: 'cainta',
      name: 'Cainta',
      description: 'Gateway town to Rizal; known for delicacies and commercial hubs.',
      geofenceLat: 14.5383,
      geofenceLng: 121.1272,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Cainta Municipal Tourism Office',
      imageAsset: 'assets/images/cainta.png',
    ),
    RizalMunicipality(
      id: 'cardona',
      name: 'Cardona',
      description: 'Lakeside municipality along Laguna de Bay.',
      geofenceLat: 14.4367,
      geofenceLng: 121.2486,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Cardona Municipal Tourism Office',
      imageAsset: 'assets/images/cardona.png',
    ),
    RizalMunicipality(
      id: 'jala_jala',
      name: 'Jala-Jala',
      description: 'Island municipality on Laguna de Bay.',
      geofenceLat: 14.3750,
      geofenceLng: 121.3286,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Jala-Jala Municipal Tourism Office',
      imageAsset: 'assets/images/jala_jala.png',
    ),
    RizalMunicipality(
      id: 'morong',
      name: 'Morong',
      description: 'Heritage town with Spanish-era church and stone fortifications.',
      geofenceLat: 14.4972,
      geofenceLng: 121.3272,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Morong Municipal Tourism Office',
      imageAsset: 'assets/images/morong.png',
    ),
    RizalMunicipality(
      id: 'pililla',
      name: 'Pililla',
      description: 'Wind farm and lake-view municipality.',
      geofenceLat: 14.4406,
      geofenceLng: 121.3422,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Pililla Municipal Tourism Office',
      imageAsset: 'assets/images/pililla.png',
    ),
    RizalMunicipality(
      id: 'rodriguez',
      name: 'Rodriguez',
      description: 'Formerly Montalban; gateway to the Sierra Madre mountains.',
      geofenceLat: 14.6667,
      geofenceLng: 121.2667,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Rodriguez Municipal Tourism Office',
      imageAsset: 'assets/images/rodriguez.png',
    ),
    RizalMunicipality(
      id: 'san_mateo',
      name: 'San Mateo',
      description: 'Residential town along the Marikina River.',
      geofenceLat: 14.6136,
      geofenceLng: 121.1303,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'San Mateo Municipal Tourism Office',
      imageAsset: 'assets/images/san_mateo.png',
    ),
    RizalMunicipality(
      id: 'tanay',
      name: 'Tanay',
      description: 'Mountain resort town; flagship ecotourism destination of Rizal.',
      geofenceLat: 14.5306,
      geofenceLng: 121.2736,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Tanay Municipal Tourism Office',
      imageAsset: 'assets/images/tanay.png',
    ),
    RizalMunicipality(
      id: 'taytay',
      name: 'Taytay',
      description: 'Garment and tiangge capital; Santa Ana de Sapa Parish.',
      geofenceLat: 14.5608,
      geofenceLng: 121.1347,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Taytay Municipal Tourism Office',
      imageAsset: 'assets/images/taytay.png',
    ),
    RizalMunicipality(
      id: 'teresa',
      name: 'Teresa',
      description: 'Small upland municipality with waterfalls and nature spots.',
      geofenceLat: 14.5067,
      geofenceLng: 121.2458,
      geofenceRadiusMeters: 5000,
      tourismOfficeContact: 'Teresa Municipal Tourism Office',
      imageAsset: 'assets/images/teresa.png',
    ),
  ];

  static RizalMunicipality? byId(String id) {
    try {
      return all.firstWhere((m) => m.id == id);
    } on StateError {
      return null;
    }
  }

  static RizalMunicipality? byName(String name) {
    try {
      return all.firstWhere((m) => m.name == name);
    } on StateError {
      return null;
    }
  }
}
