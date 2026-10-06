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
        color: AppTheme.primaryBlue,
        onRefresh: () async {
          ref.invalidate(analyticsOverviewProvider);
          ref.invalidate(peakHoursProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Overview Box
            overviewAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                ),
              ),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                ),
                child: Text('Error: $e', style: GoogleFonts.lexend(color: const Color(0xFFDC2626))),
              ),
              data: (kpi) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderOutline, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Pendapatan Terakumulasi',
                      style: GoogleFonts.lexend(color: const Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      kpi.formattedRevenue,
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: AppTheme.accentBlack,
                      ),
                    ),
                    const Divider(height: 24, color: AppTheme.borderOutline, thickness: 1.2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniStat('Transaksi', '${kpi.transactionCount} kali'),
                        _buildMiniStat('Rata-rata Order', kpi.formattedAvgBasket),
                        if (kpi.grossMarginPct != null)
                          _buildMiniStat('Margin Kotor', '${kpi.grossMarginPct}%'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Distribusi Jam Ramai (Peak Hours)
            Text(
              'Distribusi Jam Ramai Transaksi (Peak Hours)',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.accentBlack,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gunakan data ini untuk penyesuaian jadwal kasir & persiapan persediaan bahan.',
              style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),

            peakHoursAsync.when(
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
              ),
              error: (e, _) => Text('Error: $e', style: GoogleFonts.lexend()),
              data: (hours) {
                final busiestHours = hours.where((h) => h.transactionCount > 0).toList()
                  ..sort((a, b) => b.transactionCount.compareTo(a.transactionCount));

                if (busiestHours.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderOutline, width: 1.5),
                    ),
                    child: Text(
                      'Belum ada data transaksi yang tercatat.',
                      style: GoogleFonts.lexend(color: const Color(0xFF64748B)),
                    ),
                  );
                }

                return Column(
                  children: busiestHours.take(6).map((h) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.borderOutline, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                h.label.split(':')[0],
                                style: GoogleFonts.lexend(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryBlue,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pukul ${h.label}',
                                  style: GoogleFonts.lexend(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppTheme.accentBlack,
                                  ),
                                ),
                                Text(
                                  '${h.transactionCount} transaksi selesai',
                                  style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            currencyFormatter.format(h.totalRevenueIdr),
                            style: GoogleFonts.lexend(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.lexend(fontSize: 11, color: const Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accentBlack),
        ),
      ],
    );
  }
}
