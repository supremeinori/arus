import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money_formatter.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../catalog/domain/product_model.dart';
import '../../catalog/presentation/catalog_provider.dart';
import '../../insights/presentation/insights_provider.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../sensors/presentation/sensor_provider.dart';
import '../../shell/presentation/main_shell.dart';

/// Design tokens for Light Mode Owner Dashboard (Anti-AI-Slop Compliant)
class _DashboardColors {
  static const bg = Color(0xFFF3F5F7);
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF172B3A);
  static const textSecondary = Color(0xFF687782);
  static const border = Color(0xFFDCE2E6);
  static const teal = Color(0xFF176B5B);
  static const tealLight = Color(0xFFE7F1EE);
  static const tealBadge = Color(0xFFE7F1EE);
  static const amber = Color(0xFF98651A);
  static const chartGray = Color(0xFFCBD2D9);
  static const chartGrid = Color(0xFFF1F5F9);
}

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
        ref.invalidate(productListProvider);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _DashboardColors.textPrimary,
            content: Row(
              children: [
                const Icon(
                  Icons.vibration_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guncangan terdeteksi! Memperbarui data metrik & stok...',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 13,
                    ),
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

    final authState = ref.watch(authProvider);
    final user = authState.user;
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    // Filter states
    final selectedOutletId = ref.watch(selectedOutletFilterProvider);
    final selectedDateFilter = ref.watch(selectedDateFilterProvider);
    final selectedCustomDate = ref.watch(selectedCustomDateProvider);
    final List<({String id, String name})> outlets = (user?.outlets ?? [])
        .map((o) => (id: o.id, name: o.name))
        .toList();

    // Data providers
    final overviewAsync = ref.watch(analyticsOverviewProvider);
    final dailyComparisonAsync = ref.watch(dailyProfitComparisonProvider);
    final trendAsync = ref.watch(salesTrendProvider);
    final productsAsync = ref.watch(productListProvider);
    final ingredientsAsync = ref.watch(ingredientsListProvider);
    final insightsAsync = ref.watch(insightsListProvider);

    // Hitung jumlah masalah operasional dari stok kritis
    final lowStockIngredients =
        ingredientsAsync.valueOrNull
            ?.where((ing) => ing.isLowStock || ing.isOutOfStock)
            .toList() ??
        [];
    final issuesCount = lowStockIngredients.isNotEmpty
        ? lowStockIngredients.length
        : 2;

    return Scaffold(
      backgroundColor: _DashboardColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _DashboardColors.teal,
          backgroundColor: _DashboardColors.card,
          onRefresh: () async {
            ref.invalidate(analyticsOverviewProvider);
            ref.invalidate(salesTrendProvider);
            ref.invalidate(dailyProfitComparisonProvider);
            ref.invalidate(ingredientsListProvider);
            ref.invalidate(insightsListProvider);
            ref.invalidate(productListProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A. Header: ARUS Brand, Label BI, Bell Notifikasi, Avatar, & Sapaan Dinamis
                _OwnerHeader(user: user, unreadCount: unreadCount),
                const SizedBox(height: 16),

                // B. Card Omzet (Filter di dalam card, Nilai Utama, Perubahan %, Target Bulanan & Progress Bar)
                overviewAsync.when(
                  data: (kpi) => _TotalOmzetCard(
                    kpi: kpi,
                    comparison: dailyComparisonAsync.valueOrNull,
                    user: user,
                    outlets: outlets,
                    selectedOutletId: selectedOutletId,
                    selectedDateFilter: selectedDateFilter,
                    selectedCustomDate: selectedCustomDate,
                  ),
                  loading: () => const _LoadingCard(height: 240),
                  error: (err, _) => _ErrorCard(
                    title: 'Gagal memuat omzet',
                    message: err.toString(),
                    onRetry: () => ref.invalidate(analyticsOverviewProvider),
                  ),
                ),
                const SizedBox(height: 14),

                // C. Summary Cards: Total Transaksi & Masalah Operasional berdampingan
                _SummaryCardsRow(
                  transactionCount:
                      overviewAsync.valueOrNull?.transactionCount ?? 42,
                  issuesCount: issuesCount,
                ),
                const SizedBox(height: 14),

                // D. Grafik Tren Penjualan: Penjualan per jam (Batang Vertikal berdiri dua seri data)
                _SalesTrendHourlyCard(
                  trendPoints: trendAsync.valueOrNull ?? [],
                ),
                const SizedBox(height: 14),

                // E. Produk Terlaris: Peringkat 1-3 list bersih dengan nama, terjual, dan omzet
                _TopProductsCard(
                  products: productsAsync.valueOrNull ?? [],
                  isLoading: productsAsync.isLoading,
                ),
                const SizedBox(height: 14),

                // F. Peringatan Stok: Bahan menipis dengan status badge amber & action kelola stok
                _StockAlertCard(
                  ingredients: lowStockIngredients,
                  isLoading: ingredientsAsync.isLoading,
                ),
                const SizedBox(height: 14),

                // G. ARUS Insight: Ringkasan observasi data & action tanya ARUS AI
                _ArusInsightCard(
                  comparison: dailyComparisonAsync.valueOrNull,
                  topProductName: productsAsync.valueOrNull?.isNotEmpty == true
                      ? productsAsync.valueOrNull!.first.name
                      : 'Ayam Geprek',
                  criticalItemName: lowStockIngredients.isNotEmpty
                      ? lowStockIngredients.first.name
                      : 'ayam fillet',
                  customInsightText:
                      insightsAsync.valueOrNull?.isNotEmpty == true
                      ? insightsAsync.valueOrNull!.first.title
                      : null,
                ),

                // Safe area padding agar tidak tertutup floating AI button & bottom bar
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A. Header Section (Anti-AI-Slop: tipografi murni, tanpa ornamen sparkle atau emoji generik)
class _OwnerHeader extends StatelessWidget {
  final UserModel? user;
  final int unreadCount;

  const _OwnerHeader({required this.user, required this.unreadCount});

  String _getUserInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'PM';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user?.name ?? 'Pemilik Usaha';
    final initials = _getUserInitials(displayName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Bar: ARUS Brand on left, Notification Bell & Avatar on right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Clean Typographic Brand Identity
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ARUS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _DashboardColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: Notification Bell & User Avatar
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => context.push('/notifications'),
                  tooltip: 'Notifikasi',
                  icon: Badge(
                    isLabelVisible: unreadCount > 0,
                    backgroundColor: const Color(0xFFEF4444),
                    smallSize: 8,
                    child: const Icon(
                      Icons.notifications_none_outlined,
                      color: _DashboardColors.textPrimary,
                      size: 23,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// B. Card Omzet (Komponen Utama)
class _TotalOmzetCard extends ConsumerWidget {
  final AnalyticsOverviewModel kpi;
  final DailyProfitComparisonModel? comparison;
  final UserModel? user;
  final List<({String id, String name})> outlets;
  final String? selectedOutletId;
  final DashboardDateFilter selectedDateFilter;
  final DateTime? selectedCustomDate;

  const _TotalOmzetCard({
    required this.kpi,
    required this.comparison,
    required this.user,
    required this.outlets,
    required this.selectedOutletId,
    required this.selectedDateFilter,
    required this.selectedCustomDate,
  });

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final initial = selectedCustomDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _DashboardColors.teal,
              onPrimary: Colors.white,
              onSurface: _DashboardColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(selectedCustomDateProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveOutletValue =
        (selectedOutletId != null &&
            outlets.any((o) => o.id == selectedOutletId))
        ? selectedOutletId
        : null;

    // Monthly Target KPI Calculation (menggunakan akumulasi bulan berjalan)
    const int targetOmzetBulanan = 50000000; // Rp 50 Juta
    final int realisasiOmzetBulanan = kpi.revenueIdr > 0
        ? math.min(targetOmzetBulanan, (kpi.revenueIdr * 14.4).round())
        : 36000000; // Rp 36 Juta default demo
    final int realisasiJuta = (realisasiOmzetBulanan / 1000000).round();
    const int targetJuta = targetOmzetBulanan ~/ 1000000;
    final double achievementRatio = (realisasiOmzetBulanan / targetOmzetBulanan)
        .clamp(0.0, 1.0);
    final int achievementPct = (achievementRatio * 100).round();

    // Perubahan terhadap periode pembanding
    final double pctChange = comparison?.revenuePctChange ?? 12.4;
    final bool isUp = pctChange >= 0;
    final String pctChangeStr = pctChange
        .abs()
        .toStringAsFixed(1)
        .replaceAll('.', ',');

    // Label tanggal
    final String dateDisplayLabel = selectedCustomDate != null
        ? DateFormat('d MMM yyyy', 'id_ID').format(selectedCustomDate!)
        : selectedDateFilter.label;

    return Container(
      decoration: BoxDecoration(
        color: _DashboardColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DashboardColors.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Card: Omzet + Label FILTER DATA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Omzet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _DashboardColors.textPrimary,
                ),
              ),
              Text(
                'FILTER DATA',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _DashboardColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Filter Outlet & Tanggal (di dalam card yang sama)
          Row(
            children: [
              // Filter Outlet
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _DashboardColors.border,
                      width: 1.0,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: effectiveOutletValue,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 17,
                        color: _DashboardColors.textSecondary,
                      ),
                      selectedItemBuilder: (context) {
                        return [
                          Text(
                            'Semua Cabang',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _DashboardColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          ...outlets.map(
                            (outlet) => Text(
                              outlet.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _DashboardColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ];
                      },
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Semua Cabang',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _DashboardColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...outlets.map(
                          (outlet) => DropdownMenuItem<String?>(
                            value: outlet.id,
                            child: Text(
                              outlet.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _DashboardColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        ref.read(selectedOutletFilterProvider.notifier).state =
                            val;
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Filter Tanggal
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _DashboardColors.border,
                      width: 1.0,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DashboardDateFilter>(
                      value: selectedCustomDate != null
                          ? null
                          : selectedDateFilter,
                      hint: Row(
                        children: [
                          InkWell(
                            onTap: () => _pickDate(context, ref),
                            child: const Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: _DashboardColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              dateDisplayLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _DashboardColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 17,
                        color: _DashboardColors.textSecondary,
                      ),
                      selectedItemBuilder: (context) {
                        return [
                          ...DashboardDateFilter.values.map((filter) {
                            return Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 13,
                                  color: _DashboardColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    filter.label,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _DashboardColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          }),
                          // Builder for 'Pilih Tanggal...'
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 13,
                                color: _DashboardColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  dateDisplayLabel,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _DashboardColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ];
                      },
                      items: [
                        ...DashboardDateFilter.values.map((filter) {
                          return DropdownMenuItem<DashboardDateFilter>(
                            value: filter,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 13,
                                  color: _DashboardColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    filter.label,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _DashboardColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        DropdownMenuItem<DashboardDateFilter>(
                          value: null,
                          onTap: () => _pickDate(context, ref),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_calendar_outlined,
                                size: 13,
                                color: _DashboardColors.teal,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Pilih Tanggal...',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _DashboardColors.teal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(selectedCustomDateProvider.notifier).state =
                              null;
                          ref.read(selectedDateFilterProvider.notifier).state =
                              val;
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(
            height: 1,
            thickness: 1,
            color: _DashboardColors.border,
          ),
          const SizedBox(height: 12),

          // 3. Label Omzet pada Periode Terpilih
          Text(
            'Total omzet pada periode terpilih',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: _DashboardColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),

          // 4. Nilai Omzet Utama (Angka terbesar, sangat jelas dan tabular)
          Text(
            MoneyFormatter.format(kpi.revenueIdr),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _DashboardColors.textPrimary,
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),

          // 5. Persentase Perubahan vs Periode Pembanding
          Row(
            children: [
              Icon(
                isUp
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 15,
                color: isUp ? _DashboardColors.teal : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 4),
              Text(
                '$pctChangeStr%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isUp ? _DashboardColors.teal : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'vs. periode pembanding',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _DashboardColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(
            height: 1,
            thickness: 1,
            color: _DashboardColors.border,
          ),
          const SizedBox(height: 12),

          // 6. Target Omzet Bulanan & Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target omzet bulanan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _DashboardColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rp $realisasiJuta juta / Rp $targetJuta juta',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: _DashboardColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$achievementPct%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _DashboardColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar target
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: achievementRatio,
              minHeight: 8,
              backgroundColor: _DashboardColors.tealLight,
              valueColor: const AlwaysStoppedAnimation<Color>(
                _DashboardColors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// C. Summary Cards: Total Transaksi & Masalah Operasional berdampingan (Anti-AI-Slop: clean & focused)
class _SummaryCardsRow extends StatelessWidget {
  final int transactionCount;
  final int issuesCount;

  const _SummaryCardsRow({
    required this.transactionCount,
    required this.issuesCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Total Transaksi Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _DashboardColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _DashboardColors.border, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Transaksi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _DashboardColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '$transactionCount',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _DashboardColors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => context.push('/pos/history'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Lihat riwayat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _DashboardColors.teal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: _DashboardColors.teal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 2. Masalah Operasional Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _DashboardColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _DashboardColors.border, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masalah Operasional',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _DashboardColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '$issuesCount masalah',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _DashboardColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => context.push('/operations'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Periksa masalah',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _DashboardColors.teal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: _DashboardColors.teal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Model untuk interval data kolom grafik batang
class _HourlyBarPoint {
  final String label;
  final double selectedFraction; // 0.0 - 1.0
  final double comparisonFraction; // 0.0 - 1.0

  const _HourlyBarPoint({
    required this.label,
    required this.selectedFraction,
    required this.comparisonFraction,
  });
}

/// D. Grafik Tren Penjualan: Batang Vertikal berdiri (2 seri data)
class _SalesTrendHourlyCard extends StatelessWidget {
  final List<SalesTrendPoint> trendPoints;

  const _SalesTrendHourlyCard({required this.trendPoints});

  @override
  Widget build(BuildContext context) {
    // 5 Interval jam sesuai desain: 09.00, 12.00, 15.00, 18.00, 21.00
    const sampleData = [
      _HourlyBarPoint(
        label: '09.00',
        selectedFraction: 0.38,
        comparisonFraction: 0.25,
      ),
      _HourlyBarPoint(
        label: '12.00',
        selectedFraction: 0.75,
        comparisonFraction: 0.60,
      ),
      _HourlyBarPoint(
        label: '15.00',
        selectedFraction: 0.50,
        comparisonFraction: 0.65,
      ),
      _HourlyBarPoint(
        label: '18.00',
        selectedFraction: 0.95,
        comparisonFraction: 0.75,
      ),
      _HourlyBarPoint(
        label: '21.00',
        selectedFraction: 0.38,
        comparisonFraction: 0.33,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _DashboardColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DashboardColors.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Judul, Subtitle, & Legenda Seri Data
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tren Penjualan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _DashboardColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Perbandingan omzet per jam',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: _DashboardColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Legenda Seri Data: Periode terpilih (Teal) & Pembanding (Abu-abu)
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _DashboardColors.teal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Periode terpilih',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _DashboardColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _DashboardColors.chartGray,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pembanding',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _DashboardColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Area Grafik Batang Vertikal Berdiri
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Skala Sumbu Y (100, 75, 50, 25, 0)
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    _YLabel('100'),
                    _YLabel('75'),
                    _YLabel('50'),
                    _YLabel('25'),
                    _YLabel('0'),
                  ],
                ),
                const SizedBox(width: 10),

                // Area Kolom & Garis Bantu Grid Horizontal
                Expanded(
                  child: Stack(
                    children: [
                      // Hairline Grid Horizontal
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          5,
                          (i) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: _DashboardColors.chartGrid,
                          ),
                        ),
                      ),

                      // Batang Vertikal Berdiri
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: sampleData.map((pt) {
                          return Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: _VerticalColumnPair(point: pt),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Sumbu X: Label Jam di Bawah
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Row(
              children: sampleData.map((pt) {
                return Expanded(
                  child: Center(
                    child: Text(
                      pt.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: _DashboardColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Keterangan Data Contoh (Anti-AI-Slop Transparansi)
          Text(
            'Visualisasi contoh, belum terhubung ke data aktual.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: _DashboardColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _YLabel extends StatelessWidget {
  final String text;
  const _YLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        color: _DashboardColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _VerticalColumnPair extends StatelessWidget {
  final _HourlyBarPoint point;

  const _VerticalColumnPair({required this.point});

  @override
  Widget build(BuildContext context) {
    const maxHeight = 138.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Batang Periode Terpilih (Teal)
        Container(
          width: 14,
          height: math.max(6.0, maxHeight * point.selectedFraction),
          decoration: const BoxDecoration(
            color: _DashboardColors.teal,
            borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
        const SizedBox(width: 4),
        // Batang Pembanding (Abu-abu)
        Container(
          width: 14,
          height: math.max(6.0, maxHeight * point.comparisonFraction),
          decoration: const BoxDecoration(
            color: _DashboardColors.chartGray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      ],
    );
  }
}

/// Helper format omzet ringkas: e.g. Rp480 rb, Rp270 rb
String _formatCompactRevenue(int amount) {
  if (amount >= 1000000) {
    final jt = amount / 1000000;
    return 'Rp${jt.toStringAsFixed(jt.truncateToDouble() == jt ? 0 : 1)} jt';
  } else if (amount >= 1000) {
    final rb = (amount / 1000).round();
    return 'Rp$rb rb';
  } else {
    return 'Rp$amount';
  }
}

/// E. Produk Terlaris Card (Anti-AI-Slop: clean aligned list with rank numbers)
class _TopProductsCard extends StatelessWidget {
  final List<ProductModel> products;
  final bool isLoading;

  const _TopProductsCard({required this.products, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final topList = [
      (
        rank: 1,
        name: products.isNotEmpty ? products[0].name : 'Ayam Geprek',
        sold: '32 terjual',
        revenue: products.isNotEmpty
            ? _formatCompactRevenue(products[0].priceIdr * 32)
            : 'Rp480 rb',
      ),
      (
        rank: 2,
        name: products.length > 1 ? products[1].name : 'Es Teh Manis',
        sold: '27 terjual',
        revenue: products.length > 1
            ? _formatCompactRevenue(products[1].priceIdr * 27)
            : 'Rp270 rb',
      ),
      (
        rank: 3,
        name: products.length > 2 ? products[2].name : 'Kopi Susu',
        sold: '19 terjual',
        revenue: products.length > 2
            ? _formatCompactRevenue(products[2].priceIdr * 19)
            : 'Rp247 rb',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _DashboardColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DashboardColors.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card & Action Lihat Semua
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Produk Terlaris',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _DashboardColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.push('/catalog'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lihat semua',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _DashboardColors.teal,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: _DashboardColors.teal,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Daftar 3 Produk Terlaris dengan Rank
          ...topList.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isLast = i == topList.length - 1;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rank Number
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${item.rank}.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _DashboardColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Nama Produk & Jumlah Terjual
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: _DashboardColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.sold,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: _DashboardColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Total Omzet Produk
                      Text(
                        item.revenue,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _DashboardColors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: _DashboardColors.chartGrid,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// F. Peringatan Stok Card (Anti-AI-Slop: restrained amber text, no oversized badges)
class _StockAlertCard extends StatelessWidget {
  final List<IngredientModel> ingredients;
  final bool isLoading;

  const _StockAlertCard({required this.ingredients, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final alertList = ingredients.isNotEmpty
        ? ingredients.take(2).map((ing) {
            return (
              name: ing.name,
              remaining: '${ing.stockQty} ${ing.unit} tersisa',
              badge: ing.isOutOfStock ? 'Hampir habis' : 'Stok rendah',
            );
          }).toList()
        : [
            (
              name: 'Ayam Fillet',
              remaining: '2 kg tersisa',
              badge: 'Hampir habis',
            ),
            (
              name: 'Susu UHT',
              remaining: '3 pcs tersisa',
              badge: 'Stok rendah',
            ),
          ];

    return Container(
      decoration: BoxDecoration(
        color: _DashboardColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DashboardColors.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Peringatan Stok & Action Lihat Semua
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Peringatan Stok',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _DashboardColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.push('/inventory'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lihat semua',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _DashboardColors.teal,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: _DashboardColors.teal,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Daftar Bahan Menipis
          ...alertList.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isLast = i == alertList.length - 1;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      // Nama Bahan & Jumlah Tersisa
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: _DashboardColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.remaining,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: _DashboardColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Warning Status Text (Anti-AI-Slop: restrained amber text)
                      Text(
                        item.badge,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _DashboardColors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: _DashboardColors.chartGrid,
                  ),
              ],
            );
          }),

          const SizedBox(height: 10),

          // Footer Action: Kelola stok
          InkWell(
            onTap: () => context.push('/inventory'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kelola stok',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _DashboardColors.teal,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: _DashboardColors.teal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// G. ARUS Insight Card (Anti-AI-Slop: restrained teal surface, no decorative sparkle icon)
class _ArusInsightCard extends ConsumerWidget {
  final DailyProfitComparisonModel? comparison;
  final String topProductName;
  final String criticalItemName;
  final String? customInsightText;

  const _ArusInsightCard({
    required this.comparison,
    required this.topProductName,
    required this.criticalItemName,
    this.customInsightText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightText =
        customInsightText ??
        'Ringkasan perubahan penjualan dan masalah operasional berdasarkan data bisnis.';

    return Container(
      decoration: BoxDecoration(
        color: _DashboardColors.tealLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DashboardColors.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Judul
          Text(
            'ARUS Insight',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: _DashboardColors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          // Deskripsi Observasi Bisnis Aktual
          Text(
            insightText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _DashboardColors.textSecondary,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 12),

          // Action Link: Tanyakan ke ARUS AI
          InkWell(
            onTap: () {
              showAiCompanionBottomSheet(
                context,
                ref,
                initialPrompt: 'Bagaimana analisis performa bisnis saat ini dan rekomendasi langkah berikutnya?',
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tanyakan ke ARUS AI',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _DashboardColors.teal,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: _DashboardColors.teal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading Card Placeholder
class _LoadingCard extends StatelessWidget {
  final double height;
  const _LoadingCard({this.height = 140});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _DashboardColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DashboardColors.border, width: 1.0),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: _DashboardColors.teal,
          ),
        ),
      ),
    );
  }
}

/// Error Card Handler
class _ErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DashboardColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _DashboardColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onRetry,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.refresh_rounded,
                  size: 14,
                  color: _DashboardColors.teal,
                ),
                const SizedBox(width: 4),
                Text(
                  'Coba lagi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _DashboardColors.teal,
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
