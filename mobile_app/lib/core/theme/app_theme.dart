import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TuklasRizal branding — Provincial Forest Green & Gold aesthetic.
///
/// Form I rules applied:
/// - No "RZL" acronym anywhere.
/// - LGU title "Tourism Coordinator" (not generic "Admin").
class AppTheme {
  // Provincial brand colors (from Web-Admin_2.html prototype).
  static const Color provincialGreen = Color(0xFF033300);
  static const Color provincialGold = Color(0xFFFFC800);

  static const Color surfaceLight = Color(0xFFF7F6F2);
  static const Color surfaceCard = Colors.white;
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color accentGoldLight = Color(0xFFFFE37A);
  static const Color outlineColor = Color(0xFFE5E5E5);

  /// [highContrast] strengthens text and outline contrast for the Settings
  /// accessibility toggle (pure black text, darker borders, white surfaces).
  static ThemeData lightTheme({bool highContrast = false}) {
    final bodyColor = highContrast ? Colors.black : textPrimary;
    final mutedColor = highContrast ? const Color(0xFF2B2B2B) : textSecondary;
    final borderColor = highContrast ? const Color(0xFF1B1B1B) : outlineColor;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: highContrast ? Colors.white : surfaceLight,
      colorScheme: ColorScheme.light(
        primary: provincialGreen,
        secondary: provincialGold,
        surface: surfaceCard,
        onPrimary: Colors.white,
        onSecondary: provincialGreen,
        onSurface: bodyColor,
        outline: borderColor,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: provincialGreen,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: provincialGreen,
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: bodyColor,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: mutedColor,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: bodyColor,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: provincialGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: provincialGreen,
          side: const BorderSide(color: provincialGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: provincialGreen, width: 2),
        ),
        labelStyle: TextStyle(color: mutedColor),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: highContrast ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: highContrast
              ? const BorderSide(color: Color(0xFF1B1B1B))
              : BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: provincialGreen,
        unselectedItemColor: textSecondary,
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}
