import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(
            height: 1.0,
            thickness: 1.0,
            color: AppTheme.darkCardBorder,
          ),
        ),
        title: Text(
          'Tentang Aplikasi ARUS',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16.5,
            color: AppTheme.textPrimaryDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.jadeTosca,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'ARUS',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ARUS Business DSS & POS',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimaryDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Versi 1.0.0 (Final Enterprise Baseline)',
                  style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textMutedDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          ShadCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deskripsi Sistem',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'ARUS adalah Mobile Business Decision-Support System terintegrasi Point-of-Sale (POS) untuk bisnis ritel dan F&B multi-cabang. Sistem ini mengalirkan data transaksi harian menjadi visualisasi analitik KPI, rekomendasi stok otomatis, dan konsultasi cerdas berbasis AI.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondaryDark, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const ShadCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teknologi yang Digunakan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 10),
                _TechRow(label: 'Frontend', value: 'Flutter 3.x, Riverpod 2.x, shadcn_ui, go_router, Google Fonts (Inter)'),
                _TechRow(label: 'Backend', value: 'Node.js, Express, TypeScript, Prisma ORM, Argon2, Pino'),
                _TechRow(label: 'Database', value: 'PostgreSQL 15+ dengan in-memory fallback offline'),
                _TechRow(label: 'Keamanan', value: 'SHA-256 Tamper-evident Ledger, JWT Access & Rotating Refresh'),
                _TechRow(label: 'Decision Support', value: 'AI Assistant (Gemini/LLM) + Rule Engine (8 Rules)'),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              '© 2026 ARUS System • Hak Cipta Dilindungi',
              style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMutedDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    if (ShadTheme.maybeOf(context) == null) {
      return ShadTheme(
        data: AppTheme.shadcnThemeLight,
        child: scaffold,
      );
    }
    return scaffold;
  }
}

/// Baris teknologi — widget class top-level const
class _TechRow extends StatelessWidget {
  final String label;
  final String value;

  const _TechRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textMutedDark),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textPrimaryDark),
            ),
          ),
        ],
      ),
    );
  }
}
