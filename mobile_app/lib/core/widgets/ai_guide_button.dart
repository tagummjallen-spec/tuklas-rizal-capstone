import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Prominent gold entry point to the live AI Tour Guide from Home / Explore.
class AiGuideButton extends StatelessWidget {
  const AiGuideButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: const Color(0xFFFFC800),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.go('/assistant'),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: Color(0xFF033300),
                ),
                SizedBox(width: 5),
                Text(
                  'AI Guide',
                  style: TextStyle(
                    color: Color(0xFF033300),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
