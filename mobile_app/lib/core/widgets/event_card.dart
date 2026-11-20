import 'package:flutter/material.dart';

import '../utils/tourism_images.dart';
import 'app_motion.dart';
import 'promotion_reason_pill.dart';

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

  /// Compact calendar chip such as `NOV 20`, pinned to the photo corner.
  final String? dateBadge;

  /// Adds a municipality pill beside the category pill (used on the full-width
  /// Events list where there is room for both).
  final bool showMunicipalityTag;

  /// Short explainable reason (e.g. "Featured · Hidden Gem Municipality")
  /// rendered as a transparent pill so fair-promotion decisions are visible.
  final String? promotionReason;
  final VoidCallback onTap;
  final VoidCallback? onToggleSave;

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
    this.dateBadge,
    this.showMunicipalityTag = false,
    this.promotionReason,
    required this.onTap,
    this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark ? const Color(0xFF24352C) : const Color(0xFFF7F6F2);
    final pillFg = isDark
        ? const Color(0xFF9FE7B5)
        : const Color(0xFF033300);

    return PressScale(
      child: Card(
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
                    if (dateBadge != null && dateBadge!.isNotEmpty)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: _Tag(
                          text: dateBadge!,
                          background: const Color(0xFFFFC800),
                          foreground: const Color(0xFF033300),
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
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MetaLine(icon: Icons.location_on, text: municipality),
                    const SizedBox(height: 2),
                    _MetaLine(icon: Icons.event, text: date),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _InfoPill(
                          label: category,
                          background: pillBg,
                          foreground: pillFg,
                        ),
                        if (showMunicipalityTag && municipality.isNotEmpty)
                          _InfoPill(
                            label: municipality,
                            icon: Icons.place_outlined,
                            background: pillBg,
                            foreground: pillFg,
                          ),
                      ],
                    ),
                    if (promotionReason != null) ...[
                      const SizedBox(height: 6),
                      PromotionReasonPill(text: promotionReason!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  const _InfoPill({
    required this.label,
    this.icon,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: foreground),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ],
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 12, color: muted),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: muted),
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
