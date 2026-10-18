import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../sensors/presentation/sensor_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<DateTime?>(shakeEventProvider, (prev, next) {
      if (next != null) {
        ref.invalidate(analyticsOverviewProvider);
        ref.invalidate(salesTrendProvider);
        ref.invalidate(dailyProfitComparisonProvider);
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
    final dailyComparisonAsync = ref.watch(dailyProfitComparisonProvider);

    // Outlet & Date Filter State
    final selectedOutletId = ref.watch(selectedOutletFilterProvider);
    final selectedDateFilter = ref.watch(selectedDateFilterProvider);
    final List<({String id, String name})> outlets = (user?.outlets ?? [])
        .map((o) => (id: o.id, name: o.name))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        scrolledUnderElevation: 0,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
        ),
        title: Text(
          'Beranda',
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppTheme.textPrimaryDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimaryDark),
            tooltip: 'Segarkan Data',
            onPressed: () {
              ref.invalidate(analyticsOverviewProvider);
              ref.invalidate(salesTrendProvider);
              ref.invalidate(dailyProfitComparisonProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.jadeTosca,
        backgroundColor: AppTheme.darkCardSurface,
        onRefresh: () async {
          ref.invalidate(analyticsOverviewProvider);
          ref.invalidate(salesTrendProvider);
          ref.invalidate(dailyProfitComparisonProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Welcome Header Enterprise
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
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
                              colors: [Color(0xFF00A896), Color(0xFF0D9488)],
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
                                  color: AppTheme.textPrimaryDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Akses: ${user?.role.toDisplayString() ?? ""}',
                                style: GoogleFonts.lexend(
                                  fontSize: 12,
                                  color: AppTheme.textMutedDark,
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

                  // 2. Dropdown Filter Bar: Pilihan Cabang & Pilihan Hari
                  _DashboardFilterBar(
                    selectedOutletId: selectedOutletId,
                    outlets: outlets,
                    selectedDateFilter: selectedDateFilter,
                    onOutletChanged: (outletId) {
                      ref.read(selectedOutletFilterProvider.notifier).state = outletId;
                    },
                    onDateFilterChanged: (filter) {
                      ref.read(selectedDateFilterProvider.notifier).state = filter;
                    },
                  ),

                  const SizedBox(height: 14),

                  // 3. Perhitungan Perbedaan Laba Hari Kemarin dan Sekarang
                  if (isOwnerOrManager) ...[
                    AsyncStateView<DailyProfitComparisonModel>(
                      value: dailyComparisonAsync,
                      onRetry: () => ref.invalidate(dailyProfitComparisonProvider),
                      dataBuilder: (comparison) => _DailyProfitComparisonCard(
                        comparison: comparison,
                        selectedOutletName: selectedOutletId == null
                            ? 'Seluruh Cabang'
                            : (outlets.where((o) => o.id == selectedOutletId).isNotEmpty
                                ? outlets.firstWhere((o) => o.id == selectedOutletId).name
                                : 'Cabang'),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 4. KPI Overview Cards (2x2 Bento Grid)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Ringkasan Metrik (${selectedDateFilter.label})',
                          style: GoogleFonts.lexend(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTheme.textPrimaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedOutletId != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Cabang Terfilter',
                          style: GoogleFonts.lexend(
                            fontSize: 11,
                            color: AppTheme.jadeTosca,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  AsyncStateView<AnalyticsOverviewModel>(
                    value: overviewAsync,
                    onRetry: () => ref.invalidate(analyticsOverviewProvider),
                    dataBuilder: (kpi) => _KpiBentoGrid(kpi: kpi, isOwnerOrManager: isOwnerOrManager),
                  ),

                  const SizedBox(height: 20),

                  // 5. Tren Penjualan 7 Hari (Curved Line Area Chart)
                  Text(
                    'Tren Omset 7 Hari Terakhir',
                    style: GoogleFonts.lexend(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textPrimaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  AsyncStateView<List<SalesTrendPoint>>(
                    value: trendAsync,
                    onRetry: () => ref.invalidate(salesTrendProvider),
                    dataBuilder: (trendPoints) => _CurvedSalesAreaChart(points: trendPoints),
                  ),

                  const SizedBox(height: 20),

                  // 6. Banner Wawasan Bisnis Cepat
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.jadeTosca.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: AppTheme.jadeTosca, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Decision Support Siaga',
                                style: GoogleFonts.lexend(
                                  color: AppTheme.textPrimaryDark,
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
                                  color: AppTheme.textMutedDark,
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

/// Bar Filter Cabang & Periode Hari
class _DashboardFilterBar extends StatelessWidget {
  final String? selectedOutletId;
  final List<({String id, String name})> outlets;
  final DashboardDateFilter selectedDateFilter;
  final ValueChanged<String?> onOutletChanged;
  final ValueChanged<DashboardDateFilter> onDateFilterChanged;

  const _DashboardFilterBar({
    required this.selectedOutletId,
    required this.outlets,
    required this.selectedDateFilter,
    required this.onOutletChanged,
    required this.onDateFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 360;
          final effectiveOutletValue = (selectedOutletId != null && outlets.any((o) => o.id == selectedOutletId))
              ? selectedOutletId
              : null;

          final outletDropdown = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.darkCardSurfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: effectiveOutletValue,
                isExpanded: true,
                dropdownColor: AppTheme.darkCardSurface,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.jadeTosca),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 16, color: AppTheme.jadeTosca),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Semua Cabang',
                            style: GoogleFonts.lexend(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...outlets.map<DropdownMenuItem<String?>>((outlet) {
                    return DropdownMenuItem<String?>(
                      value: outlet.id,
                      child: Row(
                        children: [
                          const Icon(Icons.store_rounded, size: 16, color: AppTheme.textMutedDark),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              outlet.name,
                              style: GoogleFonts.lexend(fontSize: 12.5, color: AppTheme.textPrimaryDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: onOutletChanged,
              ),
            ),
          );

          final dateDropdown = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.darkCardSurfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DashboardDateFilter>(
                value: selectedDateFilter,
                isExpanded: true,
                dropdownColor: AppTheme.darkCardSurface,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.jadeTosca),
                items: DashboardDateFilter.values.map((filter) {
                  return DropdownMenuItem<DashboardDateFilter>(
                    value: filter,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.jadeTosca),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            filter.label,
                            style: GoogleFonts.lexend(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) onDateFilterChanged(val);
                },
              ),
            ),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                outletDropdown,
                const SizedBox(height: 8),
                dateDropdown,
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: outletDropdown),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: dateDropdown),
            ],
          );
        },
      ),
    );
  }
}

/// Kartu Perhitungan Perbedaan Laba Hari Kemarin dan Sekarang
class _DailyProfitComparisonCard extends StatelessWidget {
  final DailyProfitComparisonModel comparison;
  final String selectedOutletName;

  const _DailyProfitComparisonCard({
    required this.comparison,
    required this.selectedOutletName,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = comparison.isProfitUp;
    final isDown = comparison.isProfitDown;

    final statusColor = isUp
        ? const Color(0xFF22C55E)
        : isDown
            ? const Color(0xFFEF4444)
            : AppTheme.jadeTosca;

    final statusBg = isUp
        ? const Color(0x2616A34A)
        : isDown
            ? const Color(0x26DC2626)
            : const Color(0x2600A896);

    final statusIcon = isUp
        ? Icons.trending_up_rounded
        : isDown
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;

    final statusText = isUp
        ? '${comparison.formattedProfitPct} Naik'
        : isDown
            ? '${comparison.formattedProfitPct} Turun'
            : 'Stabil (0%)';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.jadeTosca.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_graph_rounded, color: AppTheme.jadeTosca, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Komparasi Laba Harian',
                            style: GoogleFonts.lexend(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Hari Ini vs Hari Kemarin ($selectedOutletName)',
                            style: GoogleFonts.lexend(
                              fontSize: 11,
                              color: AppTheme.textMutedDark,
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: GoogleFonts.lexend(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.darkCardBorder),
          const SizedBox(height: 14),

          // Nilai Laba Hari Ini vs Kemarin
          Row(
            children: [
              // Laba Hari Ini
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.jadeTosca,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Laba Hari Ini',
                              style: GoogleFonts.lexend(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMutedDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        comparison.formattedTodayProfit,
                        style: GoogleFonts.lexend(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Omset: ${comparison.formattedTodayRevenue}',
                        style: GoogleFonts.lexend(fontSize: 10.5, color: AppTheme.textMutedDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Laba Hari Kemarin
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF64748B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Laba Kemarin',
                              style: GoogleFonts.lexend(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textMutedDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        comparison.formattedYesterdayProfit,
                        style: GoogleFonts.lexend(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Omset: ${comparison.formattedYesterdayRevenue}',
                        style: GoogleFonts.lexend(fontSize: 10.5, color: AppTheme.textMutedDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Detail Perhitungan Selisih Laba
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkCardSurfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate_outlined, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textPrimaryDark),
                      children: [
                        const TextSpan(text: 'Perbedaan Laba: '),
                        TextSpan(
                          text: comparison.formattedProfitDiff,
                          style: GoogleFonts.lexend(
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                        TextSpan(
                          text: ' (${comparison.formattedProfitPct}) dibanding kemarin',
                          style: GoogleFonts.lexend(
                            color: AppTheme.textMutedDark,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bento Grid 2x2 KPI Dashboard Mobile
class _KpiBentoGrid extends StatelessWidget {
  final AnalyticsOverviewModel kpi;
  final bool isOwnerOrManager;

  const _KpiBentoGrid({required this.kpi, required this.isOwnerOrManager});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Row 1: Total Omset & Total Transaksi
        Row(
          children: [
            Expanded(
              child: _BentoCard(
                title: 'Total Omset',
                value: kpi.formattedRevenue,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BentoCard(
                title: 'Total Transaksi',
                value: '${kpi.transactionCount}',
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Row 2: Rata-rata Struk / ATV & Status Integritas Blockchain
        Row(
          children: [
            Expanded(
              child: _BentoCard(
                title: 'Rata-rata Struk / ATV',
                value: kpi.formattedAvgBasket,
                icon: Icons.shopping_basket_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BlockchainIntegrityCard(
                kpi: kpi,
                isOwnerOrManager: isOwnerOrManager,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BentoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _BentoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.jadeTosca.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppTheme.jadeTosca),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
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
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryDark,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BlockchainIntegrityCard extends StatelessWidget {
  final AnalyticsOverviewModel kpi;
  final bool isOwnerOrManager;

  const _BlockchainIntegrityCard({
    required this.kpi,
    required this.isOwnerOrManager,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.jadeTosca.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: AppTheme.jadeTosca,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Status Integritas Blockchain',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.jadeTosca),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Terverifikasi',
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.jadeTosca,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (isOwnerOrManager && kpi.grossProfitIdr != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.darkCardSurfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.darkCardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Estimasi Margin (${kpi.grossMarginPct ?? 0}%)',
                    style: GoogleFonts.lexend(
                      fontSize: 10,
                      color: AppTheme.textMutedDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kpi.formattedGrossProfit,
                    style: GoogleFonts.lexend(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Curved Line Area Chart tren penjualan dengan efek gradien rgba(0, 168, 150, 0.4) -> transparan
class _CurvedSalesAreaChart extends StatelessWidget {
  final List<SalesTrendPoint> points;

  const _CurvedSalesAreaChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.darkCardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
        ),
        child: Center(
          child: Text(
            'Belum ada data tren.',
            style: GoogleFonts.lexend(color: AppTheme.textMutedDark, fontSize: 13),
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
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.jadeTosca.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.show_chart_rounded, size: 16, color: AppTheme.jadeTosca),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tren Omset 7 Hari',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.darkCardSurfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.darkCardBorder),
                ),
                child: Text(
                  'Puncak: Rp ${(maxRevenue / 1000).toStringAsFixed(0)}k',
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.jadeTosca,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _CurvedAreaChartPainter(points: points),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: points.map<Widget>((p) {
              final dateLabel = p.date.length >= 5 ? p.date.substring(5) : p.date;
              return Expanded(
                child: Text(
                  dateLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    color: AppTheme.textMutedDark,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CurvedAreaChartPainter extends CustomPainter {
  final List<SalesTrendPoint> points;

  _CurvedAreaChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxRevenue = points.fold<int>(0, (max, p) => p.revenueIdr > max ? p.revenueIdr : max);
    final effectiveMax = maxRevenue > 0 ? maxRevenue.toDouble() : 1.0;

    // Subtle horizontal grid lines
    final gridPaint = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 1.0;

    const gridLines = 3;
    for (int i = 0; i <= gridLines; i++) {
      final y = size.height * (i / gridLines);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length == 1) {
      final center = Offset(size.width / 2, size.height / 2);
      final dotPaint = Paint()..color = AppTheme.jadeTosca;
      canvas.drawCircle(center, 4, dotPaint);
      return;
    }

    final double stepX = size.width / (points.length - 1);
    final List<Offset> offsets = [];

    // Top and bottom padding for curve within canvas
    const double topPad = 8.0;
    const double bottomPad = 8.0;
    final double usableHeight = size.height - topPad - bottomPad;

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final normalizedY = (points[i].revenueIdr / effectiveMax).clamp(0.0, 1.0);
      final y = (size.height - bottomPad) - (normalizedY * usableHeight);
      offsets.add(Offset(x, y));
    }

    // Build curved path using cubic Bezier
    final Path linePath = Path();
    linePath.moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    // Build area path for gradient
    final Path areaPath = Path.from(linePath);
    areaPath.lineTo(offsets.last.dx, size.height);
    areaPath.lineTo(offsets.first.dx, size.height);
    areaPath.close();

    // Area Gradient: from rgba(0, 168, 150, 0.4) down to transparent
    final areaPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x6600A896), // rgba(0, 168, 150, 0.4)
          Color(0x0000A896), // transparent
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, areaPaint);

    // Line Stroke
    final linePaint = Paint()
      ..color = AppTheme.jadeTosca
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Draw dots at data points
    final dotOuterPaint = Paint()
      ..color = AppTheme.jadeTosca
      ..style = PaintingStyle.fill;
    final dotInnerPaint = Paint()
      ..color = AppTheme.darkCardSurface
      ..style = PaintingStyle.fill;

    for (final p in offsets) {
      canvas.drawCircle(p, 4.0, dotOuterPaint);
      canvas.drawCircle(p, 2.0, dotInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CurvedAreaChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
