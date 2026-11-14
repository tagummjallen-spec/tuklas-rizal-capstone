import 'package:flutter/material.dart';

/// Tourism categories mirroring `supabase/migrations/001_initial_schema.sql` `categories` table.
///
/// Used for USER_INTERESTS selection and Discovery Hub category filters.
class TourismCategory {
  final String id;
  final String name;
  final String slug;
  final String description;
  final Color color;
  final IconData? icon;

  const TourismCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.color,
    this.icon,
  });
}

/// Seed categories — Cultural, Festival, Civic, Sports, Health, Food/Heritage.
class TourismCategories {
  static const List<TourismCategory> all = [
    TourismCategory(
      id: 'cultural',
      name: 'Cultural',
      slug: 'cultural',
      description: 'Cultural and heritage sites and experiences',
      color: Color(0xFF033300),
    ),
    TourismCategory(
      id: 'festival',
      name: 'Festival',
      slug: 'festival',
      description: 'Town festivals and celebrations',
      color: Color(0xFFFFC800),
    ),
    TourismCategory(
      id: 'civic',
      name: 'Civic',
      slug: 'civic',
      description: 'Civic activities and community events',
      color: Color(0xFF033300),
    ),
    TourismCategory(
      id: 'sports',
      name: 'Sports',
      slug: 'sports',
      description: 'Sports events and activities',
      color: Color(0xFFFFC800),
    ),
    TourismCategory(
      id: 'health',
      name: 'Health',
      slug: 'health',
      description: 'Health and wellness tourism',
      color: Color(0xFF033300),
    ),
    TourismCategory(
      id: 'food_heritage',
      name: 'Food/Heritage',
      slug: 'food-heritage',
      description: 'Unique Rizal delicacies and food heritage',
      color: Color(0xFFFFC800),
    ),
  ];

  static TourismCategory? byId(String id) {
    try {
      return all.firstWhere((c) => c.id == id);
    } on StateError {
      return null;
    }
  }
}
