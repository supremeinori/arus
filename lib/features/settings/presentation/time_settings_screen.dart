import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import 'widgets/time_settings_section.dart';

/// Layar pengaturan waktu (zona waktu operasional + pratinjau jam).
///
/// Terpisah dari pengaturan kurs agar tiap domain punya layar sendiri.
class TimeSettingsScreen extends StatelessWidget {
  const TimeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          'Pengaturan Waktu',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: TimeSettingsSection(),
      ),
    );
  }
}
