import 'package:flutter/material.dart';

/// Transparent, non-judgemental pill that explains why a card was promoted.
///
/// Used by the Rule-Based "Promote Towns and Events" feed so interest matches
/// and fair-promotion boosts are visible to the resident, not hidden in a score.
class PromotionReasonPill extends StatelessWidget {
  final String text;

  const PromotionReasonPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark
        ? const Color(0xFF9FE7B5)
        : const Color(0xFF033300);
    final background = isDark
        ? const Color(0xFF24352C)
        : const Color(0xFFE8F0E5);
    final border = isDark
        ? const Color(0xFF5FD08A).withValues(alpha: 0.35)
        : const Color(0xFF033300).withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 11, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
