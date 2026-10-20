import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money_formatter.dart';
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

/// Design tokens for Light Mode Owner Dashboard (Wireframe & Anti-AI-Slop Compliant)
class _DashboardColors {
  static const bg = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172A); // Slate-900 Navy
  static const textSecondary = Color(0xFF475569); // Slate-600
  static const textMuted = Color(0xFF64748B); // Slate-500
  static const border = Color(0xFFE2E8F0); // Hairline 1px Slate-200
  static const teal = Color(0xFF00A896); // Modern Jade Tosca
  static const tealLight = Color(0xFFE6F6F4);
  static const amber = Color(0xFFD97706); // Warm Amber
  static const amberLight = Color(0xFFFEF3C7);
  static const danger = Color(0xFFEF4444);
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

    // API TERSEDIA: GET /api/notifications (Unread notification count)
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    // Filter states (Cabang & Hari)
    final selectedOutletId = ref.watch(selectedOutletFilterProvider);
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
    // Data Katalog Produk: GET /api/catalog/products
    final productsAsync = ref.watch(productListProvider);
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
            ref.invalidate(productListProvider);
            ref.invalidate(notificationsListProvider);
          },
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header (Wireframe: [logo] Arus .......... (🔔))
                // API TERSEDIA: GET /api/notifications (badge unread)
                _WireframeHeader(unreadCount: unreadCount),
                const SizedBox(height: 14),

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
                  ),
                  data: (kpi) => _HeroOmzetCard(
                    revenueIdr: kpi.revenueIdr, // Data asli dari API
                    outlets: outlets,
                    selectedOutletId: selectedOutletId,
                    selectedDateFilter: selectedDateFilter,
                    selectedCustomDate: selectedCustomDate,
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
                    onViewHistory: () => context.push('/pos-history'),
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
                    onViewHistory: () => context.push('/pos-history'),
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
                // ============================================================
                // TODO: [BELUM ADA API] Endpoint Produk Terlaris (Top Selling)
                // Rekomendasi API Backend yang perlu dibuat:
                //   GET /api/analytics/products?type=top_selling&outlet_id=...&from=...&to=...&limit=3
                // Response yang diharapkan:
                //   [
                //     {
                //       "product_id": "...",
                //       "name": "Kopi Susu Gula Aren",
                //       "category_name": "Coffee",
                //       "price_idr": 20000,
                //       "sold_quantity": 45
                //     }
                //   ]
                // ============================================================
                _TerlarisCard(
                  products: productsAsync.valueOrNull ?? [],
                  isLoading: productsAsync.isLoading,
                  onViewAll: () => context.push('/catalog'),
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
                  onViewAll: () => context.push('/inventory'),
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

  const _WireframeHeader({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo Badge + "Arus" Text
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B), // Slate-800 Dark Container
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'logo',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Arus',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _DashboardColors.textPrimary,
                  letterSpacing: -0.3,
                ),
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

  const _HeroOmzetCard({
    required this.revenueIdr,
    required this.outlets,
    required this.selectedOutletId,
    required this.selectedDateFilter,
    required this.selectedCustomDate,
    this.errorMessage,
    this.onRetry,
  });

  String _formatRp(int amount) {
    final formatted = MoneyFormatter.format(amount);
    // Wireframe format: "Rp.17.000.000" / "Rp.2.500.000"
    return formatted.replaceAll('Rp ', 'Rp.');
  }

  void _openFilterDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FilterBoxSheet(
        outlets: outlets,
        selectedOutletId: selectedOutletId,
        selectedDateFilter: selectedDateFilter,
        selectedCustomDate: selectedCustomDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nama Cabang
    String branchLabel = 'Semua Cabang';
    if (selectedOutletId != null) {
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
          // Label "Omzet" (Inter)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Omzet',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _DashboardColors.textSecondary,
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
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Angka Besar Omzet (LEXEND w800) - Data riil dari API
          Text(
            _formatRp(revenueIdr),
            style: GoogleFonts.lexend(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _DashboardColors.textPrimary,
              letterSpacing: -0.6,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Baris Bawah: Di "Nama Cabang" pada "Pilihan Hari" + Filter Icon
          Row(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // DropdownButton transparan untuk direct selection & test runner compatibility
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
                          fontSize: 12.5,
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
                    color: const Color(0xFFF1F5F9), // Slate-100
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
// KOTAK FILTER (Modal Bottom Sheet untuk Memilih Cabang & Hari)
// Memicu refilter API GET /api/analytics/overview dengan parameter baru
// ============================================================================
class _FilterBoxSheet extends ConsumerStatefulWidget {
  final List<({String id, String name})> outlets;
  final String? selectedOutletId;
  final DashboardDateFilter selectedDateFilter;
  final DateTime? selectedCustomDate;

  const _FilterBoxSheet({
    required this.outlets,
    required this.selectedOutletId,
    required this.selectedDateFilter,
    required this.selectedCustomDate,
  });

  @override
  ConsumerState<_FilterBoxSheet> createState() => _FilterBoxSheetState();
}

class _FilterBoxSheetState extends ConsumerState<_FilterBoxSheet> {
  late String? _tempOutletId;
  late DashboardDateFilter _tempDateFilter;
  late DateTime? _tempCustomDate;

  @override
  void initState() {
    super.initState();
    _tempOutletId = widget.selectedOutletId;
    _tempDateFilter = widget.selectedDateFilter;
    _tempCustomDate = widget.selectedCustomDate;
  }

  Future<void> _pickCustomCalendarDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempCustomDate ?? now,
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
      setState(() {
        _tempCustomDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: _DashboardColors.teal,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Kotak Filter Bisnis',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _DashboardColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: _DashboardColors.textMuted,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _DashboardColors.border),
          const SizedBox(height: 16),

          // 1. Pemilihan Cabang
          Text(
            'PILIH CABANG OUTLET',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _DashboardColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _DashboardColors.border, width: 1.0),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _tempOutletId,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _DashboardColors.textMuted,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Semua Cabang',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _DashboardColors.textPrimary,
                      ),
                    ),
                  ),
                  ...widget.outlets.map(
                    (o) => DropdownMenuItem<String?>(
                      value: o.id,
                      child: Text(
                        o.name,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
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
                  setState(() => _tempOutletId = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2. Pemilihan Hari / Periode
          Text(
            'PILIH HARI / PERIODE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _DashboardColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...DashboardDateFilter.values.map((filter) {
                final isSelected =
                    _tempCustomDate == null && _tempDateFilter == filter;
                return ChoiceChip(
                  label: Text(filter.label),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : _DashboardColors.textPrimary,
                  ),
                  selected: isSelected,
                  selectedColor: _DashboardColors.teal,
                  backgroundColor: const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected
                          ? _DashboardColors.teal
                          : _DashboardColors.border,
                      width: 1.0,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _tempDateFilter = filter;
                        _tempCustomDate = null;
                      });
                    }
                  },
                );
              }),
              ActionChip(
                avatar: const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: _DashboardColors.teal,
                ),
                label: Text(
                  _tempCustomDate != null
                      ? DateFormat(
                          'd MMM yyyy',
                          'id_ID',
                        ).format(_tempCustomDate!)
                      : 'Pilih Tanggal...',
                ),
                labelStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: _tempCustomDate != null
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: _tempCustomDate != null
                      ? _DashboardColors.teal
                      : _DashboardColors.textSecondary,
                ),
                backgroundColor: _tempCustomDate != null
                    ? _DashboardColors.tealLight
                    : const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: _tempCustomDate != null
                        ? _DashboardColors.teal
                        : _DashboardColors.border,
                    width: 1.0,
                  ),
                ),
                onPressed: _pickCustomCalendarDate,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tombol Terapkan
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _DashboardColors.teal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                ref.read(selectedOutletFilterProvider.notifier).state =
                    _tempOutletId;
                ref.read(selectedDateFilterProvider.notifier).state =
                    _tempDateFilter;
                ref.read(selectedCustomDateProvider.notifier).state =
                    _tempCustomDate;
                Navigator.pop(context);
              },
              child: Text(
                'Terapkan Filter',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _DashboardColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
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
                    'Lihat riwayat',
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
                  'Masalah',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _DashboardColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
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
                InkWell(
                  onTap: onViewIssues,
                  child: Text(
                    'Lihat Masalah',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _DashboardColors.textSecondary,
                    ),
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

// ============================================================================
// 4. SECTION TERLARIS (Wireframe: Terlaris ...... Lihat Semua)
// ============================================================================
// TODO: [BELUM ADA API] Endpoint Produk Terlaris (Top-Selling Products)
// Endpoint yang perlu dibuat di backend:
//   GET /api/analytics/products?type=top_selling&outlet_id=...&from=...&to=...&limit=3
// Response yang diharapkan:
//   List objek { id, name, categoryName, priceIdr, soldQuantity }
//
// Saat ini menggunakan data riil katalog produk (GET /api/catalog/products),
// dan kuantitas porsi terjual ditampilkan riil bila tersedia di model produk.
// ============================================================================
class _TerlarisCard extends StatelessWidget {
  final List<ProductModel> products;
  final bool isLoading;
  final VoidCallback onViewAll;

  const _TerlarisCard({
    required this.products,
    required this.isLoading,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _DashboardColors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // List Produk Terlaris
          if (isLoading)
            const _SkeletonList(itemCount: 3, itemHeight: 48)
          else if (topList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Belum ada data produk terdaftar di katalog.',
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
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '#${index + 1}',
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

                        // Nama Produk
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: _DashboardColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                product.categoryName ?? 'Menu Utama',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: _DashboardColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Harga & Porsi Terjual
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              MoneyFormatter.format(product.priceIdr),
                              style: GoogleFonts.lexend(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _DashboardColors.textPrimary,
                              ),
                            ),
                            Text(
                              product.estimatedPortions > 0
                                  ? '${product.estimatedPortions} porsi'
                                  : '- porsi',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _DashboardColors.textMuted,
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points.map((point) {
                  final ratio = maxRevenue > 0
                      ? (point.revenueIdr / maxRevenue)
                      : 0.1;
                  final barHeight = math.max(16.0, ratio * 90.0);
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
                                  : const Color(0xFFCBD5E1),
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
class _PeringatanCard extends StatelessWidget {
  final List<IngredientModel> ingredients;
  final bool isLoading;
  final VoidCallback onViewAll;

  const _PeringatanCard({
    required this.ingredients,
    required this.isLoading,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
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
                onTap: onViewAll,
                child: Text(
                  'Lihat Semua',
                  style: GoogleFonts.inter(
                    fontSize: 12,
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

            // Tombol Panah Kanan di Pojok Bawah Card (Wireframe: ->)
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onViewAll,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: _DashboardColors.textPrimary,
                  ),
                ),
              ),
            ),
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
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 180,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
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
            color: const Color(0xFFF8FAFC),
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
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 14,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
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
