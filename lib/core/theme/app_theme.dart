import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - Modern Professional Enterprise Palette
  static const primaryBlue = Color(0xFF1D4ED8); // Royal Blue Enterprise
  static const primaryBlueHover = Color(0xFF1E40AF); // Deeper Royal Blue
  static const lightBlueBg = Color(0xFFEFF6FF); // Soft Blue Surface (Blue-50)
  static const darkBlue = Color(0xFF1E3A8A);
  static const pureWhite = Color(0xFFFFFFFF);
  static const backgroundWhite = Color(0xFFF8FAFC); // Clean Canvas (Slate-50)
  static const surfaceWhite = Color(0xFFFFFFFF);
  static const accentBlack = Color(0xFF0F172A); // High-contrast Charcoal Typography (Slate-900)
  static const textSecondary = Color(0xFF475569); // Slate-600
  static const textMuted = Color(0xFF64748B); // Slate-500
  static const borderOutline = Color(0xFFE2E8F0); // Delicate Hairline Enterprise Border (Slate-200)
  static const subtleBorder = Color(0xFFF1F5F9); // Ultra-light Divider (Slate-100)
  static const dangerRed = Color(0xFFDC2626); // Status Red
  static const successGreen = Color(0xFF16A34A); // Status Green
  static const warningAmber = Color(0xFFD97706); // Status Amber

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.lexendTextTheme();

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        color: accentBlack,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: accentBlack,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: -0.3,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        color: accentBlack,
        fontWeight: FontWeight.w600,
        fontSize: 15,
        letterSpacing: -0.2,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: accentBlack,
        fontSize: 14.5,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: textSecondary,
        fontSize: 13.5,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        color: pureWhite,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        onPrimary: pureWhite,
        secondary: darkBlue,
        onSecondary: pureWhite,
        surface: pureWhite,
        onSurface: accentBlack,
        error: dangerRed,
        outline: borderOutline,
      ),
      scaffoldBackgroundColor: backgroundWhite,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: pureWhite,
        foregroundColor: accentBlack,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: borderOutline, width: 1.0),
        ),
        titleTextStyle: GoogleFonts.lexend(
          color: accentBlack,
          fontSize: 16.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderOutline, width: 1.0),
        ),
        color: pureWhite,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: pureWhite,
          minimumSize: const Size.fromHeight(46),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentBlack,
          backgroundColor: pureWhite,
          minimumSize: const Size.fromHeight(46),
          side: const BorderSide(color: borderOutline, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pureWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderOutline, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderOutline, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        labelStyle: GoogleFonts.lexend(color: textMuted, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: borderOutline,
        thickness: 1.0,
        space: 1,
      ),
    );
  }
}
