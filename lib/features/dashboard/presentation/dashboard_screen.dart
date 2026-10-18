import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
              ref.invalidate(dailyProfitComparisonProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryBlue,
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

                  // 4. Aksi Cepat (Quick Actions)
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

                  // 5. KPI Overview Cards (sesuai periode dropdown yang dipilih)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ringkasan Metrik (${selectedDateFilter.label})',
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.accentBlack,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (selectedOutletId != null)
                        Text(
                          'Cabang Terfilter',
                          style: GoogleFonts.lexend(
                            fontSize: 11,
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AsyncStateView<AnalyticsOverviewModel>(
                    value: overviewAsync,
                    onRetry: () => ref.invalidate(analyticsOverviewProvider),
                    dataBuilder: (kpi) => _KpiGrid(kpi: kpi, isOwnerOrManager: isOwnerOrManager),
                  ),

                  const SizedBox(height: 20),

                  // 6. Tren Penjualan 7 Hari
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

                  // 7. Banner Wawasan Bisnis Cepat
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOutline, width: 1.0),
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
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderOutline, width: 1.0),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: effectiveOutletValue,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.primaryBlue),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 16, color: AppTheme.primaryBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Semua Cabang',
                            style: GoogleFonts.lexend(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentBlack,
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
                          const Icon(Icons.store_rounded, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              outlet.name,
                              style: GoogleFonts.lexend(fontSize: 12.5, color: AppTheme.accentBlack),
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
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderOutline, width: 1.0),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DashboardDateFilter>(
                value: selectedDateFilter,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.primaryBlue),
                items: DashboardDateFilter.values.map((filter) {
                  return DropdownMenuItem<DashboardDateFilter>(
                    value: filter,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primaryBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            filter.label,
                            style: GoogleFonts.lexend(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentBlack,
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
        ? const Color(0xFF16A34A)
        : isDown
            ? const Color(0xFFDC2626)
            : AppTheme.primaryBlue;

    final statusBg = isUp
        ? const Color(0xFFDCFCE7)
        : isDown
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFF0FDFA);

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOutline, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBlueBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_graph_rounded, color: AppTheme.primaryBlue, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Komparasi Laba Harian',
                        style: GoogleFonts.lexend(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentBlack,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Hari Ini vs Hari Kemarin ($selectedOutletName)',
                        style: GoogleFonts.lexend(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withAlpha(60)),
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
          const Divider(height: 1, color: AppTheme.borderOutline),
          const SizedBox(height: 14),

          // Nilai Laba Hari Ini vs Kemarin
          Row(
            children: [
              // Laba Hari Ini
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderOutline, width: 1),
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
                              color: AppTheme.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Laba Hari Ini',
                            style: GoogleFonts.lexend(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
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
                          color: AppTheme.accentBlack,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Omset: ${comparison.formattedTodayRevenue}',
                        style: GoogleFonts.lexend(fontSize: 10.5, color: const Color(0xFF64748B)),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderOutline, width: 1),
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
                              color: Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Laba Kemarin',
                            style: GoogleFonts.lexend(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
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
                          color: const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Omset: ${comparison.formattedYesterdayRevenue}',
                        style: GoogleFonts.lexend(fontSize: 10.5, color: const Color(0xFF94A3B8)),
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
              color: statusBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate_outlined, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.accentBlack),
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
                            color: const Color(0xFF475569),
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
