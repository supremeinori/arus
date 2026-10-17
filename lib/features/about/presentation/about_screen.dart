import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Tentang Aplikasi ARUS',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'ARUS',
                    style: GoogleFonts.lexend(
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
                  style: GoogleFonts.lexend(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.accentBlack),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Versi 1.0.0 (Final Enterprise Baseline)',
                  style: GoogleFonts.lexend(fontSize: 12.5, color: const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderOutline, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deskripsi Sistem',
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accentBlack),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'ARUS adalah Mobile Business Decision-Support System terintegrasi Point-of-Sale (POS) untuk bisnis ritel dan F&B multi-cabang. Sistem ini mengalirkan data transaksi harian menjadi visualisasi analitik KPI, rekomendasi stok otomatis, dan konsultasi cerdas berbasis AI.',
                  style: GoogleFonts.lexend(fontSize: 13, color: const Color(0xFF334155), height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderOutline, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teknologi yang Digunakan',
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accentBlack),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                const _TechRow(label: 'Frontend', value: 'Flutter 3.x, Riverpod 2.x, go_router, Google Fonts (Lexend)'),
                const _TechRow(label: 'Backend', value: 'Node.js, Express, TypeScript, Prisma ORM, Argon2, Pino'),
                const _TechRow(label: 'Database', value: 'PostgreSQL 15+ dengan in-memory fallback offline'),
                const _TechRow(label: 'Keamanan', value: 'SHA-256 Tamper-evident Ledger, JWT Access & Rotating Refresh'),
                const _TechRow(label: 'Decision Support', value: 'AI Assistant (Gemini/LLM) + Rule Engine (8 Rules)'),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              '© 2026 ARUS System • Hak Cipta Dilindungi',
              style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

}

/// Baris teknologi — widget class top-level const (aturan E23).
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
              style: GoogleFonts.lexend(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.lexend(fontSize: 12.5, color: AppTheme.accentBlack),
            ),
          ),
        ],
      ),
    );
  }
}
