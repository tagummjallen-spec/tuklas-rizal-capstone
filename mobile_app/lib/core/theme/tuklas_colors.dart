import 'package:flutter/material.dart';

/// Theme-aware colours for the two TuklasRizal appearances.
///
/// Widgets must never hardcode `Colors.white` or `Color(0xFF033300)` for a
/// surface or body text: in Dark Mode that produced white cards and dark-green
/// text on a near-black scaffold. These getters resolve to the light palette in
/// Light Mode and to the deep slate/emerald palette in Dark Mode.
extension TuklasColors on BuildContext {
  bool get tuklasIsDark => Theme.of(this).brightness == Brightness.dark;

  ColorScheme get tuklasScheme => Theme.of(this).colorScheme;

  /// Card / panel / sheet surface: white in light mode, deep slate in dark.
  Color get tuklasSurface =>
      tuklasIsDark ? const Color(0xFF1A2420) : Colors.white;

  /// Slightly recessed surface: cream in light mode, darker slate in dark.
  Color get tuklasSurfaceAlt =>
      tuklasIsDark ? const Color(0xFF141D19) : const Color(0xFFF7F6F2);

  /// Primary body text: charcoal in light mode, near-white in dark.
  Color get tuklasInk =>
      tuklasIsDark ? const Color(0xFFE8EFEA) : const Color(0xFF1B1B1B);

  /// Brand-green text that still reads on both appearances (bright emerald in
  /// dark mode instead of the near-black forest green).
  Color get tuklasForestInk =>
      tuklasIsDark ? const Color(0xFF8EE6A9) : const Color(0xFF033300);

  /// Secondary / supporting copy.
  Color get tuklasMuted =>
      tuklasIsDark ? const Color(0xFFA7B7AD) : const Color(0xFF6B6B6B);

  /// Hairline borders and dividers.
  Color get tuklasHairline =>
      tuklasIsDark ? const Color(0xFF3A4A42) : const Color(0xFFE5E5E5);

  /// Warm gold accent used for chips, badges and highlights.
  Color get tuklasGold => const Color(0xFFFFC800);

  /// Soft tinted fill for icon chips and small badges.
  Color get tuklasGoldTint =>
      tuklasIsDark ? const Color(0x33FFC800) : const Color(0x1AFFC800);

  /// Bodiless shadow used under cards in both appearances.
  Color get tuklasShadow =>
      Colors.black.withValues(alpha: tuklasIsDark ? 0.28 : 0.06);
}
