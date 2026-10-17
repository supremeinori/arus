import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../sensors/presentation/sensor_provider.dart';
import '../../../shared/widgets/async_state_view.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<DateTime?>(shakeEventProvider, (prev, next) {
      if (next != null) {
        ref.invalidate(analyticsOverviewProvider);
        ref.invalidate(salesTrendProvider);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentBlack,
            content: Row(
              children: [
                const Icon(Icons.vibration_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guncangan terdeteksi! Memperbarui data KPI...',
                    style: GoogleFonts.lexend(color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final user = ref.watch(authProvider).user;
    final isOwnerOrManager = user?.role == UserRole.owner || user?.role == UserRole.manager;
    final overviewAsync = ref.watch(analyticsOverviewProvider);
    final trendAsync = ref.watch(salesTrendProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Beranda',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentBlack),
            tooltip: 'Segarkan Data',
            onPressed: () {
              ref.invalidate(analyticsOverviewProvider);
              ref.invalidate(salesTrendProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryBlue,
        onRefresh: () async {
          ref.invalidate(analyticsOverviewProvider);
          ref.invalidate(salesTrendProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
            // Welcome Header Enterprise
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderOutline, width: 1.0),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, ${user?.name ?? ""}',
                          style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentBlack,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Akses: ${user?.role.toDisplayString() ?? ""}',
                          style: GoogleFonts.lexend(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Aksi Cepat (Quick Actions)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/pos'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withAlpha(40),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            'Kasir POS',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/catalog/new'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderOutline, width: 1.0),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryBlue, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            'Tambah Produk',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentBlack,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/inventory'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderOutline, width: 1.0),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warehouse_outlined, color: Color(0xFF64748B), size: 22),
                          const SizedBox(height: 6),
                          Text(
                            'Cek Stok',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentBlack,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // KPI Overview Cards
            AsyncStateView<AnalyticsOverviewModel>(
              value: overviewAsync,
              onRetry: () => ref.invalidate(analyticsOverviewProvider),
              dataBuilder: (kpi) => _KpiGrid(kpi: kpi, isOwnerOrManager: isOwnerOrManager),
            ),

            const SizedBox(height: 20),

            // Tren Penjualan 7 Hari
            Text(
              'Tren Omset 7 Hari Terakhir',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.accentBlack,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            AsyncStateView<List<SalesTrendPoint>>(
              value: trendAsync,
              onRetry: () => ref.invalidate(salesTrendProvider),
              dataBuilder: (trendPoints) => _TrendBars(points: trendPoints),
            ),

            const SizedBox(height: 20),

            // Banner Wawasan Bisnis Cepat
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderOutline, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Decision Support Siaga',
                          style: GoogleFonts.lexend(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Buka tab AI untuk tanya omset, jam ramai, atau cek inventaris secara real-time.',
                          style: GoogleFonts.lexend(
                            color: Colors.white.withAlpha(220),
                            fontSize: 12,
                            height: 1.35,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Grid KPI dashboard — widget class top-level const (aturan E23).
class _KpiGrid extends StatelessWidget {
  final AnalyticsOverviewModel kpi;
  final bool isOwnerOrManager;

  const _KpiGrid({required this.kpi, required this.isOwnerOrManager});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total Omset',
                value: kpi.formattedRevenue,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                title: 'Total Transaksi',
                value: '${kpi.transactionCount}',
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Rata-rata Keranjang',
                value: kpi.formattedAvgBasket,
                icon: Icons.shopping_basket_outlined,
              ),
            ),
            if (isOwnerOrManager && kpi.grossProfitIdr != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Estimasi Margin (${kpi.grossMarginPct ?? 0}%)',
                  value: kpi.formattedGrossProfit,
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Kartu metrik tunggal dashboard (aturan E23).
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOutline, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.lightBlueBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.lexend(
                    fontSize: 11.5,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.lexend(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentBlack,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Bar chart tren 7 hari — widget class top-level (aturan E23).
class _TrendBars extends StatelessWidget {
  final List<SalesTrendPoint> points;

  const _TrendBars({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderOutline, width: 1.0),
        ),
        child: Center(
          child: Text(
            'Belum ada data tren.',
            style: GoogleFonts.lexend(color: AppTheme.textMuted, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    final maxRevenue = points.fold<int>(0, (max, p) => p.revenueIdr > max ? p.revenueIdr : max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOutline, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map<Widget>((p) {
          final ratio = maxRevenue > 0 ? (p.revenueIdr / maxRevenue).clamp(0.08, 1.0).toDouble() : 0.08;
          return Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 85.0 * ratio,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  p.date.length >= 5 ? p.date.substring(5) : p.date,
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
