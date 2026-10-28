import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/dashboard_filter_sheet.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../insights/presentation/insights_provider.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../sensors/presentation/sensor_provider.dart';
import '../../../core/utils/timezone_converter.dart';
import '../../settings/presentation/currency_provider.dart';
import '../../settings/presentation/widgets/time_settings_section.dart';
import '../../shell/presentation/main_shell.dart';

/// Design tokens for Light Mode Owner Dashboard (Wireframe & Anti-AI-Slop Compliant)
class _DashboardColors {
  static const bg = AppTheme.lightBackground;
  static const card = AppTheme.lightCardSurface;
  static const textPrimary = AppTheme.textPrimaryLight; // Slate-900 Navy
  static const textSecondary = AppTheme.textSecondaryMid; // Slate-600
  static const textMuted = AppTheme.textMutedLight; // Slate-500
  static const border = AppTheme.lightCardBorder; // Hairline 1px Slate-200
  static const teal = AppTheme.jadeTosca; // Modern Jade Tosca
  static const tealLight = Color(0xFFE6F6F4);
  static const amber = AppTheme.warningAmberStrong; // Warm Amber
  static const amberLight = Color(0xFFFEF3C7);
  static const danger = AppTheme.dangerRed;
  static const chartGrid = AppTheme.lightCardSurfaceElevated;
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
        ref.invalidate(leaderboardProvider);
        ref.invalidate(notificationsListProvider);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _DashboardColors.textPrimary,
            content: Row(
              children: [
                const Icon(
                  Icons.vibration_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guncangan terdeteksi! Memperbarui data...',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
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
    // Revisi 22 Okt 2026: tab Beranda kini dipakai kasir juga (Ringkasan Shift dibuang),
    // jadi Outlet terkunci untuk semua role selain owner.
    final isOutletLocked = user?.role != UserRole.owner;

    // API TERSEDIA: GET /api/notifications (Unread notification count)
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    // Filter states (Cabang & Hari)
    // Untuk role manager: cabang terkunci pada cabang yang di-assign oleh owner
    final selectedOutletId = isOutletLocked && (user?.outlets.isNotEmpty ?? false)
        ? user!.outlets.first.id
        : ref.watch(selectedOutletFilterProvider);
    final selectedDateFilter = ref.watch(selectedDateFilterProvider);
    final selectedCustomDate = ref.watch(selectedCustomDateProvider);
    final List<({String id, String name})> outlets = (user?.outlets ?? [])
        .map((o) => (id: o.id, name: o.name))
        .toList();

    // Data providers terhubung ke API backend
    // API TERSEDIA: GET /api/analytics/overview (Omzet & Total Transaksi)
    final overviewAsync = ref.watch(analyticsOverviewProvider);
    // API TERSEDIA: GET /api/analytics/sales-trend (Grafik Tren Penjualan)
    final trendAsync = ref.watch(salesTrendProvider);
    // API TERSEDIA: GET /api/analytics/leaderboard (Menu Terlaris dari DB)
    final leaderboardAsync = ref.watch(leaderboardProvider);
    // API TERSEDIA: GET /api/inventory/ingredients (Data Bahan & Stok Kritis)
    final ingredientsAsync = ref.watch(ingredientsListProvider);

    // ========================================================================
    // TODO: [BELUM ADA API SPESIFIK] Endpoint Agregasi Masalah Operasional
    // Rekomendasi API Backend yang perlu dibuat:
    //   GET /api/analytics/issues?outlet_id=...
    // Response ideal:
    //   { "total_issues": 2, "critical_stock": 2, "anomalies": 0 }
    //
    // Implementasi saat ini (Data Asli):
    // Dihitung langsung dari jumlah bahan stok kritis/habis (low/out of stock)
    // yang bersumber dari API inventory riil tanpa angka dummy mock.
    // ========================================================================
    final lowStockIngredients =
        ingredientsAsync.valueOrNull
            ?.where((ing) => ing.isLowStock || ing.isOutOfStock)
            .toList() ??
        [];
    final issuesCount = lowStockIngredients.length;

    // Scroll controller untuk melompat ke section masalah / peringatan
    final ScrollController scrollController = ScrollController();

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
            ref.invalidate(leaderboardProvider);
            ref.invalidate(notificationsListProvider);
          },
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header (Wireframe: Arus + sapaan .......... (🔔))
                // API TERSEDIA: GET /api/notifications (badge unread)
                _WireframeHeader(
                  unreadCount: unreadCount,
                  greeting: TimezoneConverter.greeting(
                    ref.watch(settingsClockProvider),
                    ref.watch(displayTimezoneProvider),
                  ),
                ),
                const SizedBox(height: 14),

                // Banner Status Offline atau Pending Sync
                if (overviewAsync.valueOrNull?.isOffline == true) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 20, color: Color(0xFFB45309)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mode Offline',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (overviewAsync.valueOrNull?.pendingCount ?? 0) > 0
                                    ? 'Menampilkan data lokal. Ada ${overviewAsync.valueOrNull!.pendingCount} transaksi menunggu sinkronisasi.'
                                    : 'Menampilkan data lokal perangkat. Data server mungkin belum mencakup perubahan terbaru.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if ((overviewAsync.valueOrNull?.pendingCount ?? 0) > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_problem_rounded, size: 20, color: Color(0xFFB45309)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ada ${overviewAsync.valueOrNull!.pendingCount} transaksi lokal menunggu sinkronisasi ke server.',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 2. Hero Card: Omzet + Filter Button (Wireframe: Omzet, Rp.X, Di Cabang pada Hari)
                // API TERSEDIA: GET /api/analytics/overview?outlet_id=...&from=...&to=...
                // Menggunakan data asli riil dari response API.
                overviewAsync.when(
                  loading: () => const _LoadingCard(height: 140),
                  error: (err, _) => _HeroOmzetCard(
                    revenueIdr: 0,
                    outlets: outlets,
                    selectedOutletId: selectedOutletId,
                    selectedDateFilter: selectedDateFilter,
                    selectedCustomDate: selectedCustomDate,
                    errorMessage: 'Gagal memuat omzet dari server',
                    onRetry: () => ref.invalidate(analyticsOverviewProvider),
                    outletLocked: isOutletLocked,
                  ),
                  data: (kpi) => _HeroOmzetCard(
                    revenueIdr: kpi.revenueIdr, // Data asli dari API
                    outlets: outlets,
                    selectedOutletId: selectedOutletId,
                    selectedDateFilter: selectedDateFilter,
                    selectedCustomDate: selectedCustomDate,
                    outletLocked: isOutletLocked,
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Row of 2 KPI Cards: Transaksi & Masalah (Wireframe)
                // Transaksi -> API TERSEDIA: GET /api/analytics/overview (transaction_count)
                // Masalah   -> Dihitung dari GET /api/inventory/ingredients
                overviewAsync.when(
                  loading: () => const _LoadingCard(height: 96),
                  error: (_, _) => _KpiRowSection(
                    transactionCount: 0,
                    issuesCount: issuesCount,
                    onViewHistory: () => context.push('/pos/history?scope=dashboard'),
                    onViewIssues: () {
                      scrollController.animateTo(
                        scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );
                    },
                  ),
                  data: (kpi) => _KpiRowSection(
                    transactionCount: kpi.transactionCount, // Data asli dari API
                    issuesCount: issuesCount,
                    onViewHistory: () => context.push('/pos/history?scope=dashboard'),
                    onViewIssues: () {
                      scrollController.animateTo(
                        scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Section: Terlaris (Wireframe: Terlaris ........ Lihat Semua)
                // API TERSEDIA: GET /api/analytics/leaderboard?outlet_id=...&from=...&to=...&limit=3
                // Peringkat dihitung backend dari transaction_items + transactions
                // (status completed), bukan dari daftar katalog maupun data lokal.
                _TerlarisCard(
                  products: leaderboardAsync.valueOrNull ?? [],
                  isLoading: leaderboardAsync.isLoading,
                  onViewAll: () => context.push('/leaderboard'),
                ),
                const SizedBox(height: 12),

                // 5. Section: Tren (Wireframe: Tren)
                // API TERSEDIA: GET /api/analytics/sales-trend?outlet_id=...&days=7
                // Menampilkan grafik tren data asli dari API.
                _TrenCard(
                  trendPoints: trendAsync.valueOrNull ?? [],
                  isLoading: trendAsync.isLoading,
                ),
                const SizedBox(height: 12),

                // 6. Section: Peringatan (Wireframe: Peringatan ........ Lihat Semua ..... ->)
                // API TERSEDIA: GET /api/inventory/ingredients?outlet_id=...
                // Menampilkan bahan stok kritis/habis yang sesungguhnya.
                _PeringatanCard(
                  ingredients: lowStockIngredients,
                  isLoading: ingredientsAsync.isLoading,
                ),

                // Safe area padding agar tidak tertutup floating AI button & bottom bar
                const SizedBox(height: 84),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 1. HEADER (Wireframe: [logo] Arus, Bell Icon)
// API TERSEDIA: GET /api/notifications (unread notification count)
// ============================================================================
class _WireframeHeader extends StatelessWidget {
  final int unreadCount;
  final String greeting;

  const _WireframeHeader({required this.unreadCount, required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Logo + Wordmark "Arus" + sapaan pemilik akun
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/app_logo_mark.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Ar'),
                        TextSpan(
                          text: 'us',
                          style: GoogleFonts.inter(color: _DashboardColors.teal),
                        ),
                      ],
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _DashboardColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    greeting,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: _DashboardColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),

          // Lonceng Notifikasi (API: GET /api/notifications)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/notifications'),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _DashboardColors.border, width: 1.0),
              ),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: _DashboardColors.textPrimary,
                    size: 20,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _DashboardColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. HERO CARD: OMZET & FILTER (Wireframe: Omzet, Rp.X, Di Cabang pada Hari)
// API TERSEDIA: GET /api/analytics/overview (revenue_idr)
// ============================================================================
class _HeroOmzetCard extends ConsumerWidget {
  final int revenueIdr;
  final List<({String id, String name})> outlets;
  final String? selectedOutletId;
  final DashboardDateFilter selectedDateFilter;
  final DateTime? selectedCustomDate;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool outletLocked;

  const _HeroOmzetCard({
    required this.revenueIdr,
    required this.outlets,
    required this.selectedOutletId,
    required this.selectedDateFilter,
    required this.selectedCustomDate,
    this.errorMessage,
    this.onRetry,
    this.outletLocked = false,
  });

  /// Format omzet mengikuti mata uang tampilan milik pengguna.
  String _formatMoney(BuildContext context, WidgetRef ref, int amount) {
    final formatted = ref.money(amount);
    // Wireframe format: "Rp.17.000.000" / "Rp.2.500.000"
    return MoneyFormatter.dottedIdrSymbol(formatted);
  }

  void _openFilterDialog(BuildContext context, WidgetRef ref) {
    showDashboardFilterSheet(
      context,
      outlets: outlets,
      selectedOutletId: selectedOutletId,
      selectedDateFilter: selectedDateFilter,
      selectedCustomDate: selectedCustomDate,
      isManager: outletLocked,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nama Cabang
    String branchLabel = 'Semua Cabang';
    if (outletLocked) {
      if (selectedOutletId != null) {
        final found = outlets.where((o) => o.id == selectedOutletId);
        if (found.isNotEmpty) {
          branchLabel = found.first.name;
        } else if (outlets.isNotEmpty) {
          branchLabel = outlets.first.name;
        }
      } else if (outlets.isNotEmpty) {
        branchLabel = outlets.first.name;
      } else {
        branchLabel = 'Cabang Saya';
      }
    } else if (selectedOutletId != null) {
      final found = outlets.where((o) => o.id == selectedOutletId);
      if (found.isNotEmpty) {
        branchLabel = found.first.name;
      }
    }

    // Nama Hari / Periode
    final String dayLabel = selectedCustomDate != null
        ? DateFormat('d MMM yyyy', 'id_ID').format(selectedCustomDate!)
        : selectedDateFilter.label;

    return Container(
      decoration: BoxDecoration(
        color: _DashboardColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DashboardColors.border, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label "Omzet" (Inter) + penanda periode aktif
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Omzet',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: _DashboardColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (errorMessage != null && onRetry != null)
                InkWell(
                  onTap: onRetry,
                  child: Row(
                    children: [
                      const Icon(Icons.refresh_rounded, size: 14, color: _DashboardColors.danger),
                      const SizedBox(width: 4),
                      Text(
                        'Coba lagi',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _DashboardColors.danger,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _DashboardColors.tealLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dayLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _DashboardColors.teal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Angka Besar Omzet (LEXEND w800) - Data riil dari API
          Text(
            _formatMoney(context, ref, revenueIdr),
            style: GoogleFonts.lexend(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _DashboardColors.textPrimary,
              letterSpacing: -0.6,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Baris Bawah: Di "Nama Cabang" pada "Pilihan Hari" + Filter Icon
          Row(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // DropdownButton transparan untuk direct selection & test runner compatibility (Hanya untuk Owner)
                    if (!outletLocked)
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.001,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: selectedOutletId,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Semua Cabang'),
                                ),
                                ...outlets.map(
                                  (o) => DropdownMenuItem<String?>(
                                    value: o.id,
                                    child: Text(o.name),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                ref.read(selectedOutletFilterProvider.notifier).state = val;
                              },
                            ),
                          ),
                        ),
                      ),
                    IgnorePointer(
                      child: Text(
                        'Di "$branchLabel" pada "$dayLabel".',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: _DashboardColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Tombol Kotak Filter (Funnel Icon)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openFilterDialog(context, ref),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.lightCardSurfaceElevated, // Slate-100
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _DashboardColors.border,
                      width: 1.0,
                    ),
                  ),
                  child: const Icon(
                    Icons.filter_alt_outlined,
                    size: 20,
                    color: _DashboardColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. ROW OF 2 KPI CARDS (Wireframe: Transaksi [N] & Masalah [M])
// Transaksi: API TERSEDIA (GET /api/analytics/overview -> transaction_count)
// Masalah:   TODO: Belum ada API agregasi khusus, saat ini dihitung dari stok kritis
// ============================================================================
class _KpiRowSection extends StatelessWidget {
  final int transactionCount;
  final int issuesCount;
  final VoidCallback onViewHistory;
  final VoidCallback onViewIssues;

  const _KpiRowSection({
    required this.transactionCount,
    required this.issuesCount,
    required this.onViewHistory,
    required this.onViewIssues,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Kartu Transaksi (Data Asli API)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _DashboardColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _DashboardColors.border, width: 1.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaksi',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _DashboardColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$transactionCount',
                  style: GoogleFonts.lexend(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _DashboardColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: onViewHistory,
                  child: Text(
                    'Lihat Transaksi',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _DashboardColors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Kartu Masalah (Dihitung dari stok bahan kritis / TODO API masalah agregat)
        // Revisi 22 Okt 2026: seluruh kartu bisa diketuk, bukan hanya teksnya.
        Expanded(
          child: Material(
            color: _DashboardColors.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onViewIssues,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _DashboardColors.border, width: 1.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Masalah',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _DashboardColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$issuesCount',
                      style: GoogleFonts.lexend(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: issuesCount > 0
                            ? _DashboardColors.amber
                            : _DashboardColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lihat Masalah',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _DashboardColors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 4. SECTION TERLARIS (Wireframe: Terlaris ...... Lihat Semua)
// API TERSEDIA: GET /api/analytics/leaderboard?outlet_id=...&from=...&to=...&limit=3
// Data berasal dari perhitungan backend (transaction_items + transactions),
// bukan dari daftar katalog produk.
// ============================================================================
class _TerlarisCard extends ConsumerWidget {
  final List<TopSellingProductModel> products;
  final bool isLoading;
  final VoidCallback onViewAll;

  const _TerlarisCard({
    required this.products,
    required this.isLoading,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topList = products.take(3).toList();

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
          // Header: Terlaris + Lihat Semua
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terlaris',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _DashboardColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: onViewAll,
                child: Text(
                  'Lihat Semua',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _DashboardColors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // List Menu Terlaris
          if (isLoading)
            const _SkeletonList(itemCount: 3, itemHeight: 48)
          else if (topList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Belum ada penjualan menu pada periode ini.',
                style: GoogleFonts.inter(
                  color: _DashboardColors.textMuted,
                  fontSize: 13,
                ),
              ),
            )
          else
            ...topList.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              final bool isLast = index == topList.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        // Badge Ranking
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: index == 0
                                ? _DashboardColors.tealLight
                                : AppTheme.lightCardSurfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '#${product.rank}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: index == 0
                                  ? _DashboardColors.teal
                                  : _DashboardColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Nama Menu
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.productName,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: _DashboardColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                product.categoryName,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: _DashboardColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Terjual & Omzet
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${product.quantitySold} terjual',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _DashboardColors.teal,
                              ),
                            ),
                            Text(
                              ref.money(product.totalRevenueIdr),
                              style: GoogleFonts.lexend(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _DashboardColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: _DashboardColors.chartGrid),
                ],
              );
            }),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. SECTION TREN (Wireframe: Tren)
// API TERSEDIA: GET /api/analytics/sales-trend?outlet_id=...&days=7
// ============================================================================
class _TrenCard extends StatelessWidget {
  final List<SalesTrendPoint> trendPoints;
  final bool isLoading;

  const _TrenCard({required this.trendPoints, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final points = trendPoints;
    final int maxRevenue = points.isNotEmpty
        ? points.map((p) => p.revenueIdr).reduce(math.max)
        : 0;

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
          // Header: Tren
          Text(
            'Tren',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _DashboardColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Visualisasi Grafik Bar Bersih (Clean Trend Bars)
          if (isLoading)
            const _SkeletonTrendBars()
          else if (points.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada data tren penjualan untuk periode ini.',
                  style: GoogleFonts.inter(
                    color: _DashboardColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: points.length > 10
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: points.map((point) {
                          final hasRevenue = point.revenueIdr > 0;
                          final ratio = maxRevenue > 0
                              ? (point.revenueIdr / maxRevenue)
                              : 0.0;
                          final barHeight = hasRevenue
                              ? math.max(12.0, ratio * 90.0)
                              : 4.0;
                          final isPeak = maxRevenue > 0 && point.revenueIdr == maxRevenue;

                          return SizedBox(
                            width: 28,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Bar
                                  Container(
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: isPeak
                                          ? _DashboardColors.teal
                                          : (hasRevenue
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Label Hari
                                  Text(
                                    point.date.length > 3
                                        ? point.date.substring(point.date.length - 2)
                                        : point.date,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: isPeak
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isPeak
                                          ? _DashboardColors.teal
                                          : _DashboardColors.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: points.map((point) {
                        final hasRevenue = point.revenueIdr > 0;
                        final ratio = maxRevenue > 0
                            ? (point.revenueIdr / maxRevenue)
                            : 0.0;
                        final barHeight = hasRevenue
                            ? math.max(12.0, ratio * 90.0)
                            : 4.0;
                        final isPeak = maxRevenue > 0 && point.revenueIdr == maxRevenue;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Bar
                                Container(
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: isPeak
                                        ? _DashboardColors.teal
                                        : (hasRevenue
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Label Hari
                                Text(
                                  point.date.length > 3
                                      ? point.date.substring(point.date.length - 2)
                                      : point.date,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: isPeak
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isPeak
                                        ? _DashboardColors.teal
                                        : _DashboardColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. SECTION PERINGATAN (Wireframe: Peringatan ...... Lihat Semua ..... ->)
// API TERSEDIA: GET /api/inventory/ingredients?outlet_id=...
// Menampilkan bahan dengan stok kritis/habis aktual tanpa dummy data.
// ============================================================================
class _PeringatanCard extends ConsumerWidget {
  final List<IngredientModel> ingredients;
  final bool isLoading;

  const _PeringatanCard({
    required this.ingredients,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertItems = ingredients.take(3).toList();

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
          // Header: Peringatan + Lihat Semua
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Peringatan',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _DashboardColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: () {
                  // Switch ke tab Analytics (index 2 untuk owner/manager)
                  ref.read(shellTabIndexProvider.notifier).state = 2;
                  // Switch ke tab "Radar Stok Habis" di dalam Analytics (index 1)
                  ref.read(analyticsActiveTabProvider.notifier).state = 1;
                },
                child: Text(
                  'Lihat Semua',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _DashboardColors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // List Peringatan Stok
          if (isLoading)
            const _SkeletonList(itemCount: 2, itemHeight: 52)
          else if (alertItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 20,
                    color: _DashboardColors.teal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Semua stok bahan dalam kondisi aman. Tidak ada peringatan kritis saat ini.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: _DashboardColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ...alertItems.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _DashboardColors.amberLight.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _DashboardColors.amber.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: _DashboardColors.amber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _DashboardColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Sisa ${item.stockQty} ${item.unit} (Min: ${item.reorderLevel} ${item.unit})',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: _DashboardColors.amber,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// SKELETON / LOADING HELPERS (Anti-Slop Wireframe Shimmer Placeholders)
// Mencegah frame tiup berulang yang membekukan test & memberikan UI tenang
// ============================================================================
class _LoadingCard extends StatelessWidget {
  final double height;
  const _LoadingCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _DashboardColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DashboardColors.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.lightCardBorder,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 180,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.lightCardSurfaceElevated,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const _SkeletonList({required this.itemCount, required this.itemHeight});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Container(
          height: itemHeight,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.lightBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _DashboardColors.border, width: 0.8),
          ),
        ),
      ),
    );
  }
}

class _SkeletonTrendBars extends StatelessWidget {
  const _SkeletonTrendBars();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          7,
          (i) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 24.0 + (i * 8.0),
                    decoration: BoxDecoration(
                      color: AppTheme.lightCardBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 14,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.lightCardSurfaceElevated,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
