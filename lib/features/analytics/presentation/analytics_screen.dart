import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import 'analytics_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(analyticsOverviewProvider);
    final peakHoursAsync = ref.watch(peakHoursProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Analitik Performa',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentBlack),
            tooltip: 'Segarkan',
            onPressed: () {
              ref.invalidate(analyticsOverviewProvider);
              ref.invalidate(peakHoursProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryToska,
        onRefresh: () async {
          ref.invalidate(analyticsOverviewProvider);
          ref.invalidate(peakHoursProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Ringkasan pendapatan (gradien toska)
            overviewAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryToska)),
              ),
              error: (e, _) => _buildErrorBox('Error: $e'),
              data: (kpi) => _buildRevenueCard(
                revenue: kpi.formattedRevenue,
                transactions: '${kpi.transactionCount} kali',
                avgOrder: kpi.formattedAvgBasket,
                margin: kpi.grossMarginPct != null ? '${kpi.grossMarginPct}%' : null,
              ),
            ),

            // Jam ramai
            _buildSectionTitle('Distribusi Jam Ramai (Peak Hours)'),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                'Gunakan data ini untuk penyesuaian jadwal kasir & persiapan persediaan bahan.',
                style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textMuted, height: 1.35),
              ),
            ),

            peakHoursAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryToska)),
              ),
              error: (e, _) => _buildErrorBox('Error: $e'),
              data: (hours) {
                final busiestHours = hours.where((h) => h.transactionCount > 0).toList()
                  ..sort((a, b) => b.transactionCount.compareTo(a.transactionCount));

                if (busiestHours.isEmpty) {
                  return _buildCardBox(
                    child: Text(
                      'Belum ada data transaksi yang tercatat.',
                      style: GoogleFonts.lexend(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  );
                }

                return Column(
                  children: busiestHours.take(6).toList().asMap().entries.map((entry) {
                    final rank = entry.key;
                    final h = entry.value;
                    return _buildHourTile(
                      rank: rank,
                      hourLabel: h.label,
                      hourShort: h.label.split(':')[0],
                      txCount: h.transactionCount,
                      revenue: currencyFormatter.format(h.totalRevenueIdr),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Komponen ----------

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.lexend(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildRevenueCard({
    required String revenue,
    required String transactions,
    required String avgOrder,
    String? margin,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryToska, AppTheme.darkToska],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkToska.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Pendapatan Terakumulasi',
            style: GoogleFonts.lexend(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            revenue,
            style: GoogleFonts.lexend(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat('Transaksi', transactions),
                _buildMiniStat('Rata-rata', avgOrder),
                if (margin != null) _buildMiniStat('Margin', margin),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.lexend(fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
        ),
      ],
    );
  }

  /// Satu baris jam ramai. Peringkat 1 diberi latar toska penuh.
  Widget _buildHourTile({
    required int rank,
    required String hourLabel,
    required String hourShort,
    required int txCount,
    required String revenue,
  }) {
    final isTop = rank == 0;
    final fg = isTop ? Colors.white : AppTheme.darkToska;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTop ? AppTheme.primaryToska : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTop ? AppTheme.primaryToska : AppTheme.borderOutline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTop ? Colors.white.withValues(alpha: 0.2) : AppTheme.lightToskaBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              hourShort,
              style: GoogleFonts.lexend(fontWeight: FontWeight.w800, color: fg, fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pukul $hourLabel',
                  style: GoogleFonts.lexend(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isTop ? Colors.white : AppTheme.accentBlack,
                  ),
                ),
                Text(
                  '$txCount transaksi selesai',
                  style: GoogleFonts.lexend(
                    fontSize: 11.5,
                    color: isTop ? Colors.white.withValues(alpha: 0.9) : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            revenue,
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700, color: fg, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderOutline),
      ),
      child: child,
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.5)),
      ),
      child: Text(message, style: GoogleFonts.lexend(color: AppTheme.dangerRed)),
    );
  }
}
