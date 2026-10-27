import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/local_db.dart';
import '../domain/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final localDb = ref.watch(localDbProvider);
  return AnalyticsRepository(apiClient, localDb);
});

class AnalyticsRepository {
  final ApiClient _client;
  final LocalDatabase? _localDb;

  AnalyticsRepository(this._client, [this._localDb]);

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

      int pendingCount = 0;
      if (_localDb != null) {
        final pendingRows = await _localDb.getPendingOfflineTransactions();
        pendingCount = pendingRows.where((row) {
          if (outletId != null && outletId.isNotEmpty) {
            final rowOutlet = row['outlet_id'] as String?;
            return rowOutlet == null || rowOutlet.isEmpty || rowOutlet == outletId;
          }
          return true;
        }).length;
      }

      return ShiftSummaryModel(
        todayRevenueIdr: data['today_revenue_idr'] as int? ?? 0,
        cashRevenueIdr: data['cash_revenue_idr'] as int? ?? 0,
        qrisRevenueIdr: data['qris_revenue_idr'] as int? ?? 0,
        transactionCount: data['transaction_count'] as int? ?? 0,
        isOffline: false,
        pendingCount: pendingCount,
        isDataAvailable: true,
      );
    } on AppException {
      if (_localDb != null) {
        return await _computeLocalShiftSummary(outletId: outletId);
      }
      rethrow;
    } catch (_) {
      if (_localDb != null) {
        return await _computeLocalShiftSummary(outletId: outletId);
      }
      throw const AppException('Koneksi ke web service terputus. Ringkasan shift tidak dapat dimuat.');
    }
  }

  Future<ShiftSummaryModel> _computeLocalShiftSummary({String? outletId}) async {
    if (_localDb == null) {
      return const ShiftSummaryModel(
        todayRevenueIdr: 0,
        cashRevenueIdr: 0,
        qrisRevenueIdr: 0,
        transactionCount: 0,
        isOffline: true,
        pendingCount: 0,
        isDataAvailable: false,
      );
    }

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // Ambil data transaksi dari backup lokal (cache struk)
    final backupList = await _localDb.getBackupTransactions(outletId: outletId);

    // Ambil data transaksi lokal yang belum tersinkronisasi
    final pendingRows = await _localDb.getPendingOfflineTransactions();

    // Gabungkan dan deduplikasi ketat berdasarkan ID transaksi maupun Client Request ID
    final seenKeys = <String>{};
    final allTodayTx = <({int totalIdr, String paymentMethod, bool isPending})>[];

    for (final tx in backupList) {
      final idMatch = tx.id.isNotEmpty && seenKeys.contains(tx.id);
      final reqMatch = tx.clientRequestId != null && tx.clientRequestId!.isNotEmpty && seenKeys.contains(tx.clientRequestId);

      if (!idMatch && !reqMatch) {
        if (tx.id.isNotEmpty) seenKeys.add(tx.id);
        if (tx.clientRequestId != null && tx.clientRequestId!.isNotEmpty) {
          seenKeys.add(tx.clientRequestId!);
        }

        if (!tx.createdAt.isBefore(startOfToday) && tx.status != 'voided') {
          allTodayTx.add((
            totalIdr: tx.totalIdr,
            paymentMethod: tx.paymentMethod,
            isPending: tx.isOfflinePending || tx.status == 'offline_pending',
          ));
        }
      }
    }

    for (final row in pendingRows) {
      final clientReqId = row['client_request_id'] as String?;
      final rowId = row['id'] as String?;

      final idMatch = rowId != null && rowId.isNotEmpty && seenKeys.contains(rowId);
      final reqMatch = clientReqId != null && clientReqId.isNotEmpty && seenKeys.contains(clientReqId);

      if (!idMatch && !reqMatch) {
        if (rowId != null && rowId.isNotEmpty) seenKeys.add(rowId);
        if (clientReqId != null && clientReqId.isNotEmpty) seenKeys.add(clientReqId);

        final rowOutlet = row['outlet_id'] as String?;
        if (outletId != null && outletId.isNotEmpty && rowOutlet != null && rowOutlet.isNotEmpty && rowOutlet != outletId) {
          continue;
        }
        final createdAtStr = row['created_at'] as String?;
        final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
        if (createdAt == null || !createdAt.isBefore(startOfToday)) {
          allTodayTx.add((
            totalIdr: row['total_idr'] as int? ?? 0,
            paymentMethod: row['payment_method'] as String? ?? 'cash',
            isPending: true,
          ));
        }
      }
    }

    if (allTodayTx.isEmpty) {
      return const ShiftSummaryModel(
        todayRevenueIdr: 0,
        cashRevenueIdr: 0,
        qrisRevenueIdr: 0,
        transactionCount: 0,
        isOffline: true,
        pendingCount: 0,
        isDataAvailable: false,
      );
    }

    final todayRevenueIdr = allTodayTx.fold<int>(0, (sum, t) => sum + t.totalIdr);
    final cashRevenueIdr = allTodayTx.where((t) => t.paymentMethod == 'cash').fold<int>(0, (sum, t) => sum + t.totalIdr);
    final qrisRevenueIdr = todayRevenueIdr - cashRevenueIdr;
    final transactionCount = allTodayTx.length;
    final pendingCount = allTodayTx.where((t) => t.isPending).length;

    return ShiftSummaryModel(
      todayRevenueIdr: todayRevenueIdr,
      cashRevenueIdr: cashRevenueIdr,
      qrisRevenueIdr: qrisRevenueIdr,
      transactionCount: transactionCount,
      isOffline: true,
      pendingCount: pendingCount,
      isDataAvailable: true,
    );
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

  /// Leaderboard Menu Terlaris (Top Selling Products) dari Backend Database
  Future<List<TopSellingProductModel>> getLeaderboard({
    String? outletId,
    String? from,
    String? to,
    int limit = 20,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/analytics/leaderboard',
        queryParameters: query,
      );
      final list = response.data?['data'] as List<dynamic>? ?? [];
      return list.map((item) => TopSellingProductModel.fromJson(item as Map<String, dynamic>)).toList();
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Data leaderboard terlaris tidak dapat dimuat.');
    }
  }
}
