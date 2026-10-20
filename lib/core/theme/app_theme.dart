import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppTheme {
  // Brand Colors - Modern Professional Jade Tosca / Teal Palette
  static const jadeTosca = Color(0xFF00A896); // Main Accent: Jade Tosca
  static const jadeToscaGlow = Color(
    0x6600A896,
  ); // rgba(0, 168, 150, 0.4) for chart gradient
  static const primaryToska = jadeTosca; // Modern Toska Enterprise (Jade Tosca)
  static const primaryToskaHover = Color(0xFF0F766E); // Deeper Toska (Teal 700)
  static const lightToskaBg = Color(0x1F00A896); // Subtle Toska Tint
  static const darkToska = Color(0xFF0B4F47); // Deep Forest Toska

  // Clean Modern Light Mode Standard Palette (Requested Design)
  static const lightBackground = Color(0xFFF8FAFC); // Slate-50 canvas
  static const lightCardSurface = Color(0xFFFFFFFF); // Pure White cards
  static const lightCardSurfaceElevated = Color(
    0xFFF1F5F9,
  ); // Slate-100 hover/elevated
  static const lightCardBorder = Color(
    0xFFE2E8F0,
  ); // 1px solid Slate-200 hairline border
  static const textPrimaryLight = Color(0xFF0F172A); // Slate-900 primary text
  static const textSecondaryLight = Color(
    0xFF334155,
  ); // Slate-700 secondary text
  static const textMutedLight = Color(0xFF64748B); // Slate-500 muted text

  // Dark Mode Palette - Remapped to Clean Light Mode (100% white/light theme)
  static const darkBackground = lightBackground; // 0xFFF8FAFC
  static const darkCardSurface = lightCardSurface; // 0xFFFFFFFF
  static const darkCardSurfaceElevated = lightCardSurfaceElevated; // 0xFFF1F5F9
  static const darkCardBorder = lightCardBorder; // 0xFFE2E8F0
  static const textPrimaryDark = textPrimaryLight; // 0xFF0F172A
  static const textSecondaryDark = textSecondaryLight; // 0xFF334155
  static const textMutedDark = textMutedLight; // 0xFF64748B

  // Backward compatible aliases mapped to Clean Modern Light Mode
  static const primaryBlue = primaryToska;
  static const primaryBlueHover = primaryToskaHover;
  static const lightBlueBg = lightCardSurfaceElevated;
  static const darkBlue = darkToska;
  static const primary = primaryToska;
  static const background = lightBackground;
  static const error = dangerRed;

  static const pureWhite = Color(0xFFFFFFFF);
  static const backgroundWhite = lightBackground; // Slate-50
  static const surfaceWhite = lightCardSurface; // Pure White
  static const accentBlack = textPrimaryLight; // Slate-900
  static const textSecondary = textSecondaryLight; // Slate-700
  static const textMuted = textMutedLight; // Slate-500
  static const borderOutline = lightCardBorder; // Slate-200
  static const subtleBorder = lightCardBorder;
  static const dangerRed = Color(0xFFEF4444); // Status Red
  static const successGreen = Color(0xFF10B981); // Status Emerald
  static const warningAmber = Color(0xFFF59E0B); // Status Amber

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        color: textPrimaryLight,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: textPrimaryLight,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: -0.3,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        color: textPrimaryLight,
        fontWeight: FontWeight.w600,
        fontSize: 15,
        letterSpacing: -0.2,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        color: textPrimaryLight,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: textPrimaryLight,
        fontSize: 14.5,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: textSecondaryLight,
        fontSize: 13.5,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: textMutedLight,
        fontSize: 12,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        color: pureWhite,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        color: textMutedLight,
        fontSize: 12,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        color: textMutedLight,
        fontSize: 10,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: jadeTosca,
        onPrimary: pureWhite,
        secondary: jadeTosca,
        onSecondary: pureWhite,
        surface: lightCardSurface,
        onSurface: textPrimaryLight,
        error: dangerRed,
        outline: lightCardBorder,
      ),
      scaffoldBackgroundColor: lightBackground,
      canvasColor: lightBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: lightCardSurface,
        foregroundColor: textPrimaryLight,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(color: lightCardBorder, width: 1.0),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimaryLight,
          fontSize: 16.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: textPrimaryLight),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lightCardBorder, width: 1.0),
        ),
        color: lightCardSurface,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: jadeTosca,
          foregroundColor: pureWhite,
          minimumSize: const Size.fromHeight(46),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryLight,
          backgroundColor: lightCardSurface,
          minimumSize: const Size.fromHeight(46),
          side: const BorderSide(color: lightCardBorder, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: jadeTosca,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCardSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightCardBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightCardBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: jadeTosca, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: textMutedLight, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: textMutedLight, fontSize: 13),
        prefixIconColor: textMutedLight,
        suffixIconColor: textMutedLight,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightCardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lightCardBorder, width: 1.0),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimaryLight,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: textSecondaryLight,
          fontSize: 13.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: lightCardBorder, width: 1.0),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimaryLight,
        contentTextStyle: GoogleFonts.inter(color: pureWhite),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: lightCardBorder,
        thickness: 1.0,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightCardSurfaceElevated,
        disabledColor: lightCardSurface,
        selectedColor: jadeTosca,
        secondarySelectedColor: jadeTosca,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: textPrimaryLight),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 12, color: pureWhite),
        brightness: Brightness.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: lightCardBorder, width: 1.0),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightCardSurface,
        selectedItemColor: jadeTosca,
        unselectedItemColor: textMutedLight,
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;

  // static ThemeData get _legacyDarkTheme {
  //   final baseTextTheme = GoogleFonts.interTextTheme();

  //   final textTheme = baseTextTheme.copyWith(
  //     displayLarge: baseTextTheme.displayLarge?.copyWith(
  //       color: textPrimaryDark,
  //       fontWeight: FontWeight.w700,
  //       letterSpacing: -0.5,
  //     ),
  //     titleLarge: baseTextTheme.titleLarge?.copyWith(
  //       color: textPrimaryDark,
  //       fontWeight: FontWeight.w700,
  //       fontSize: 18,
  //       letterSpacing: -0.3,
  //     ),
  //     titleMedium: baseTextTheme.titleMedium?.copyWith(
  //       color: textPrimaryDark,
  //       fontWeight: FontWeight.w600,
  //       fontSize: 15,
  //       letterSpacing: -0.2,
  //     ),
  //     titleSmall: baseTextTheme.titleSmall?.copyWith(
  //       color: textPrimaryDark,
  //       fontWeight: FontWeight.w600,
  //       fontSize: 13,
  //     ),
  //     bodyLarge: baseTextTheme.bodyLarge?.copyWith(
  //       color: textPrimaryDark,
  //       fontSize: 14.5,
  //     ),
  //     bodyMedium: baseTextTheme.bodyMedium?.copyWith(
  //       color: textSecondaryDark,
  //       fontSize: 13.5,
  //     ),
  //     bodySmall: baseTextTheme.bodySmall?.copyWith(
  //       color: textMutedDark,
  //       fontSize: 12,
  //     ),
  //     labelLarge: baseTextTheme.labelLarge?.copyWith(
  //       color: pureWhite,
  //       fontWeight: FontWeight.w600,
  //       fontSize: 14,
  //     ),
  //     labelMedium: baseTextTheme.labelMedium?.copyWith(
  //       color: textMutedDark,
  //       fontSize: 12,
  //     ),
  //     labelSmall: baseTextTheme.labelSmall?.copyWith(
  //       color: textMutedDark,
  //       fontSize: 10,
  //     ),
  //   );

  //   return ThemeData(
  //     useMaterial3: true,
  //     brightness: Brightness.dark,
  //     colorScheme: const ColorScheme.dark(
  //       primary: jadeTosca,
  //       onPrimary: pureWhite,
  //       secondary: jadeTosca,
  //       onSecondary: pureWhite,
  //       surface: darkCardSurface,
  //       onSurface: textPrimaryDark,
  //       error: dangerRed,
  //       outline: darkCardBorder,
  //     ),
  //     scaffoldBackgroundColor: darkBackground,
  //     canvasColor: darkBackground,
  //     textTheme: textTheme,
  //     appBarTheme: AppBarTheme(
  //       backgroundColor: darkBackground,
  //       foregroundColor: textPrimaryDark,
  //       elevation: 0,
  //       centerTitle: false,
  //       scrolledUnderElevation: 0,
  //       surfaceTintColor: Colors.transparent,
  //       shape: const Border(
  //         bottom: BorderSide(color: darkCardBorder, width: 1.0),
  //       ),
  //       titleTextStyle: GoogleFonts.inter(
  //         color: textPrimaryDark,
  //         fontSize: 16.5,
  //         fontWeight: FontWeight.w700,
  //         letterSpacing: -0.2,
  //       ),
  //       iconTheme: const IconThemeData(color: textPrimaryDark),
  //     ),
  //     cardTheme: CardThemeData(
  //       elevation: 0,
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(12),
  //         side: const BorderSide(color: darkCardBorder, width: 1.0),
  //       ),
  //       color: darkCardSurface,
  //       margin: EdgeInsets.zero,
  //     ),
  //     elevatedButtonTheme: ElevatedButtonThemeData(
  //       style: ElevatedButton.styleFrom(
  //         backgroundColor: jadeTosca,
  //         foregroundColor: pureWhite,
  //         minimumSize: const Size.fromHeight(46),
  //         elevation: 0,
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //         textStyle: GoogleFonts.inter(
  //           fontSize: 14,
  //           fontWeight: FontWeight.w600,
  //           letterSpacing: 0.1,
  //         ),
  //       ),
  //     ),
  //     outlinedButtonTheme: OutlinedButtonThemeData(
  //       style: OutlinedButton.styleFrom(
  //         foregroundColor: textPrimaryDark,
  //         backgroundColor: darkCardSurface,
  //         minimumSize: const Size.fromHeight(46),
  //         side: const BorderSide(color: darkCardBorder, width: 1.0),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //         textStyle: GoogleFonts.inter(
  //           fontSize: 14,
  //           fontWeight: FontWeight.w600,
  //         ),
  //       ),
  //     ),
  //     textButtonTheme: TextButtonThemeData(
  //       style: TextButton.styleFrom(
  //         foregroundColor: jadeTosca,
  //         textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
  //       ),
  //     ),
  //     inputDecorationTheme: InputDecorationTheme(
  //       filled: true,
  //       fillColor: darkCardSurface,
  //       contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  //       border: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(10),
  //         borderSide: const BorderSide(color: darkCardBorder, width: 1.0),
  //       ),
  //       enabledBorder: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(10),
  //         borderSide: const BorderSide(color: darkCardBorder, width: 1.0),
  //       ),
  //       focusedBorder: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(10),
  //         borderSide: const BorderSide(color: jadeTosca, width: 1.5),
  //       ),
  //       labelStyle: GoogleFonts.inter(color: textMutedDark, fontSize: 13),
  //       hintStyle: GoogleFonts.inter(color: textMutedDark, fontSize: 13),
  //     ),
  //     dialogTheme: DialogThemeData(
  //       backgroundColor: darkCardSurface,
  //       surfaceTintColor: Colors.transparent,
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(14),
  //         side: const BorderSide(color: darkCardBorder, width: 1.0),
  //       ),
  //       titleTextStyle: GoogleFonts.inter(
  //         color: textPrimaryDark,
  //         fontSize: 17,
  //         fontWeight: FontWeight.w700,
  //       ),
  //       contentTextStyle: GoogleFonts.inter(
  //         color: textSecondaryDark,
  //         fontSize: 13.5,
  //       ),
  //     ),
  //     bottomSheetTheme: const BottomSheetThemeData(
  //       backgroundColor: darkCardSurface,
  //       surfaceTintColor: Colors.transparent,
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  //         side: BorderSide(color: darkCardBorder, width: 1.0),
  //       ),
  //     ),
  //     snackBarTheme: SnackBarThemeData(
  //       backgroundColor: darkCardSurfaceElevated,
  //       contentTextStyle: GoogleFonts.inter(color: textPrimaryDark),
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(10),
  //         side: const BorderSide(color: darkCardBorder, width: 1.0),
  //       ),
  //       behavior: SnackBarBehavior.floating,
  //     ),
  //     dividerTheme: const DividerThemeData(
  //       color: darkCardBorder,
  //       thickness: 1.0,
  //       space: 1,
  //     ),
  //     chipTheme: ChipThemeData(
  //       backgroundColor: darkCardSurfaceElevated,
  //       disabledColor: darkCardSurface,
  //       selectedColor: jadeTosca.withValues(alpha: 0.25),
  //       secondarySelectedColor: jadeTosca,
  //       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  //       labelStyle: GoogleFonts.inter(fontSize: 12, color: textPrimaryDark),
  //       secondaryLabelStyle: GoogleFonts.inter(fontSize: 12, color: textPrimaryDark),
  //       brightness: Brightness.dark,
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(8),
  //         side: const BorderSide(color: darkCardBorder, width: 1.0),
  //       ),
  //     ),
  //     bottomNavigationBarTheme: const BottomNavigationBarThemeData(
  //       backgroundColor: darkCardSurface,
  //       selectedItemColor: jadeTosca,
  //       unselectedItemColor: textMutedDark,
  //     ),
  //   );
  // }

  static ShadThemeData get shadcnThemeLight => ShadThemeData(
    brightness: Brightness.light,
    colorScheme: const ShadZincColorScheme.light(
      primary: jadeTosca,
      destructive: dangerRed,
    ),
    radius: const BorderRadius.all(Radius.circular(8)),
    textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.inter),
  );

  static ShadThemeData get shadcnThemeDark => shadcnThemeLight;
}
