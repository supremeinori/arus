import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - Strict Minimalist Palette: Biru & Putih dengan Aksen Hitam Garis Tegas
  static const primaryBlue = Color(0xFF1D4ED8); // Royal Blue Tajam
  static const darkBlue = Color(0xFF1E3A8A);
  static const pureWhite = Color(0xFFFFFFFF);
  static const backgroundWhite = Color(0xFFF8FAFC);
  static const accentBlack = Color(0xFF0F172A); // Hitam Pekat Tegas
  static const borderOutline = Color(0xFF0F172A); // Garis Outline Tegas 1.5px
  static const subtleBorder = Color(0xFFE2E8F0); // Garis Tipis Bersih
  static const dangerRed = Color(0xFFDC2626); // Merah Status
  static const successGreen = Color(0xFF16A34A); // Hijau Status

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
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: accentBlack,
        fontSize: 14.5,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: const Color(0xFF334155),
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
        secondary: accentBlack,
        onSecondary: pureWhite,
        surface: pureWhite,
        onSurface: accentBlack,
        error: Color(0xFFDC2626),
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
          bottom: BorderSide(color: borderOutline, width: 1.5),
        ),
        titleTextStyle: GoogleFonts.lexend(
          color: accentBlack,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: borderOutline, width: 1.5),
        ),
        color: pureWhite,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: pureWhite,
          minimumSize: const Size.fromHeight(46),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: borderOutline, width: 1.5),
          ),
          textStyle: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentBlack,
          backgroundColor: pureWhite,
          minimumSize: const Size.fromHeight(46),
          side: const BorderSide(color: borderOutline, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
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
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderOutline, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderOutline, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        labelStyle: GoogleFonts.lexend(color: const Color(0xFF64748B), fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: borderOutline,
        thickness: 1.2,
        space: 1,
      ),
    );
  }
}
