import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../insights/presentation/insights_provider.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../sensors/presentation/sensor_provider.dart';
import '../../settings/presentation/currency_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listener Sensor Guncangan (Shake-to-Refresh)
    ref.listen<DateTime?>(shakeEventProvider, (prev, next) {
      if (next != null) {
        ref.invalidate(analyticsOverviewProvider);
        ref.invalidate(salesTrendProvider);
        ref.invalidate(dailyProfitComparisonProvider);
        ref.invalidate(ingredientsListProvider);
        ref.invalidate(insightsListProvider);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.textPrimaryDark,
            content: Row(
              children: [
                const Icon(Icons.vibration_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guncangan terdeteksi! Memperbarui data metrik & stok...',
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
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final currentCurrency = ref.watch(displayCurrencyProvider);
    final currentTimezone = ref.watch(displayTimezoneProvider);

    // Outlet & Date Filter State
    final selectedOutletId = ref.watch(selectedOutletFilterProvider);
    final selectedDateFilter = ref.watch(selectedDateFilterProvider);
    final List<({String id, String name})> outlets = (user?.outlets ?? [])
        .map((o) => (id: o.id, name: o.name))
        .toList();

    final effectiveOutletName = selectedOutletId == null
        ? 'Seluruh Cabang'
        : (outlets.where((o) => o.id == selectedOutletId).isNotEmpty
            ? outlets.firstWhere((o) => o.id == selectedOutletId).name
            : 'Cabang');

    final scaffold = Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkCardSurface,
        scrolledUnderElevation: 0,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
        ),
        title: Text(
          'Beranda',
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.w700,
            fontSize: 16.5,
            color: AppTheme.textPrimaryDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Currency Quick Switcher (IDR / USD / EUR)
          PopupMenuButton<String>(
            tooltip: 'Pilih Mata Uang',
            initialValue: currentCurrency,
            onSelected: (curr) {
              ref.read(displayCurrencyProvider.notifier).state = curr;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.darkCardSurfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.darkCardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentCurrency,
                    style: GoogleFonts.lexend(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.jadeTosca,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.jadeTosca),
                ],
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'IDR', child: Text('IDR (Rp - Rupiah)')),
              const PopupMenuItem(value: 'USD', child: Text('USD (\$ - Dollar AS)')),
              const PopupMenuItem(value: 'EUR', child: Text('EUR (€ - Euro)')),
            ],
          ),
          const SizedBox(width: 8),

          // Timezone Indicator Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.darkCardSurfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.darkCardBorder),
            ),
            child: Text(
              currentTimezone.contains('Jakarta')
                  ? 'WIB'
                  : currentTimezone.contains('Makassar')
                      ? 'WITA'
                      : 'WIT',
              style: GoogleFonts.lexend(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMutedDark,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Notifications Bell with Badge
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: AppTheme.dangerRed,
              label: Text(
                '$unreadCount',
                style: GoogleFonts.lexend(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppTheme.textPrimaryDark,
                size: 21,
              ),
            ),
            tooltip: 'Notifikasi',
            onPressed: () => context.push('/notifications'),
          ),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimaryDark, size: 21),
            tooltip: 'Segarkan Data',
            onPressed: () {
              ref.invalidate(analyticsOverviewProvider);
              ref.invalidate(salesTrendProvider);
              ref.invalidate(dailyProfitComparisonProvider);
              ref.invalidate(ingredientsListProvider);
              ref.invalidate(insightsListProvider);
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.jadeTosca,
        backgroundColor: AppTheme.darkCardSurface,
        onRefresh: () async {
          ref.invalidate(analyticsOverviewProvider);
          ref.invalidate(salesTrendProvider);
          ref.invalidate(dailyProfitComparisonProvider);
          ref.invalidate(ingredientsListProvider);
          ref.invalidate(insightsListProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Welcome & Blockchain Verification Header Card
              _ExecutiveHeaderCard(
                user: user,
                selectedOutletName: effectiveOutletName,
              ),

              const SizedBox(height: 14),

              // 2. Dropdown Filter Bar: Pilihan Cabang & Periode Hari
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

              // 3. Komparasi Laba Harian (Khusus Owner / Manager)
              if (isOwnerOrManager) ...[
                AsyncStateView<DailyProfitComparisonModel>(
                  value: dailyComparisonAsync,
                  onRetry: () => ref.invalidate(dailyProfitComparisonProvider),
                  dataBuilder: (comparison) => _DailyProfitComparisonCard(
                    comparison: comparison,
                    selectedOutletName: effectiveOutletName,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 4. Hero KPI Bento Grid (2x2 ala Inventix)
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

              const SizedBox(height: 16),

              // 5. Operational Trends Card (Curved Area Chart & Sensor Telemetry)
              AsyncStateView<List<SalesTrendPoint>>(
                value: trendAsync,
                onRetry: () => ref.invalidate(salesTrendProvider),
                dataBuilder: (trendPoints) => _OperationalTrendsCard(
                  points: trendPoints,
                  selectedFilter: selectedDateFilter,
                  onFilterTap: (filter) {
                    ref.read(selectedDateFilterProvider.notifier).state = filter;
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 6. Critical Action Card: "Stok Bahan Baku Kritis" (ala Inventix)
              const _CriticalStockActionCard(),

              const SizedBox(height: 16),

              // 7. Performance Row: Top Menu Terlaris & Kesehatan Stok Gudang
              const _PerformanceStorageRow(),

              const SizedBox(height: 16),

              // 8. Rekomendasi Keputusan AI (DSS)
              const _AiRecommendationsSection(),
              const SizedBox(height: 24),
            ],
          ),
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

/// 1. Executive Header Card
class _ExecutiveHeaderCard extends StatelessWidget {
  final UserModel? user;
  final String selectedOutletName;

  const _ExecutiveHeaderCard({
    required this.user,
    required this.selectedOutletName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00A896), Color(0xFF0D9488)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 19,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, ${user?.name ?? ""}',
                  style: GoogleFonts.lexend(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$selectedOutletName • ${user?.role.toDisplayString() ?? ""}',
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF059669)),
                const SizedBox(width: 4),
                Text(
                  'Chain Valid',
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF059669),
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

/// 2. Dropdown Filter Bar: Pilihan Cabang & Periode Hari
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
        borderRadius: BorderRadius.circular(14),
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

/// 3. Kartu Perhitungan Komparasi Laba Harian (Hari Ini vs Kemarin)
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
        ? const Color(0xFF059669)
        : isDown
            ? const Color(0xFFDC2626)
            : AppTheme.jadeTosca;

    final statusBg = isUp
        ? const Color(0xFFECFDF5)
        : isDown
            ? const Color(0xFFFEF2F2)
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
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(16),
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
                              color: Color(0xFF94A3B8),
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

/// 4. Bento Grid 2x2 KPI Dashboard Mobile
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
        borderRadius: BorderRadius.circular(14),
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
              fontSize: 22,
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
        borderRadius: BorderRadius.circular(14),
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
                  'Integritas Blockchain',
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
              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Terverifikasi',
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF059669),
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

/// 5. Operational Trends Card (Curved Area Chart & Telemetry)
class _OperationalTrendsCard extends StatelessWidget {
  final List<SalesTrendPoint> points;
  final DashboardDateFilter selectedFilter;
  final ValueChanged<DashboardDateFilter> onFilterTap;

  const _OperationalTrendsCard({
    required this.points,
    required this.selectedFilter,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxRevenue = points.fold<int>(0, (max, p) => p.revenueIdr > max ? p.revenueIdr : max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operasional & Tren Omset',
                      style: GoogleFonts.lexend(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Puncak: Rp ${(maxRevenue / 1000).toStringAsFixed(0)}k • Tilt/Shake aktif',
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.darkCardSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkCardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PeriodPill(
                      label: '7H',
                      isSelected: selectedFilter == DashboardDateFilter.last7Days,
                      onTap: () => onFilterTap(DashboardDateFilter.last7Days),
                    ),
                    _PeriodPill(
                      label: '30H',
                      isSelected: selectedFilter == DashboardDateFilter.last30Days,
                      onTap: () => onFilterTap(DashboardDateFilter.last30Days),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (points.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada data tren omset.',
                  style: GoogleFonts.lexend(color: AppTheme.textMutedDark, fontSize: 13),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 125,
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
                      fontSize: 10.5,
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
        ],
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.jadeTosca : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.lexend(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textMutedDark,
          ),
        ),
      ),
    );
  }
}

/// 6. Critical Stock Action Card (Adaptasi "Product running out of stock" ala Inventix)
class _CriticalStockActionCard extends ConsumerWidget {
  const _CriticalStockActionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientsAsync = ref.watch(ingredientsListProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(16),
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
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stok Bahan Baku Kritis',
                        style: GoogleFonts.lexend(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.jadeTosca, size: 20),
                tooltip: 'Lihat Semua Inventaris',
                onPressed: () => context.push('/inventory'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ingredientsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => Text(
              'Gagal memuat status bahan baku.',
              style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.dangerRed),
            ),
            data: (ingredients) {
              final critical = ingredients.where((i) => i.isLowStock || i.isOutOfStock).take(3).toList();
              if (critical.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Seluruh stok bahan baku dalam batas aman.',
                          style: GoogleFonts.lexend(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: critical.map((ing) {
                  final isOut = ing.isOutOfStock;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCardSurfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isOut ? const Color(0xFFFCA5A5) : AppTheme.darkCardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isOut ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.egg_alt_outlined,
                              size: 16,
                              color: isOut ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ing.name,
                                  style: GoogleFonts.lexend(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Sisa: ${ing.stockQty} ${ing.unit} (Min: ${ing.reorderLevel})',
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOut ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOut ? 'Habis' : 'Menipis',
                              style: GoogleFonts.lexend(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 7. Performance Storage Row (Kesehatan Stok Gudang)
class _PerformanceStorageRow extends ConsumerWidget {
  const _PerformanceStorageRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientsAsync = ref.watch(ingredientsListProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Kesehatan Stok & Gudang',
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.inventory_2_outlined, size: 18, color: AppTheme.jadeTosca),
            ],
          ),
          const SizedBox(height: 12),
          ingredientsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (ingredients) {
              if (ingredients.isEmpty) {
                return Text(
                  'Data inventaris belum terisi.',
                  style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textMutedDark),
                );
              }
              final safeCount = ingredients.where((i) => !i.isLowStock && !i.isOutOfStock).length;
              final totalCount = ingredients.length;
              final safePct = totalCount > 0 ? (safeCount / totalCount) : 1.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Rasio Bahan Baku Siap Pakai',
                          style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMutedDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(safePct * 100).toStringAsFixed(0)}% Sehat',
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.jadeTosca,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: safePct,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFFEE2E2),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.jadeTosca),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$safeCount dari $totalCount bahan baku dalam kuantitas aman',
                    style: GoogleFonts.lexend(fontSize: 10.5, color: AppTheme.textMutedDark),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Curved Line Area Chart Painter
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
      ..color = const Color(0xFFE2E8F0)
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

    const double topPad = 8.0;
    const double bottomPad = 8.0;
    final double usableHeight = size.height - topPad - bottomPad;

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final normalizedY = (points[i].revenueIdr / effectiveMax).clamp(0.0, 1.0);
      final y = (size.height - bottomPad) - (normalizedY * usableHeight);
      offsets.add(Offset(x, y));
    }

    final Path linePath = Path();
    linePath.moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final Path areaPath = Path.from(linePath);
    areaPath.lineTo(offsets.last.dx, size.height);
    areaPath.lineTo(offsets.first.dx, size.height);
    areaPath.close();

    final areaPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x4000A896),
          Color(0x0000A896),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = AppTheme.jadeTosca
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    final dotOuterPaint = Paint()
      ..color = AppTheme.jadeTosca
      ..style = PaintingStyle.fill;
    final dotInnerPaint = Paint()
      ..color = Colors.white
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

/// 8. Rekomendasi Keputusan AI (DSS) Widget untuk Dashboard
class _AiRecommendationsSection extends ConsumerWidget {
  const _AiRecommendationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.jadeTosca, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rekomendasi Keputusan AI',
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
            InkWell(
              onTap: () => context.push('/insights'),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Buka Modul DSS',
                      style: GoogleFonts.lexend(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.jadeTosca,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward_rounded, size: 13, color: AppTheme.jadeTosca),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Body Content
        insightsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => ShadCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: AppTheme.jadeTosca, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Decision Support System Siaga',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ketuk untuk melihat analisis Rule Engine, anomali stok, dan proyeksi.',
                        style: GoogleFonts.lexend(
                          fontSize: 11.5,
                          color: AppTheme.textMutedDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () => context.push('/insights'),
                  child: const Text('Buka'),
                ),
              ],
            ),
          ),
          data: (insights) {
            final activeInsights = insights.where((i) => i.status != 'dismissed').toList();

            if (activeInsights.isEmpty) {
              return ShadCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.jadeTosca.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.verified_outlined, color: AppTheme.jadeTosca, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sistem DSS Berjalan Optimal',
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tidak terdeteksi anomali kritis atau penumpukan bahan baku.',
                            style: GoogleFonts.lexend(
                              fontSize: 11.5,
                              color: AppTheme.textMutedDark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: () => context.push('/insights'),
                      child: const Text('Detail'),
                    ),
                  ],
                ),
              );
            }

            final displayList = activeInsights.take(2).toList();
            return Column(
              children: [
                ...displayList.map((item) {
                  final isCrit = item.isCritical;
                  final isWarn = item.isWarning;
                  final badgeColor = isCrit
                      ? AppTheme.dangerRed
                      : (isWarn ? const Color(0xFFF59E0B) : AppTheme.jadeTosca);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => context.push('/insights'),
                      borderRadius: BorderRadius.circular(8),
                      child: ShadCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ShadBadge.secondary(
                                  backgroundColor: badgeColor.withValues(alpha: 0.15),
                                  foregroundColor: badgeColor,
                                  child: Text(
                                    isCrit ? 'Kritis' : (isWarn ? 'Peringatan' : 'Rekomendasi'),
                                    style: GoogleFonts.lexend(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: GoogleFonts.lexend(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimaryDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: AppTheme.textMutedDark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.message,
                              style: GoogleFonts.lexend(
                                fontSize: 11.5,
                                color: AppTheme.textMutedDark,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.recommendation.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkCardSurfaceElevated,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.darkCardBorder,
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.lightbulb_rounded,
                                      size: 13,
                                      color: AppTheme.jadeTosca,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.recommendation,
                                        style: GoogleFonts.lexend(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.jadeTosca,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}
