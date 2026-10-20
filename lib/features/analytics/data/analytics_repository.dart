import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../domain/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AnalyticsRepository(apiClient);
});

class AnalyticsRepository {
  final ApiClient _client;

  AnalyticsRepository(this._client);

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
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Data ringkasan analitik tidak dapat dimuat.');
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
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Tren penjualan tidak dapat dimuat.');
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
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Data jam sibuk tidak dapat dimuat.');
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
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Ringkasan shift tidak dapat dimuat.');
    }
  }

  /// AI Time Series Sales Forecasting (7 / 30 Hari ke depan)
  Future<SalesForecastModel> getSalesForecast({
    String? outletId,
    int horizon = 7,
  }) async {
    final query = <String, dynamic>{'horizon': horizon};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/analytics/forecast/sales',
        queryParameters: query,
      );
      final data = response.data?['data'] as Map<String, dynamic>;
      return SalesForecastModel.fromJson(data);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Prediksi penjualan AI tidak dapat dimuat.');
    }
  }

  /// AI Stock Runout & Consumption Velocity Forecasting
  Future<StockoutForecastModel> getStockoutForecast({
    String? outletId,
  }) async {
    final query = <String, dynamic>{};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/analytics/forecast/stockout',
        queryParameters: query,
      );
      final data = response.data?['data'] as Map<String, dynamic>;
      return StockoutForecastModel.fromJson(data);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Prediksi kehabisan stok tidak dapat dimuat.');
    }
  }
}
