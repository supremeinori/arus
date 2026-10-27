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
  // Tepi kartu default: Slate-300 (1,48:1) supaya batas kartu terbaca di
  // atas putih. Slate-200 (1,23:1) terlalu samar untuk daftar panjang.
  // Nama 'lightCardBorderStrong' dipertahankan untuk kompatibilitas mundur.
  static const lightCardBorder = Color(0xFFCBD5E1); // Slate-300, 1,48:1
  static const lightCardBorderStrong = Color(0xFFCBD5E1); // alias, Slate-300
  static const textPrimaryLight = Color(0xFF0F172A); // Slate-900 primary text
  static const textSecondaryLight = Color(
    0xFF334155,
  ); // Slate-700 secondary text
  static const textMutedLight = Color(0xFF64748B); // Slate-500 muted text

  // Dark Mode Palette - Remapped to Clean Light Mode (100% white/light theme)
  static const darkBackground = lightBackground; // 0xFFF8FAFC
  static const darkCardSurface = lightCardSurface; // 0xFFFFFFFF
  static const darkCardSurfaceElevated = lightCardSurfaceElevated; // 0xFFF1F5F9
  static const darkCardBorder = lightCardBorder; // 0xFFCBD5E1 Slate-300
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
  static const borderOutline = lightCardBorder; // Slate-300
  static const subtleBorder = lightCardBorder;
  static const dangerRed = Color(0xFFEF4444); // Status Red
  static const successGreen = Color(0xFF10B981); // Status Emerald
  static const warningAmber = Color(0xFFF59E0B); // Status Amber

  // Skala radius (revisi 23 Okt 2026). Sebelumnya ada 11 nilai radius berbeda
  // (1, 2, 3, 4, 6, 8, 10, 12, 14, 16, 20) sehingga sudut kartu terlihat tidak
  // satu keluarga. Skala ini diturunkan dari nilai yang memang sudah dominan di
  // kode supaya tidak ada tata letak yang bergeser.
  static const radiusXs = 6.0; // label kecil, penanda
  static const radiusSm = 8.0; // chip, tombol ikon
  static const radiusMd = 10.0; // tombol, kolom isian
  static const radiusLg = 12.0; // kartu, dialog
  static const radiusXl = 16.0; // kartu utama, lembar bawah
  static const radiusFull = 999.0; // pil

  // Garis rambut standar pengganti angka 1.0 yang tersebar.
  static const hairline = 1.0;

  // Bayangan. Dipakai supaya container terasa terangkat tanpa mengandalkan
  // elevation Material yang mengaburkan garis tepi.
  static const shadowSoft = Color(0x140F172A); // ink 8%
  static const shadowTosca = Color(0x3300A896); // tosca 20%

  // Batas bawah ukuran huruf. Apple menetapkan minimum 11pt untuk iOS dan
  // teks di bawah itu tidak layak pakai, lebih-lebih pada #64748B.
  static const textMinSize = 11.0;

  // Rampa semantik (revisi 23 Okt 2026). Sebelumnya tiap layar memilih alpha
  // sendiri sehingga ada lima tingkat merah, tiga tingkat hijau, dan dua tingkat
  // tosca untuk arti yang sama. Nilai di bawah diambil dari yang paling dominan
  // di kode supaya pergeseran tampilannya nol atau tidak terasa.
  static const dangerRedStrong = Color(0xFFDC2626); // teks merah, 4,83:1 di putih
  static const dangerTintSoft = Color(0x1AEF4444); // latar lembut
  static const dangerTint = Color(0x22EF4444); // latar, paling banyak dipakai
  static const dangerTintStrong = Color(0x33EF4444); // latar penekanan

  static const successGreenStrong = Color(0xFF16A34A); // teks hijau
  static const successTintSoft = Color(0x1A10B981);
  static const successTint = Color(0x2210B981);
  static const successTintStrong = Color(0x3310B981);

  static const warningAmberStrong = Color(0xFFD97706); // teks amber
  static const warningTintSoft = Color(0x1AF59E0B);
  static const warningTint = Color(0x22F59E0B);
  static const warningTintStrong = Color(0x33F59E0B);

  static const borderStrong = Color(0xFF94A3B8); // tepi lebih tegas
  static const borderMid = Color(0xFFCBD5E1); // tepi tengah
  static const textSecondaryMid = Color(0xFF475569); // nada tengah
  static const infoBlue = Color(0xFF0284C7); // garis proyeksi pada grafik
  static const toscaTintStrong = Color(0x4000A896); // tosca 25%
  static const scrim = Color(0x33000000); // lapis gelap di atas konten

  // Rampa permukaan opaque. Tint di atas tembus pandang, jadi tidak bisa dipakai
  // sebagai latar badge yang menumpuk di atas permukaan lain. Warna di bawah ini
  // menggantikan hex yang sebelumnya ditulis ulang di banyak layar.
  static const dangerSurfacePale = Color(0xFFFEF2F2); // rose-50
  static const dangerSurface = Color(0xFFFEE2E2); // rose-100
  static const dangerRedDeep = Color(0xFFB91C1C); // red-700
  static const dangerRedLight = Color(0xFFFCA5A5); // red-300, tepi lembut

  static const successSurfacePale = Color(0xFFF0FDF4); // green-50
  static const successSurface = Color(0xFFDCFCE7); // green-100
  static const successSurfaceStrong = Color(0xFFBBF7D0); // green-200
  static const successGreenMid = Color(0xFF059669); // emerald-600
  static const successGreenDeep = Color(0xFF15803D); // green-700, 4,8:1 di putih
  static const successGreenDeepest = Color(0xFF14532D); // green-900, teks di latar hijau muda
  static const successGreenLight = Color(0xFF34D399); // emerald-400, ikon di latar gelap

  static const warningAmberSurface = Color(0xFFFEF3C7); // amber-100
  static const warningAmberSurfaceStrong = Color(0xFFFFEDD5); // orange-100
  static const warningAmberMid = Color(0xFFB45309); // amber-700
  static const warningAmberDeep = Color(0xFFC2410C); // orange-700
  static const warningAmberLight = Color(0xFFFBBF24); // amber-400

  static const toscaSurfacePale = Color(0xFFF0FDFA); // teal-50
  static const toscaSurface = Color(0xFFE6F6F4); // tosca-50
  static const toscaSurfaceStrong = Color(0xFFCCFBF1); // teal-100

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
        fontSize: textMinSize,
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
        // Tema menyetel false padahal seluruh 31 layar memaksa true, jadi nilai
        // tema ini sebelumnya mati. Disamakan ke true dan pengulangan per layar
        // dihapus supaya tidak ada dua sumber kebenaran.
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(color: lightCardBorder, width: hairline),
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
        elevation: 1,
        shadowColor: shadowSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: lightCardBorder, width: hairline),
        ),
        color: lightCardSurface,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: jadeTosca,
          foregroundColor: pureWhite,
          // Tanpa iconColor, ikon tetap putih mentah saat tombol dinonaktifkan,
          // jadi label ikut kelabu sementara ikonnya masih menyala.
          iconColor: pureWhite,
          disabledBackgroundColor: lightCardSurfaceElevated,
          disabledForegroundColor: textMutedLight,
          disabledIconColor: textMutedLight,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          elevation: 2,
          shadowColor: shadowTosca,
          surfaceTintColor: Colors.transparent,
          overlayColor: darkToska,
          animationDuration: const Duration(milliseconds: 120),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // Tombol sekunder sekarang tosca, bukan putih bertepi abu-abu.
          // Teks #0F766E di atas latar #F0FDFA berkontras 5,25:1, lolos ambang
          // 4,5:1 untuk teks di bawah 18 pt.
          foregroundColor: primaryToskaHover,
          iconColor: primaryToskaHover,
          backgroundColor: toscaSurfacePale,
          disabledBackgroundColor: lightCardSurfaceElevated,
          disabledForegroundColor: textMutedLight,
          disabledIconColor: textMutedLight,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          overlayColor: lightToskaBg,
          elevation: 0,
          animationDuration: const Duration(milliseconds: 120),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ).copyWith(
          // Tepi tosca 45 persen. Yang 25 persen tadinya nyaris tidak terbaca
          // sebagai tepi di atas putih, hanya 1,25:1. Yang 45 persen menjadi
          // sekitar 1,5:1, cukup untuk menandai batas tombol tanpa jadi garis tegas.
          // Sekaligus dipisah per state. styleFrom menempelkan satu sisi ke semua
          // state, jadi tanpa ini tombol sekunder yang mati tetap bertepi tosca.
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(color: lightCardBorder, width: hairline);
            }
            return BorderSide(
              color: jadeTosca.withValues(alpha: 0.45),
              width: hairline,
            );
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // Tombol teks juga tosca tua. #00A896 di atas putih hanya 2,98:1,
          // gagal ambang 4,5:1 untuk teks 14,5 pt. #0F766E di atas putih 5,25:1.
          foregroundColor: primaryToskaHover,
          iconColor: primaryToskaHover,
          disabledForegroundColor: textMutedLight,
          disabledIconColor: textMutedLight,
          overlayColor: lightToskaBg,
          // Tinggi 40 supaya tombol teks tidak lebih pendek dari tombol utama
          // saat keduanya berpasangan di actions dialog.
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          animationDuration: const Duration(milliseconds: 120),
          shape: RoundedRectangleBorder(
            // Dulu radiusSm, jadi pasangan Batal dan Simpan di dialog punya
            // sudut berbeda. Sekarang ikut radius tombol lain.
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Bawaan Material untuk FilledButton adalah radius 20 dan tinggi 40,
      // jadi empat tombol di layar integritas tampil seperti kapsul di antara
      // tombol radius 12 lainnya.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: jadeTosca,
          foregroundColor: pureWhite,
          iconColor: pureWhite,
          disabledBackgroundColor: lightCardSurfaceElevated,
          disabledForegroundColor: textMutedLight,
          disabledIconColor: textMutedLight,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          elevation: 2,
          shadowColor: shadowTosca,
          surfaceTintColor: Colors.transparent,
          overlayColor: darkToska,
          animationDuration: const Duration(milliseconds: 120),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      // 50 IconButton di aplikasi ini memakai warna bawaan Material yang lebih
      // pudar dari teks di sekitarnya.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textSecondaryLight,
          highlightColor: lightToskaBg,
          hoverColor: lightToskaBg,
          focusColor: lightToskaBg,
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCardSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: lightCardBorder, width: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: lightCardBorder, width: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: jadeTosca, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: dangerRed, width: hairline),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondaryLight, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: textMutedLight, fontSize: 13),
        errorStyle: GoogleFonts.inter(color: dangerRed, fontSize: 11.5),
        prefixIconColor: textMutedLight,
        suffixIconColor: textMutedLight,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightCardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: lightCardBorder, width: hairline),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimaryLight,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: textSecondaryLight,
          fontSize: 13.5,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
          side: BorderSide(color: lightCardBorder, width: hairline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimaryLight,
        contentTextStyle: GoogleFonts.inter(
          color: pureWhite,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: jadeTosca,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
      ),
      dividerTheme: const DividerThemeData(
        color: lightCardBorder,
        thickness: hairline,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightCardSurfaceElevated,
        disabledColor: lightCardSurface,
        selectedColor: jadeTosca,
        secondarySelectedColor: jadeTosca,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        labelStyle: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: textSecondaryLight,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: pureWhite,
        ),
        checkmarkColor: pureWhite,
        brightness: Brightness.light,
        side: const BorderSide(color: lightCardBorder, width: hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondaryLight,
        textColor: textPrimaryLight,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: textMutedLight,
          height: 1.35,
        ),
      ),
      switchTheme: SwitchThemeData(
        // Thumb putih butuh track gelap saat mati, kalau tidak keduanya tenggelam
        // di kartu putih.
        thumbColor: const WidgetStatePropertyAll(pureWhite),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? jadeTosca
              : AppTheme.borderMid,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? jadeTosca
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(pureWhite),
        side: const BorderSide(color: textMutedLight, width: 1.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXs),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? jadeTosca
              : textMutedLight,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: jadeTosca,
        linearTrackColor: lightCardSurfaceElevated,
        circularTrackColor: lightCardSurfaceElevated,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightCardSurface,
        selectedItemColor: jadeTosca,
        unselectedItemColor: textMutedLight,
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;

  // Tema shadcn. Ini titik paling berpengaruh untuk container dan tombol,
  // sebab seluruh kartu dan tombol aplikasi memakai ShadCard dan ShadButton,
  // bukan Card dan ElevatedButton milik Material. Yang diubah di bawah hanya
  // bentuk, warna, sudut, bayangan, dan tinggi. Tidak ada susunan yang dipindah.
  static ShadThemeData get shadcnThemeLight => ShadThemeData(
    brightness: Brightness.light,
    colorScheme: const ShadZincColorScheme.light(
      primary: jadeTosca,
      destructive: dangerRed,
    ),
    radius: BorderRadius.all(Radius.circular(radiusLg)),
    textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.inter),

    // Container kartu: sudut 12, garis rambut, satu bayangan tipis supaya kartu
    // terbaca terangkat tanpa tepi yang mengabur.
    cardTheme: ShadCardTheme(
      backgroundColor: lightCardSurface,
      radius: BorderRadius.all(Radius.circular(radiusLg)),
      border: ShadBorder.all(
        color: lightCardBorder,
        width: hairline,
        radius: BorderRadius.all(Radius.circular(radiusLg)),
      ),
      shadows: [
        BoxShadow(color: shadowSoft, blurRadius: 14, offset: const Offset(0, 3)),
      ],
    ),

    // Tinggi tombol. Bawaan shadcn hanya 40 untuk ukuran regular, di bawah
    // minimum 44 sehingga kurang nyaman disentuh. Dinaikkan dan dirapikan
    // sehingga tiap ukuran punya proporsi yang jelas.
    buttonSizesTheme: ShadButtonSizesTheme(
      regular: ShadButtonSizeTheme(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      sm: ShadButtonSizeTheme(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      lg: ShadButtonSizeTheme(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
      ),
      icon: ShadButtonSizeTheme(
        height: 44,
        padding: EdgeInsets.zero,
        width: 44,
      ),
    ),

    // Tombol utama: tosca padat dengan satu lapis pendar tipis supaya terasa
    // bisa ditekan, dan keadaan tertekan yang jelas.
    primaryButtonTheme: ShadButtonTheme(
      backgroundColor: jadeTosca,
      hoverBackgroundColor: primaryToskaHover,
      pressedBackgroundColor: primaryToskaHover,
      foregroundColor: pureWhite,
      hoverForegroundColor: pureWhite,
      pressedForegroundColor: pureWhite,
      textStyle: GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      shadows: [
        BoxShadow(color: shadowTosca, blurRadius: 16, offset: const Offset(0, 5)),
      ],
    ),

    // Tombol garis: permukaan putih, tepi rambut, dan isapan tosca tipis saat
    // disentuh sehingga terbaca hidup tanpa berteriak.
    outlineButtonTheme: ShadButtonTheme(
      backgroundColor: lightCardSurface,
      hoverBackgroundColor: lightToskaBg,
      pressedBackgroundColor: lightToskaBg,
      foregroundColor: textPrimaryLight,
      hoverForegroundColor: textPrimaryLight,
      pressedForegroundColor: textPrimaryLight,
      textStyle: GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: ShadDecoration(
        border: ShadBorder.all(
          color: lightCardBorder,
          width: hairline,
          radius: BorderRadius.all(Radius.circular(radiusLg)),
        ),
      ),
    ),

    ghostButtonTheme: ShadButtonTheme(
      backgroundColor: Colors.transparent,
      hoverBackgroundColor: lightToskaBg,
      pressedBackgroundColor: lightToskaBg,
      foregroundColor: textSecondaryLight,
      hoverForegroundColor: jadeTosca,
      pressedForegroundColor: jadeTosca,
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),

    destructiveButtonTheme: ShadButtonTheme(
      backgroundColor: dangerRed,
      hoverBackgroundColor: dangerRedStrong,
      pressedBackgroundColor: dangerRedStrong,
      foregroundColor: pureWhite,
      hoverForegroundColor: pureWhite,
      pressedForegroundColor: pureWhite,
      textStyle: GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  static ShadThemeData get shadcnThemeDark => shadcnThemeLight;
}
