import '../../services/lookup_service.dart';
import '../constants/categories.dart';

/// Resolves the user's tourism interests into the live category ids and display
/// names used by `events.category_id` / `pois_logistics.category_id`.
///
/// Interests can arrive in three shapes:
///  * onboarding slugs from the four-step welcome flow (`festival`,
///    `cultural-arts`, `food-heritage`, …),
///  * seeded category ids used in mock/demo mode (`cultural`, `sports`, …),
///  * live Supabase `categories.id` UUIDs from `public.user_interests`.
///
/// Comparing both ids and lowercase names keeps the ranking correct whether the
/// app is running against Supabase or the bundled mock data.
class RecommendationInterests {
  final List<String> categoryIds;
  final List<String> categoryNames;

  const RecommendationInterests({
    this.categoryIds = const [],
    this.categoryNames = const [],
  });

  static const RecommendationInterests empty = RecommendationInterests();

  bool get isEmpty => categoryIds.isEmpty && categoryNames.isEmpty;

  bool matchesId(String? categoryId) =>
      categoryId != null && categoryIds.contains(categoryId);

  bool matchesName(String? value) {
    if (value == null) return false;
    final needle = value.trim().toLowerCase();
    if (needle.isEmpty) return false;
    return categoryNames.contains(needle);
  }

  /// Matches a record by its category id and/or its resolved display label.
  bool matches(String? categoryId, [String? categoryLabel]) =>
      matchesId(categoryId) ||
      matchesName(categoryId) ||
      matchesName(categoryLabel);
}

/// Old onboarding slugs that predate the seeded `categories.slug` values.
const Map<String, String> _slugAliases = {
  'cultural-arts': 'cultural',
  'arts': 'cultural',
  'civic-community': 'civic',
  'sports-recreation': 'sports',
  'eco-tourism': 'cultural',
};

RecommendationInterests resolveRecommendations(
  Iterable<String> interests,
  LookupTables labels,
) {
  final names = <String>{};
  final liveCategoryNames = <String, String>{
    for (final entry in labels.categoryNames.entries)
      entry.key.toLowerCase(): entry.value.toLowerCase(),
  };

  for (final raw in interests) {
    final token = raw.trim().toLowerCase();
    if (token.isEmpty) continue;

    final alias = _slugAliases[token];
    for (final category in TourismCategories.all) {
      final matches = category.id.toLowerCase() == token ||
          category.slug.toLowerCase() == token ||
          category.name.toLowerCase() == token ||
          (alias != null && category.id == alias);
      if (matches) names.add(category.name.toLowerCase());
    }

    // A live UUID (or a label the static catalogue does not know about).
    final liveName = liveCategoryNames[token] ?? labels.category(token);
    if (liveName.isNotEmpty) names.add(liveName.toLowerCase());
  }

  final ids = <String>{
    // Live ids win: every Supabase-backed event/POI carries a UUID.
    for (final entry in labels.categoryNames.entries)
      if (names.contains(entry.value.toLowerCase())) entry.key,
    // Seeded ids keep mock mode working when lookups are unavailable.
    for (final category in TourismCategories.all)
      if (names.contains(category.name.toLowerCase())) category.id,
  };

  return RecommendationInterests(
    categoryIds: ids.toList(growable: false),
    categoryNames: names.toList(growable: false),
  );
}
