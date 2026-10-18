import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../analytics/domain/analytics_models.dart';
import 'analytics_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(analyticsOverviewProvider);
    final peakHoursAsync = ref.watch(peakHoursProvider);

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
          'Analitik Performa',
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.w700,
            fontSize: 16.5,
            color: AppTheme.textPrimaryDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimaryDark),
            tooltip: 'Segarkan',
            onPressed: () {
              ref.invalidate(analyticsOverviewProvider);
              ref.invalidate(peakHoursProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.jadeTosca,
        backgroundColor: AppTheme.darkCardSurfaceElevated,
        onRefresh: () async {
          ref.invalidate(analyticsOverviewProvider);
          ref.invalidate(peakHoursProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
            // Overview Box
            AsyncStateView<AnalyticsOverviewModel>(
              value: overviewAsync,
              onRetry: () => ref.invalidate(analyticsOverviewProvider),
              dataBuilder: (kpi) => _OverviewCard(kpi: kpi),
            ),

            const SizedBox(height: 24),

            // Distribusi Jam Ramai (Peak Hours)
            Text(
              'Distribusi Jam Ramai Transaksi (Peak Hours)',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.textPrimaryDark,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Gunakan data ini untuk penyesuaian jadwal kasir & persiapan persediaan bahan.',
              style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textMutedDark),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            AsyncStateView<List<PeakHourPoint>>(
              value: peakHoursAsync,
              onRetry: () => ref.invalidate(peakHoursProvider),
              dataBuilder: (hours) => _PeakHoursList(hours: hours),
            ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );

    if (ShadTheme.maybeOf(context) == null) {
      return ShadTheme(
        data: AppTheme.shadcnThemeDark,
        child: scaffold,
      );
    }
    return scaffold;
  }
}

/// Kartu ringkasan analitik — memakai ShadCard
class _OverviewCard extends StatelessWidget {
  final AnalyticsOverviewModel kpi;

  const _OverviewCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Pendapatan Terakumulasi',
            style: GoogleFonts.lexend(color: AppTheme.textMutedDark, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            kpi.formattedRevenue,
            style: GoogleFonts.lexend(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: AppTheme.textPrimaryDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 24, color: AppTheme.darkCardBorder, thickness: 1.0),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Transaksi', value: '${kpi.transactionCount} kali')),
              Expanded(child: _MiniStat(label: 'Rata-rata Order', value: kpi.formattedAvgBasket)),
              if (kpi.grossMarginPct != null)
                Expanded(child: _MiniStat(label: 'Margin Kotor', value: '${kpi.grossMarginPct}%')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stat mini — widget class top-level const (aturan E23, B7 Expanded di call-site).
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.lexend(fontSize: 11, color: AppTheme.textMutedDark),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryDark),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Daftar jam ramai — widget class top-level (aturan E23, empty via EmptyStateView).
class _PeakHoursList extends StatelessWidget {
  final List<PeakHourPoint> hours;

  const _PeakHoursList({required this.hours});

  @override
  Widget build(BuildContext context) {
    final busiestHours = hours.where((h) => h.transactionCount > 0).toList()
      ..sort((a, b) => b.transactionCount.compareTo(a.transactionCount));

    if (busiestHours.isEmpty) {
      return const EmptyStateView(
        message: 'Belum ada data transaksi yang tercatat.',
        icon: Icons.bar_chart_outlined,
      );
    }

    // List kecil dan tetap (maks 6 item) — render inline tanpa scroll bersarang (aturan A4).
    return Column(
      children: busiestHours.take(6).map((h) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ShadCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.jadeTosca.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.jadeTosca.withValues(alpha: 0.3), width: 1.0),
                  ),
                  child: Center(
                    child: Text(
                      h.label.split(':')[0],
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.jadeTosca,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        color: AppTheme.textPrimaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${h.transactionCount} transaksi selesai',
                      style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMutedDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  MoneyFormatter.format(h.totalRevenueIdr),
                  style: GoogleFonts.lexend(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.jadeTosca,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );
  }
}
