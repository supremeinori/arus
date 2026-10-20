import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import 'widgets/currency_settings_section.dart';

/// Layar pengaturan kurs (mata uang tampilan + kalkulator konversi).
///
/// Terpisah dari pengaturan waktu agar tiap domain punya layar sendiri.
class CurrencySettingsScreen extends StatelessWidget {
  const CurrencySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          'Pengaturan Kurs',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: CurrencySettingsSection(),
      ),
    );
  }
}
