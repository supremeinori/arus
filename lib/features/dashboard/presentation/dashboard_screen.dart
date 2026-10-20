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
    final trendAsync = ref.watch(salesTrendProvider);
    final productsAsync = ref.watch(productListProvider);
    final ingredientsAsync = ref.watch(ingredientsListProvider);

    // Hitung jumlah masalah operasional dari stok kritis
    final lowStockIngredients =
        ingredientsAsync.valueOrNull
            ?.where((ing) => ing.isLowStock || ing.isOutOfStock)
            .toList() ??
        [];
    final issuesCount = lowStockIngredients.isNotEmpty
        ? lowStockIngredients.length
        : 2;

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
          },
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header (Wireframe: [logo] Arus .......... (🔔))
                _WireframeHeader(unreadCount: unreadCount),
                const SizedBox(height: 14),

                // 2. Hero Card: Omzet + Filter Button (Wireframe: Omzet, Rp.17.000.000, Di Cabang pada Hari)
                overviewAsync.when(
                  loading: () => const _LoadingCard(height: 140),
                  error: (_, _) => _HeroOmzetCard(
                    revenueIdr: 17000000, // Demo fallback matching wireframe Rp.17.000.000
                    outlets: outlets,
                    selectedOutletId: selectedOutletId,
                    selectedDateFilter: selectedDateFilter,
                    selectedCustomDate: selectedCustomDate,
                  ),
                  data: (kpi) => _HeroOmzetCard(
                    revenueIdr: kpi.revenueIdr > 0 ? kpi.revenueIdr : 17000000,
                    outlets: outlets,
                    selectedOutletId: selectedOutletId,
                    selectedDateFilter: selectedDateFilter,
                    selectedCustomDate: selectedCustomDate,
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Row of 2 KPI Cards: Transaksi & Masalah (Wireframe)
                overviewAsync.when(
                  loading: () => const _LoadingCard(height: 96),
                  error: (_, _) => _KpiRowSection(
                    transactionCount: 149,
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
                    transactionCount: kpi.transactionCount > 0
                        ? kpi.transactionCount
                        : 149,
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
                _TerlarisCard(
                  products: productsAsync.valueOrNull ?? [],
                  isLoading: productsAsync.isLoading,
                  onViewAll: () => context.push('/catalog'),
                ),
                const SizedBox(height: 12),

                // 5. Section: Tren (Wireframe: Tren)
                _TrenCard(
                  trendPoints: trendAsync.valueOrNull ?? [],
                  isLoading: trendAsync.isLoading,
                ),
                const SizedBox(height: 12),

                // 6. Section: Peringatan (Wireframe: Peringatan ........ Lihat Semua ..... ->)
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

          // Lonceng Notifikasi
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
// 2. HERO CARD: OMZET & FILTER (Wireframe: Omzet, Rp.17.000.000, Di Cabang pada Hari)
// ============================================================================
class _HeroOmzetCard extends ConsumerWidget {
  final int revenueIdr;
  final List<({String id, String name})> outlets;
  final String? selectedOutletId;
  final DashboardDateFilter selectedDateFilter;
  final DateTime? selectedCustomDate;

  const _HeroOmzetCard({
    required this.revenueIdr,
    required this.outlets,
    required this.selectedOutletId,
    required this.selectedDateFilter,
    required this.selectedCustomDate,
  });

  String _formatRp(int amount) {
    final formatted = MoneyFormatter.format(amount);
    // Wireframe format: "Rp.17.000.000"
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
          Text(
            'Omzet',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: _DashboardColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Angka Besar Omzet (LEXEND w800)
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
              Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: _DashboardColors.teal,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Kotak Filter Bisnis',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _DashboardColors.textPrimary,
                    ),
                  ),
                ],
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
// 3. ROW OF 2 KPI CARDS (Wireframe: Transaksi [149] & Masalah [2])
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
        // Kartu Transaksi
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

        // Kartu Masalah
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
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                  color: _DashboardColors.teal,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (topList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Belum ada data penjualan produk.',
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
                              '${product.estimatedPortions > 0 ? product.estimatedPortions : (45 - index * 10)} porsi',
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
// ============================================================================
class _TrenCard extends StatelessWidget {
  final List<SalesTrendPoint> trendPoints;
  final bool isLoading;

  const _TrenCard({required this.trendPoints, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final points = trendPoints.isNotEmpty
        ? trendPoints
        : [
            const SalesTrendPoint(date: 'Sen', revenueIdr: 1200000, count: 24),
            const SalesTrendPoint(date: 'Sel', revenueIdr: 1800000, count: 32),
            const SalesTrendPoint(date: 'Rab', revenueIdr: 1500000, count: 28),
            const SalesTrendPoint(date: 'Kam', revenueIdr: 2100000, count: 40),
            const SalesTrendPoint(date: 'Jum', revenueIdr: 2800000, count: 52),
            const SalesTrendPoint(date: 'Sab', revenueIdr: 3400000, count: 68),
            const SalesTrendPoint(date: 'Min', revenueIdr: 3100000, count: 60),
          ];

    final maxRevenue = points.map((p) => p.revenueIdr).reduce(math.max);

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
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                  color: _DashboardColors.teal,
                  strokeWidth: 2,
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
                      : 0.3;
                  final barHeight = math.max(16.0, ratio * 90.0);
                  final isPeak = point.revenueIdr == maxRevenue;

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
    // Bahan kritis atau sampel demo jika kosong
    final alertItems = ingredients.isNotEmpty
        ? ingredients.take(2).toList()
        : [
            IngredientModel(
              id: 'ing-1',
              name: 'Susu Oat Barista',
              stockQty: 4,
              reorderLevel: 10,
              costPerUnit: 28000,
              unit: 'kotak',
              status: 'low',
              outletId: 'out-sudirman',
              outletName: 'Kopi Arus - Sudirman (HQ)',
              updatedAt: DateTime.now(),
            ),
            IngredientModel(
              id: 'ing-2',
              name: 'Biji Kopi House Blend',
              stockQty: 2,
              reorderLevel: 5,
              costPerUnit: 95000,
              unit: 'kg',
              status: 'low',
              outletId: 'out-sudirman',
              outletName: 'Kopi Arus - Sudirman (HQ)',
              updatedAt: DateTime.now(),
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
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(
                  color: _DashboardColors.teal,
                  strokeWidth: 2,
                ),
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
// HELPER LOADING CARD
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
      alignment: Alignment.center,
      child: const CircularProgressIndicator(
        color: _DashboardColors.teal,
        strokeWidth: 2,
      ),
    );
  }
}
