import 'package:flutter/material.dart';

import '../utils/tourism_images.dart';
import 'app_motion.dart';
import 'promotion_reason_pill.dart';

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

  /// Interest-based boost: shows the "Recommended for You" badge.
  final bool isRecommended;

  /// Compact transport hint (e.g. "Commute guide") shown beside the category.
  final String? commuteBadge;

  /// Explainable reason for a promotion / interest match.
  final String? promotionReason;
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
    this.isRecommended = false,
    this.commuteBadge,
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
                    if (isRecommended)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF033300),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'Recommended for You',
                            style: TextStyle(
                              color: Color(0xFFFFC800),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
                              child: AnimatedBookmarkIcon(
                                isSaved: isSaved,
                                size: 18,
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
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_city,
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            municipality,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Pill(
                          label: category,
                          background: pillBg,
                          foreground: pillFg,
                        ),
                        if (commuteBadge != null && commuteBadge!.isNotEmpty)
                          _Pill(
                            label: commuteBadge!,
                            icon: Icons.directions_bus,
                            background: isDark
                                ? const Color(0xFF2A2411)
                                : const Color(0xFFFFF4CC),
                            foreground: isDark
                                ? const Color(0xFFFFD65C)
                                : const Color(0xFF7A5A00),
                          ),
                      ],
                    ),
                    if (promotionReason != null) ...[
                      const SizedBox(height: 8),
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

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  const _Pill({
    required this.label,
    this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
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
