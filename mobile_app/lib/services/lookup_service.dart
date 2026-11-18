import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/municipalities.dart';
import '../core/constants/categories.dart';

/// Human-readable labels for the UUID foreign keys stored on events and POIs.
///
/// Live rows carry `municipality_id` / `category_id` UUIDs, so cards that used
/// to print the raw id now resolve them through this table.
class LookupTables {
  final Map<String, String> municipalityNames;
  final Map<String, String> categoryNames;

  const LookupTables({
    this.municipalityNames = const {},
    this.categoryNames = const {},
  });

  static const LookupTables empty = LookupTables();

  String municipality(String? id) {
    if (id == null || id.isEmpty) return 'Rizal';
    return municipalityNames[id] ?? 'Rizal';
  }

  String category(String? id) {
    if (id == null || id.isEmpty) return 'General';
    return categoryNames[id] ?? 'General';
  }
}

abstract class LookupService {
  Future<LookupTables> load();
}

class SupabaseLookupService implements LookupService {
  @override
  Future<LookupTables> load() async {
    final client = Supabase.instance.client;
    final tables = LookupTables(
      municipalityNames: <String, String>{},
      categoryNames: <String, String>{},
    );

    try {
      final municipalities =
          await client.from('municipalities').select('id,name');
      for (final row in municipalities) {
        final id = row['id'] as String?;
        final name = row['name'] as String?;
        if (id != null && name != null) {
          tables.municipalityNames[id] = name;
        }
      }
    } catch (_) {
      // Reference data is non-critical for rendering a card.
    }

    try {
      final categories = await client.from('categories').select('id,name');
      for (final row in categories) {
        final id = row['id'] as String?;
        final name = row['name'] as String?;
        if (id != null && name != null) {
          tables.categoryNames[id] = name;
        }
      }
    } catch (_) {
      // Same as above.
    }

    return tables;
  }
}

class MockLookupService implements LookupService {
  @override
  Future<LookupTables> load() async {
    return LookupTables(
      municipalityNames: {
        for (final municipality in RizalMunicipalities.all)
          municipality.id: municipality.name,
      },
      categoryNames: {
        for (final category in TourismCategories.all) category.id: category.name,
      },
    );
  }
}
