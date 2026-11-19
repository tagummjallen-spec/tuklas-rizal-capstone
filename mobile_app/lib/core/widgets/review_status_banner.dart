import 'package:flutter/material.dart';

/// Inline banner that explains why reviews are (or are not) available.
class ReviewStatusBanner extends StatelessWidget {
  final String message;
  final bool positive;

  const ReviewStatusBanner({
    super.key,
    required this.message,
    this.positive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = positive ? const Color(0xFFE8F0E5) : const Color(0xFFFFF4E0);
    final fg = positive ? const Color(0xFF1B4D1B) : const Color(0xFF7A5300);
    final icon = positive ? Icons.verified_user : Icons.lock_clock;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
