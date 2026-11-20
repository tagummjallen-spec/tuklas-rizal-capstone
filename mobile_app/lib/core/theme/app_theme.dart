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

  // Deep slate/emerald palette used by the Dark appearance.
  static const Color darkScaffold = Color(0xFF0E1512);
  static const Color darkSurface = Color(0xFF1A2420);
  static const Color darkSurfaceAlt = Color(0xFF141D19);
  static const Color darkTextPrimary = Color(0xFFE8EFEA);
  static const Color darkTextSecondary = Color(0xFFA7B7AD);
  static const Color darkOutline = Color(0xFF3A4A42);
  static const Color darkEmerald = Color(0xFF5FD08A);
  static const Color darkEmeraldInk = Color(0xFF06210F);

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
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: provincialGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

  /// Deep slate + emerald Dark appearance with warm-gold accents.
  ///
  /// Every surface is dark, text is near-white, and interactive accents use a
  /// bright emerald or brand gold so cards, forms and the bottom navigation bar
  /// keep accessible contrast.
  static ThemeData darkTheme({bool highContrast = false}) {
    final bodyColor = highContrast ? Colors.white : darkTextPrimary;
    final mutedColor = highContrast ? const Color(0xFFD7E2DB) : darkTextSecondary;
    final borderColor = highContrast ? Colors.white : darkOutline;
    final cardColor = highContrast ? Colors.black : darkSurface;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: highContrast ? Colors.black : darkScaffold,
      colorScheme: ColorScheme.dark(
        primary: darkEmerald,
        secondary: provincialGold,
        surface: cardColor,
        onPrimary: darkEmeraldInk,
        onSecondary: provincialGreen,
        onSurface: bodyColor,
        onSurfaceVariant: mutedColor,
        outline: borderColor,
        error: const Color(0xFFFFB4AB),
        onError: const Color(0xFF690005),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: darkEmerald,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: bodyColor,
          ),
          headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: darkEmerald,
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: bodyColor,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: bodyColor,
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
          backgroundColor: darkEmerald,
          foregroundColor: darkEmeraldInk,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkEmerald,
          foregroundColor: darkEmeraldInk,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkEmerald,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: highContrast ? Colors.black : darkSurfaceAlt,
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
          borderSide: const BorderSide(color: darkEmerald, width: 2),
        ),
        labelStyle: TextStyle(color: mutedColor),
        hintStyle: TextStyle(color: mutedColor),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: highContrast ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: highContrast
              ? BorderSide(color: borderColor)
              : BorderSide(color: borderColor.withValues(alpha: 0.45)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      dividerTheme: DividerThemeData(color: borderColor.withValues(alpha: 0.5)),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: provincialGold,
        unselectedItemColor: mutedColor,
        backgroundColor: highContrast ? Colors.black : darkSurfaceAlt,
        elevation: 8,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cardColor,
        foregroundColor: bodyColor,
        elevation: 0,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1F2B25),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}
