import 'package:flutter/material.dart';

import '../utils/tourism_images.dart';

/// Reusable POI (point of interest) card with a Rizal photography fallback and
/// a bookmark toggle.
class PoiCard extends StatelessWidget {
  final String name;
  final String municipality;
  final String category;
  final String? imageUrl;
  final String? categoryKey;
  final String? municipalityKey;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback? onToggleSave;

  const PoiCard({
    super.key,
    required this.name,
    required this.municipality,
    required this.category,
    required this.imageUrl,
    this.categoryKey,
    this.municipalityKey,
    this.isSaved = false,
    required this.onTap,
    this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TourismImage(
                    imageUrl: imageUrl,
                    category: categoryKey ?? category,
                    municipality: municipalityKey,
                  ),
                  if (onToggleSave != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onToggleSave,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              isSaved ? Icons.bookmark : Icons.bookmark_border,
                              size: 18,
                              color: const Color(0xFF033300),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_city,
                          size: 13, color: Color(0xFF6B6B6B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          municipality,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF6B6B6B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F6F2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF033300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
