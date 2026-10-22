import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';

/// Opsi pilihan periode hari untuk dashboard owner & analitik
enum DashboardDateFilter {
  today('Hari Ini'),
  yesterday('Kemarin'),
  last7Days('7 Hari Terakhir'),
  last30Days('30 Hari Terakhir'),
  thisMonth('Bulan Ini');

  final String label;
  const DashboardDateFilter(this.label);
}

/// Filter outlet: null berarti "Seluruh Cabang" (default untuk Owner).
/// Untuk Role Manager & Staff: otomatis terkunci pada outlet yang di-assign oleh Owner.
final selectedOutletFilterProvider = StateProvider<String?>((ref) {
  final user = ref.watch(authProvider).user;
  if (user != null && user.role != UserRole.owner && user.outlets.isNotEmpty) {
    return user.outlets.first.id;
  }
  return null;
});

/// Helper untuk menentukan outlet efektif (Owner dapat memilih atau semua, sedangkan Manager/Staff terkunci ke outlet yang di-assign)
String? getEffectiveOutletId(Ref ref) {
  final user = ref.watch(authProvider).user;
  if (user != null && user.role != UserRole.owner && user.outlets.isNotEmpty) {
    return user.outlets.first.id;
  }
  return ref.watch(selectedOutletFilterProvider);
}

/// Filter hari/periode dashboard: default "Hari Ini"
final selectedDateFilterProvider = StateProvider<DashboardDateFilter>((ref) => DashboardDateFilter.today);

/// Filter tanggal kustom spesifik (jika pengguna memilih tanggal via date picker)
final selectedCustomDateProvider = StateProvider<DateTime?>((ref) => null);

/// Menerjemahkan filter periode dashboard menjadi rentang tanggal `from`/`to`
/// (format YYYY-MM-DD) agar dashboard, riwayat transaksi, dan leaderboard
/// memakai definisi periode yang sama persis.
({String from, String to}) resolveDashboardDateRange(
  DashboardDateFilter dateFilter,
  DateTime? customDate, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  if (customDate != null) {
    final d = DateFormat('yyyy-MM-dd').format(customDate);
    return (from: d, to: d);
  }
  switch (dateFilter) {
    case DashboardDateFilter.today:
      final d = DateFormat('yyyy-MM-dd').format(today);
      return (from: d, to: d);
    case DashboardDateFilter.yesterday:
      final d = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 1)));
      return (from: d, to: d);
    case DashboardDateFilter.last7Days:
      return (
        from: DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 6))),
        to: DateFormat('yyyy-MM-dd').format(today),
      );
    case DashboardDateFilter.last30Days:
      return (
        from: DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 29))),
        to: DateFormat('yyyy-MM-dd').format(today),
      );
    case DashboardDateFilter.thisMonth:
      return (
        from: DateFormat('yyyy-MM-dd').format(DateTime(today.year, today.month, 1)),
        to: DateFormat('yyyy-MM-dd').format(today),
      );
  }
}

/// Model komparasi laba dan omset hari kemarin vs hari sekarang
class DailyProfitComparisonModel {
  final AnalyticsOverviewModel today;
  final AnalyticsOverviewModel yesterday;

  const DailyProfitComparisonModel({
    required this.today,
    required this.yesterday,
  });

  int get todayRevenue => today.revenueIdr;
  int get yesterdayRevenue => yesterday.revenueIdr;
  int get revenueDiff => todayRevenue - yesterdayRevenue;
  double get revenuePctChange {
    if (yesterdayRevenue == 0) return todayRevenue > 0 ? 100.0 : 0.0;
    return ((todayRevenue - yesterdayRevenue) / yesterdayRevenue.abs()) * 100;
  }

  int get todayProfit => today.grossProfitIdr ?? (today.grossMarginPct != null && today.revenueIdr > 0 ? (today.revenueIdr * today.grossMarginPct! / 100).round() : 0);
  int get yesterdayProfit => yesterday.grossProfitIdr ?? (yesterday.grossMarginPct != null && yesterday.revenueIdr > 0 ? (yesterday.revenueIdr * yesterday.grossMarginPct! / 100).round() : 0);
  int get profitDiff => todayProfit - yesterdayProfit;
  double get profitPctChange {
    if (yesterdayProfit == 0) return todayProfit > 0 ? 100.0 : 0.0;
    return ((todayProfit - yesterdayProfit) / yesterdayProfit.abs()) * 100;
  }

  bool get isProfitUp => profitDiff > 0;
  bool get isProfitDown => profitDiff < 0;
  bool get isProfitEqual => profitDiff == 0;

  // Format nominal uang TIDAK lagi di-hardcode di sini: nominal ditampilkan
  // lewat MoneyText/ref.money() supaya mengikuti mata uang pengguna.
}

/// Provider ringkasan analitik utama (mengikuti outlet & date filter)
final analyticsOverviewProvider = FutureProvider.autoDispose<AnalyticsOverviewModel>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = getEffectiveOutletId(ref);
  final dateFilter = ref.watch(selectedDateFilterProvider);
  final customDate = ref.watch(selectedCustomDateProvider);

  final now = DateTime.now();
  String? fromStr;
  String? toStr;

  if (customDate != null) {
    final d = DateFormat('yyyy-MM-dd').format(customDate);
    fromStr = d;
    toStr = d;
  } else {
    switch (dateFilter) {
      case DashboardDateFilter.today:
        final d = DateFormat('yyyy-MM-dd').format(now);
        fromStr = d;
        toStr = d;
        break;
      case DashboardDateFilter.yesterday:
        final d = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
        fromStr = d;
        toStr = d;
        break;
      case DashboardDateFilter.last7Days:
        fromStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 6)));
        toStr = DateFormat('yyyy-MM-dd').format(now);
        break;
      case DashboardDateFilter.last30Days:
        fromStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 29)));
        toStr = DateFormat('yyyy-MM-dd').format(now);
        break;
      case DashboardDateFilter.thisMonth:
        fromStr = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
        toStr = DateFormat('yyyy-MM-dd').format(now);
        break;
    }
  }

  return repo.getOverview(outletId: outletId, from: fromStr, to: toStr);
});

/// Provider perhitungan komparasi laba hari kemarin dan hari sekarang
final dailyProfitComparisonProvider = Provider.autoDispose<AsyncValue<DailyProfitComparisonModel>>((ref) {
  final overviewAsync = ref.watch(analyticsOverviewProvider);
  final trendAsync = ref.watch(salesTrendProvider);

  if (overviewAsync.isLoading || trendAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (overviewAsync.hasError) {
    return AsyncValue.error(
      overviewAsync.error!,
      overviewAsync.stackTrace ?? StackTrace.current,
    );
  }

  final overview = overviewAsync.valueOrNull;
  if (overview == null) {
    return const AsyncValue.loading();
  }

  final trend = trendAsync.valueOrNull ?? [];
  final now = DateTime.now();
  final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

  // Ambil data kemarin dari sales trend jika tersedia
  final yesterdayPoint = trend.where((p) => p.date == yesterdayStr).firstOrNull;

  // Jika data kemarin tidak tersedia, gunakan data hari ini (0% perubahan) — TIDAK memfabrikasi angka.
  final yesterdayRevenue = yesterdayPoint?.revenueIdr ?? overview.revenueIdr;
  final yesterdayCount = yesterdayPoint?.count ?? overview.transactionCount;

  final marginFraction = (overview.grossMarginPct != null && overview.grossMarginPct! > 0)
      ? (overview.grossMarginPct! / 100.0)
      : (overview.grossProfitIdr != null && overview.revenueIdr > 0)
          ? (overview.grossProfitIdr! / overview.revenueIdr)
          : 0.0;
  final yesterdayProfit = (yesterdayRevenue * marginFraction).round();

  final yesterdayModel = AnalyticsOverviewModel(
    revenueIdr: yesterdayRevenue,
    subtotalIdr: yesterdayRevenue,
    discountIdr: 0,
    transactionCount: yesterdayCount,
    avgBasketSizeIdr: yesterdayCount > 0 ? (yesterdayRevenue / yesterdayCount).round() : 0,
    grossProfitIdr: yesterdayProfit,
    grossMarginPct: overview.grossMarginPct ?? (marginFraction * 100).round(),
  );

  return AsyncValue.data(
    DailyProfitComparisonModel(
      today: overview,
      yesterday: yesterdayModel,
    ),
  );
});

final salesTrendProvider = FutureProvider.autoDispose<List<SalesTrendPoint>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = getEffectiveOutletId(ref);
  return repo.getSalesTrend(outletId: outletId, days: 7);
});

final peakHoursProvider = FutureProvider.autoDispose<List<PeakHourPoint>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = getEffectiveOutletId(ref);
  return repo.getPeakHours(outletId: outletId);
});

final shiftSummaryProvider = FutureProvider.autoDispose<ShiftSummaryModel>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = getEffectiveOutletId(ref);
  return repo.getShiftSummary(outletId: outletId);
});

// =========================================================================
// AI PREDICTIVE PROVIDERS
// =========================================================================

/// Tab aktif di Predictive Dashboard: 0 = Peramalan Penjualan, 1 = Radar Stok Habis
final analyticsActiveTabProvider = StateProvider.autoDispose<int>((ref) => 0);

/// Horizon waktu peramalan penjualan: 7 hari atau 30 hari
final selectedForecastHorizonProvider = StateProvider.autoDispose<int>((ref) => 7);

/// Filter kategori stok habis: 'all' | 'critical' | 'warning' | 'safe'
final selectedStockoutFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');

/// Provider data AI Sales Forecast (Time Series Model)
final salesForecastProvider = FutureProvider.autoDispose<SalesForecastModel>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = getEffectiveOutletId(ref);
  final horizon = ref.watch(selectedForecastHorizonProvider);
  return repo.getSalesForecast(outletId: outletId, horizon: horizon);
});

/// Provider data AI Stockout & Velocity Forecast
final stockoutForecastProvider = FutureProvider.autoDispose<StockoutForecastModel>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = getEffectiveOutletId(ref);
  return repo.getStockoutForecast(outletId: outletId);
});

/// Provider data Leaderboard Menu Terlaris (mengikuti filter outlet & tanggal)
final leaderboardProvider = FutureProvider.autoDispose<List<TopSellingProductModel>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = getEffectiveOutletId(ref);
  final range = resolveDashboardDateRange(
    ref.watch(selectedDateFilterProvider),
    ref.watch(selectedCustomDateProvider),
  );

  return repo.getLeaderboard(
    outletId: outletId,
    from: range.from,
    to: range.to,
    limit: 50,
  );
});
