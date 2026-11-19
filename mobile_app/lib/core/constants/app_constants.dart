import 'package:flutter/foundation.dart' show kIsWeb;

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

  // Provincial Tourism Office support contacts (source: rizalprovince.ph).
  static const String tourismOfficeName =
      'Rizal Provincial Tourism Office';
  static const String tourismOfficeAddress =
      '3/F Rizal Provincial Capitol, Circumferencial Road cor. P. Oliveros '
      'St., Ynares Center Complex, Antipolo City, 1870';
  static const String tourismOfficeEmail =
      'tourismoffice@rizalprovincialgov.ph';
  static const String tourismOfficeTrunkline = '(02) 8256-3000';
  static const String tourismOfficeLocal = 'local 4241 / 4242';
  static const String tourismOfficeHours = 'Monday – Friday, 8:00 AM – 5:00 PM';

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
  static const String supabaseUrl = 'https://dhqzhlhyblcziouyoltp.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_kEqnKvO1fUU3xMmvZVCylg_el4jTWnr';

  /// Returns true only when Supabase credentials have been replaced with real values.
  /// When false, the app launches in mock/demo mode without initializing Supabase.
  static bool get isSupabaseConfigured {
    return supabaseUrl.startsWith('https://') &&
        !supabaseUrl.contains('your-project') &&
        supabaseAnonKey.isNotEmpty &&
        !supabaseAnonKey.contains('your-anon-key');
  }

  /// Where Supabase sends the browser/app after Google sign-in.
  ///
  /// Register both values in Supabase → Authentication → URL Configuration:
  ///   `https://<your-domain>/**`     (web)
  ///   io.supabase.tuklasrizal://login-callback   (Android/iOS)
  ///
  /// On web the code is returned to the origin and the app-level session
  /// bootstrap routes first-time users to interest onboarding.
  static String get oauthRedirectUrl {
    if (kIsWeb) return Uri.base.origin;
    return 'io.supabase.tuklasrizal://login-callback';
  }

  static const int defaultPageSize = 20;
}
