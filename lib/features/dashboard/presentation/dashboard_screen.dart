import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../sensors/presentation/sensor_provider.dart';
import 'trend_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<DateTime?>(shakeEventProvider, (prev, next) {
      if (next != null) {
        _refreshAll(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentBlack,
            content: Text(
              'Guncangan terdeteksi! Memperbarui data KPI...',
              style: GoogleFonts.lexend(color: Colors.white, fontSize: 13),
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
    final shiftAsync = ref.watch(shiftSummaryProvider);
    final stockAsync = ref.watch(inventoryListProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

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
            onPressed: () => _refreshAll(ref),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: AppTheme.dangerRed,
              label: Text('$unreadCount', style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 10)),
              child: const Icon(Icons.notifications_outlined, color: AppTheme.accentBlack),
            ),
            tooltip: 'Pusat Notifikasi',
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryToska,
        onRefresh: () async => _refreshAll(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // 1. Kondisi uang hari ini
            _buildSectionTitle('Hari Ini'),
            shiftAsync.when(
              loading: _loadingBox,
              error: (e, _) => _buildErrorBox('Gagal memuat ringkasan hari ini: $e'),
              data: (shift) => _buildTodayCard(shift, isOwnerOrManager),
            ),

            // 2. Perlu tindakan
            _buildSectionTitle('Perlu Perhatian'),
            stockAsync.when(
              loading: _loadingBox,
              error: (e, _) => _buildErrorBox('Gagal memuat stok: $e'),
              data: (items) => _buildAttentionList(items),
            ),

            // 3. KPI periode
            _buildSectionTitle('Ringkasan KPI'),
            overviewAsync.when(
              loading: _loadingBox,
              error: (e, _) => _buildErrorBox('Gagal memuat KPI: $e'),
              data: (kpi) => _buildKpiGrid(kpi, isOwnerOrManager),
            ),

            // 4. Tren
            _buildSectionTitle('Tren Omset 7 Hari'),
            trendAsync.when(
              loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: AppTheme.primaryToska))),
              error: (e, _) => _buildErrorBox('Gagal memuat tren: $e'),
              data: (points) => _buildCardBox(child: TrendChart(points: points)),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(analyticsOverviewProvider);
    ref.invalidate(salesTrendProvider);
    ref.invalidate(shiftSummaryProvider);
    ref.invalidate(inventoryListProvider);
  }

  // ---------- Komponen ----------

  Widget _loadingBox() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator(color: AppTheme.primaryToska)),
    );
  }

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

  /// Omzet hari ini dengan pembagian tunai dan QRIS.
  Widget _buildTodayCard(ShiftSummaryModel shift, bool isOwnerOrManager) {
    final total = shift.todayRevenueIdr;
    final cashShare = total > 0 ? (shift.cashRevenueIdr / total).clamp(0.0, 1.0).toDouble() : 0.0;

    return _buildCardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Omzet hari ini', style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      _rupiah.format(total),
                      style: GoogleFonts.lexend(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentBlack,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              _pill('${shift.transactionCount} transaksi'),
            ],
          ),
          if (isOwnerOrManager) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: total > 0 ? cashShare : 0,
                minHeight: 10,
                backgroundColor: AppTheme.primaryToska.withValues(alpha: 0.35),
                color: AppTheme.primaryToska,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _splitStat('Tunai', _rupiah.format(shift.cashRevenueIdr), AppTheme.primaryToska)),
                Expanded(child: _splitStat('QRIS', _rupiah.format(shift.qrisRevenueIdr), AppTheme.primaryToska.withValues(alpha: 0.35))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _splitStat(String label, String value, Color dot) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$label $value',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// Daftar stok yang menipis, maksimal tiga baris. Ketuk untuk membuka inventaris.
  Widget _buildAttentionList(List<InventoryStockItem> items) {
    final low = items.where((i) => i.isLowStock).toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));

    if (low.isEmpty) {
      return _buildCardBox(
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: AppTheme.primaryToska),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Semua stok aman. Tidak ada produk di bawah batas minimum.',
                style: GoogleFonts.lexend(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderOutline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${low.length} produk stok menipis',
                        style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.accentBlack),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                  ],
                ),
                for (final item in low.take(3)) ...[
                  const Divider(height: 20, color: AppTheme.borderOutline),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.lexend(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${item.quantity} / min ${item.reorderLevel} ${item.unit}',
                        style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.dangerRed, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(AnalyticsOverviewModel kpi, bool isOwnerOrManager) {
    final showMargin = isOwnerOrManager && kpi.grossProfitIdr != null;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Total Omset',
                value: kpi.formattedRevenue,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'Transaksi',
                value: '${kpi.transactionCount}',
                icon: Icons.receipt_long_outlined,
                accent: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Rata-rata Keranjang',
                value: kpi.formattedAvgBasket,
                icon: Icons.shopping_basket_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: showMargin
                  ? _buildMetricCard(
                      title: 'Laba Kotor (${kpi.grossMarginPct ?? 0}%)',
                      value: kpi.formattedGrossProfit,
                      icon: Icons.trending_up_rounded,
                      accent: true,
                    )
                  : _buildMetricCard(
                      title: 'Diskon',
                      value: _rupiah.format(kpi.discountIdr),
                      icon: Icons.sell_outlined,
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    bool accent = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent ? AppTheme.lightToskaBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent ? AppTheme.primaryToska.withValues(alpha: 0.35) : AppTheme.borderOutline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent ? AppTheme.primaryToska : AppTheme.lightToskaBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryToska.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, size: 16, color: accent ? Colors.white : AppTheme.primaryToska),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.lexend(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
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
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.lightToskaBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primaryToska.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: GoogleFonts.lexend(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.darkToska),
      ),
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
      child: Text(message, style: GoogleFonts.lexend(color: AppTheme.dangerRed, fontSize: 13)),
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
}
