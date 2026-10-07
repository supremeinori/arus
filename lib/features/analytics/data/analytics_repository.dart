import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AnalyticsRepository(apiClient);
});

class AnalyticsRepository {
  final ApiClient _client;

  AnalyticsRepository(this._client);

  static const _demoOverview = AnalyticsOverviewModel(
    revenueIdr: 45200000,
    subtotalIdr: 46100000,
    discountIdr: 900000,
    transactionCount: 142,
    avgBasketSizeIdr: 318309,
    totalCostIdr: 17800000,
    grossProfitIdr: 27400000,
    grossMarginPct: 61,
  );

  static final List<SalesTrendPoint> _demoTrend = [
    const SalesTrendPoint(date: '01/10', revenueIdr: 5400000, count: 21),
    const SalesTrendPoint(date: '02/10', revenueIdr: 6100000, count: 25),
    const SalesTrendPoint(date: '03/10', revenueIdr: 5800000, count: 22),
    const SalesTrendPoint(date: '04/10', revenueIdr: 7200000, count: 29),
    const SalesTrendPoint(date: '05/10', revenueIdr: 8500000, count: 34),
    const SalesTrendPoint(date: '06/10', revenueIdr: 6800000, count: 26),
    const SalesTrendPoint(date: '07/10', revenueIdr: 5400000, count: 21),
  ];

  static final List<PeakHourPoint> _demoPeakHours = [
    const PeakHourPoint(hour: 8, label: '08:00', transactionCount: 18, totalRevenueIdr: 396000),
    const PeakHourPoint(hour: 9, label: '09:00', transactionCount: 24, totalRevenueIdr: 528000),
    const PeakHourPoint(hour: 12, label: '12:00', transactionCount: 35, totalRevenueIdr: 770000),
    const PeakHourPoint(hour: 13, label: '13:00', transactionCount: 30, totalRevenueIdr: 660000),
    const PeakHourPoint(hour: 18, label: '18:00', transactionCount: 28, totalRevenueIdr: 616000),
    const PeakHourPoint(hour: 19, label: '19:00', transactionCount: 32, totalRevenueIdr: 704000),
  ];

  static const _demoShift = ShiftSummaryModel(
    todayRevenueIdr: 616000,
    cashRevenueIdr: 242000,
    qrisRevenueIdr: 374000,
    transactionCount: 28,
  );

  Future<AnalyticsOverviewModel> getOverview({
    String? outletId,
    String? from,
    String? to,
  }) async {
    final query = <String, dynamic>{};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/analytics/overview',
        queryParameters: query,
      );
      final data = response.data?['data'] as Map<String, dynamic>;
      return AnalyticsOverviewModel.fromJson(data);
    } catch (_) {
      return _demoOverview;
    }
  }

  Future<List<SalesTrendPoint>> getSalesTrend({
    String? outletId,
    int days = 7,
  }) async {
    final query = <String, dynamic>{'days': days};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/analytics/sales-trend',
        queryParameters: query,
      );
      final list = response.data?['data'] as List<dynamic>? ?? [];
      return list.map((item) => SalesTrendPoint.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return _demoTrend;
    }
  }

  Future<List<PeakHourPoint>> getPeakHours({
    String? outletId,
  }) async {
    final query = <String, dynamic>{};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/analytics/peak-hours',
        queryParameters: query,
      );
      final list = response.data?['data'] as List<dynamic>? ?? [];
      return list.map((item) => PeakHourPoint.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return _demoPeakHours;
    }
  }

  Future<ShiftSummaryModel> getShiftSummary({
    String? outletId,
  }) async {
    final query = <String, dynamic>{};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/analytics/shift-summary',
        queryParameters: query,
      );
      final data = response.data?['data'] as Map<String, dynamic>;
      return ShiftSummaryModel.fromJson(data);
    } catch (_) {
      return _demoShift;
    }
  }
}
