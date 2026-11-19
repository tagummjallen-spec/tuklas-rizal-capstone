import 'package:flutter/material.dart';

import '../utils/tourism_images.dart';
import 'app_motion.dart';

/// Reusable event card.
///
/// The card fills whatever height its parent gives it: the photo takes the
/// remaining space (`Expanded`) and every text line is capped with
/// `maxLines` + ellipsis, so no RenderFlex overflow stripes can appear at any
/// viewport or text scale.
class EventCard extends StatelessWidget {
  final String title;
  final String municipality;
  final String date;
  final String category;
  final String? imageUrl;

  /// Raw category / municipality values used to pick the Rizal fallback photo.
  final String? categoryKey;
  final String? municipalityKey;

  final bool isPromoted;
  final bool isFeatured;
  final bool isSaved;

  /// Interest-based boost: shows the "Recommended for You" badge.
  final bool isRecommended;
  final VoidCallback onTap;
  final VoidCallback? onToggleSave;

  /// Matches `EventDetailPage`'s Hero tag for a shared image transition.
  /// Only pass one instance per route so tags stay unique.
  final String? heroTag;

  const EventCard({
    super.key,
    required this.title,
    required this.municipality,
    required this.date,
    required this.category,
    required this.imageUrl,
    this.categoryKey,
    this.municipalityKey,
    this.isPromoted = false,
    this.isFeatured = false,
    this.isSaved = false,
    this.isRecommended = false,
    required this.onTap,
    this.onToggleSave,
    this.heroTag,
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
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (heroTag != null)
                    Hero(
                      tag: heroTag!,
                      child: TourismImage(
                        imageUrl: imageUrl,
                        category: categoryKey ?? category,
                        municipality: municipalityKey,
                      ),
                    )
                  else
                    TourismImage(
                      imageUrl: imageUrl,
                      category: categoryKey ?? category,
                      municipality: municipalityKey,
                    ),
                  if (isPromoted)
                    const Positioned(
                      top: 6,
                      left: 6,
                      child: _Tag(
                        text: 'Promoted',
                        background: Color(0xFFFFC800),
                        foreground: Color(0xFF033300),
                      ),
                    ),
                  if (isFeatured)
                    const Positioned(
                      top: 6,
                      left: 6,
                      child: _Tag(
                        text: 'Featured',
                        background: Color(0xFF033300),
                        foreground: Colors.white,
                      ),
                    ),
                  if (isRecommended)
                    const Positioned(
                      bottom: 6,
                      left: 6,
                      child: _Tag(
                        text: 'Recommended for You',
                        background: Color(0xFF033300),
                        foreground: Color(0xFFFFC800),
                      ),
                    ),
                  if (onToggleSave != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _SaveButton(
                        isSaved: isSaved,
                        onPressed: onToggleSave!,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _MetaLine(icon: Icons.location_on, text: municipality),
                  const SizedBox(height: 2),
                  _MetaLine(icon: Icons.event, text: date),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
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

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFF6B6B6B)),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B6B6B)),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  const _Tag({
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool isSaved;
  final VoidCallback onPressed;
  const _SaveButton({required this.isSaved, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: AnimatedBookmarkIcon(isSaved: isSaved, size: 17),
        ),
      ),
    );
  }
}
