/// Form I compliant labels and app-wide constants.
///
/// Rules enforced here:
/// - Never use the acronym "RZL". Use "TuklasRizal" or "Rizal".
/// - Use "Tourism Coordinator" (not generic "Admin"/"Event Organizer").
/// - Feature named "Promote Towns and Events" (not "Recommendations").
class AppConstants {
  // App identity
  static const String appName = 'TuklasRizal';
  static const String appTagline = 'Discover Culture, Arts & Tourism in Rizal';

  // Form I: LGU title terminology
  static const String tourismCoordinatorTitle = 'Tourism Coordinator';
  static const String tourismCoordinatorDirectory =
      'Municipal Tourism Coordinator Directory';

  // Form I: Feature naming — never "Recommendations"
  static const String promoteTownsAndEventsTitle = 'Promote Towns and Events';
  static const String promoteTownsAndEventsSubtitle =
      'Lesser-visited towns and local events matched to your interests';

  // Feature section titles
  static const String featuredEvents = 'Featured Events';
  static const String discoverMunicipalities = 'Discover Municipalities';
  static const String uniqueFoodsRestaurants = 'Unique Foods & Restaurants';
  static const String culturalHeritageSites = 'Cultural & Heritage Sites';
  static const String eventsCalendar = 'Events & Calendar';
  static const String conversationalAssistant = 'Conversational AI Assistant';

  // Category filter chips
  static const String categoryAll = 'All Categories';

  // Geofence
  static const String geofenceWelcomeAlertTitle = 'Welcome to {municipality}!';
  static const String geofenceDebugToggleLabel = 'Simulate Geofence Entry (Dev)';

  // Database table name references (mirror 001_initial_schema.sql)
  static const String tableMunicipalities = 'municipalities';
  static const String tableBarangays = 'barangays';
  static const String tableCategories = 'categories';
  static const String tableUsers = 'users';
  static const String tableUserInterests = 'user_interests';
  static const String tableEvents = 'events';
  static const String tableEventEmbeddings = 'event_embeddings';
  static const String tableEventParticipation = 'event_participation';
  static const String tablePoisLogistics = 'pois_logistics';
  static const String tableCoordinatorInquiries = 'coordinator_inquiries';

  // Supabase placeholder — replace with real keys before production build.
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key';

  /// Returns true only when Supabase credentials have been replaced with real values.
  /// When false, the app launches in mock/demo mode without initializing Supabase.
  static bool get isSupabaseConfigured {
    return supabaseUrl != 'https://your-project.supabase.co' &&
        supabaseAnonKey != 'your-anon-key' &&
        supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty;
  }

  static const int defaultPageSize = 20;
}
