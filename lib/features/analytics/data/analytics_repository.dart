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
      final base = AnalyticsOverviewModel.fromJson(data);

      if (_localDb != null) {
        final pendingRows = await _localDb.getPendingOfflineTransactions();
        final pending = _filterLocalRows(pendingRows, outletId: outletId, from: from, to: to);
        if (pending.isNotEmpty) {
          final pendingRev = pending.fold<int>(0, (s, r) => s + (r['total_idr'] as int? ?? 0));
          return base.copyWith(
            revenueIdr: base.revenueIdr + pendingRev,
            transactionCount: base.transactionCount + pending.length,
            pendingCount: pending.length,
          );
        }
      }

      return base;
    } on AppException {
      if (_localDb != null) {
        return await _computeLocalOverview(outletId: outletId, from: from, to: to);
      }
      rethrow;
    } catch (_) {
      if (_localDb != null) {
        return await _computeLocalOverview(outletId: outletId, from: from, to: to);
      }
      throw const AppException('Koneksi ke web service terputus. Data ringkasan analitik tidak dapat dimuat.');
    }
  }

  Future<List<SalesTrendPoint>> getSalesTrend({
    String? outletId,
    int? days,
    String? from,
    String? to,
  }) async {
    final query = <String, dynamic>{};
    if (days != null) query['days'] = days;
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/analytics/sales-trend',
        queryParameters: query,
      );
      final list = response.data?['data'] as List<dynamic>? ?? [];
      var points = list.map((item) => SalesTrendPoint.fromJson(item as Map<String, dynamic>)).toList();

      if (_localDb != null) {
        final pendingRows = await _localDb.getPendingOfflineTransactions();
        final pending = _filterLocalRows(pendingRows, outletId: outletId, from: from, to: to);
        if (pending.isNotEmpty) {
          points = _mergePendingIntoSalesTrend(points, pending);
        }
      }

      return points;
    } on AppException {
      if (_localDb != null) {
        return await _computeLocalSalesTrend(outletId: outletId, days: days, from: from, to: to);
      }
      rethrow;
    } catch (_) {
      if (_localDb != null) {
        return await _computeLocalSalesTrend(outletId: outletId, days: days, from: from, to: to);
      }
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

  List<Map<String, dynamic>> _filterLocalRows(
    List<Map<String, dynamic>> rows, {
    String? outletId,
    String? from,
    String? to,
  }) {
    DateTime? startDate;
    DateTime? endDate;
    if (from != null && from.isNotEmpty) {
      startDate = DateTime.tryParse('${from}T00:00:00.000Z') ?? DateTime.tryParse(from);
    }
    if (to != null && to.isNotEmpty) {
      endDate = DateTime.tryParse('${to}T23:59:59.999Z') ?? DateTime.tryParse(to);
    }

    return rows.where((row) {
      if (outletId != null && outletId.isNotEmpty) {
        final rowOutlet = row['outlet_id'] as String?;
        if (rowOutlet != null && rowOutlet.isNotEmpty && rowOutlet != outletId) {
          return false;
        }
      }
      if (startDate != null || endDate != null) {
        final createdAtStr = row['created_at'] as String?;
        final dt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
        if (dt != null) {
          if (startDate != null && dt.isBefore(startDate)) return false;
          if (endDate != null && dt.isAfter(endDate)) return false;
        }
      }
      return true;
    }).toList();
  }

  List<SalesTrendPoint> _mergePendingIntoSalesTrend(
    List<SalesTrendPoint> serverPoints,
    List<Map<String, dynamic>> pendingRows,
  ) {
    if (serverPoints.isEmpty) return serverPoints;
    final map = {for (final p in serverPoints) p.date: p};
    for (final row in pendingRows) {
      final createdAtStr = row['created_at'] as String?;
      final dt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : DateTime.now();
      if (dt != null) {
        final dateKey = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        final existing = map[dateKey];
        final totalIdr = row['total_idr'] as int? ?? 0;
        if (existing != null) {
          map[dateKey] = SalesTrendPoint(
            date: existing.date,
            revenueIdr: existing.revenueIdr + totalIdr,
            count: existing.count + 1,
          );
        }
      }
    }
    return map.values.toList();
  }

  Future<AnalyticsOverviewModel> _computeLocalOverview({
    String? outletId,
    String? from,
    String? to,
  }) async {
    if (_localDb == null) {
      return const AnalyticsOverviewModel(
        revenueIdr: 0,
        subtotalIdr: 0,
        discountIdr: 0,
        transactionCount: 0,
        avgBasketSizeIdr: 0,
        isOffline: true,
        pendingCount: 0,
      );
    }

    DateTime? startDate;
    DateTime? endDate;
    if (from != null && from.isNotEmpty) {
      startDate = DateTime.tryParse('${from}T00:00:00.000Z') ?? DateTime.tryParse(from);
    }
    if (to != null && to.isNotEmpty) {
      endDate = DateTime.tryParse('${to}T23:59:59.999Z') ?? DateTime.tryParse(to);
    }

    final backupList = await _localDb.getBackupTransactions(outletId: outletId);
    final pendingRows = await _localDb.getPendingOfflineTransactions();

    final seenKeys = <String>{};
    int totalRevenue = 0;
    int totalSubtotal = 0;
    int totalDiscount = 0;
    int count = 0;
    int pendingCount = 0;

    for (final tx in backupList) {
      final idMatch = tx.id.isNotEmpty && seenKeys.contains(tx.id);
      final reqMatch = tx.clientRequestId != null && tx.clientRequestId!.isNotEmpty && seenKeys.contains(tx.clientRequestId);
      if (!idMatch && !reqMatch) {
        if (tx.id.isNotEmpty) seenKeys.add(tx.id);
        if (tx.clientRequestId != null && tx.clientRequestId!.isNotEmpty) seenKeys.add(tx.clientRequestId!);

        if (tx.status != 'voided') {
          if (startDate != null && tx.createdAt.isBefore(startDate)) continue;
          if (endDate != null && tx.createdAt.isAfter(endDate)) continue;

          totalRevenue += tx.totalIdr;
          totalSubtotal += tx.subtotalIdr;
          totalDiscount += tx.discountIdr;
          count++;
          if (tx.isOfflinePending || tx.status == 'offline_pending') {
            pendingCount++;
          }
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
        final dt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : DateTime.now();
        if (dt != null) {
          if (startDate != null && dt.isBefore(startDate)) continue;
          if (endDate != null && dt.isAfter(endDate)) continue;
        }

        final tot = row['total_idr'] as int? ?? 0;
        final sub = row['subtotal_idr'] as int? ?? tot;
        final disc = row['discount_idr'] as int? ?? 0;

        totalRevenue += tot;
        totalSubtotal += sub;
        totalDiscount += disc;
        count++;
        pendingCount++;
      }
    }

    return AnalyticsOverviewModel(
      revenueIdr: totalRevenue,
      subtotalIdr: totalSubtotal,
      discountIdr: totalDiscount,
      transactionCount: count,
      avgBasketSizeIdr: count > 0 ? (totalRevenue / count).round() : 0,
      isOffline: true,
      pendingCount: pendingCount,
    );
  }

  Future<List<SalesTrendPoint>> _computeLocalSalesTrend({
    String? outletId,
    int? days,
    String? from,
    String? to,
  }) async {
    final effectiveDays = days ?? 7;
    DateTime startDate;
    DateTime endDate;

    if (from != null && from.isNotEmpty) {
      startDate = DateTime.tryParse('T00:00:00.000Z') ?? DateTime.tryParse(from) ?? DateTime.now();
      endDate = to != null && to.isNotEmpty
          ? (DateTime.tryParse('T23:59:59.999Z') ?? DateTime.tryParse(to) ?? DateTime.now())
          : startDate.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    } else {
      final now = DateTime.now();
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: effectiveDays - 1));
    }

    final trendMap = <String, ({int revenueIdr, int count})>{};
    var curr = DateTime(startDate.year, startDate.month, startDate.day);
    final endLimit = DateTime(endDate.year, endDate.month, endDate.day);
    while (!curr.isAfter(endLimit)) {
      final key = '${curr.year.toString().padLeft(4, '0')}-${curr.month.toString().padLeft(2, '0')}-${curr.day.toString().padLeft(2, '0')}';
      trendMap[key] = (revenueIdr: 0, count: 0);
      curr = curr.add(const Duration(days: 1));
    }

    if (_localDb != null) {
      final backupList = await _localDb.getBackupTransactions(outletId: outletId);
      final pendingRows = await _localDb.getPendingOfflineTransactions();

      final seenKeys = <String>{};

      for (final tx in backupList) {
        final idMatch = tx.id.isNotEmpty && seenKeys.contains(tx.id);
        final reqMatch = tx.clientRequestId != null && tx.clientRequestId!.isNotEmpty && seenKeys.contains(tx.clientRequestId);
        if (!idMatch && !reqMatch) {
          if (tx.id.isNotEmpty) seenKeys.add(tx.id);
          if (tx.clientRequestId != null && tx.clientRequestId!.isNotEmpty) seenKeys.add(tx.clientRequestId!);

          if (tx.status != 'voided') {
            final key = '${tx.createdAt.year.toString().padLeft(4, '0')}-${tx.createdAt.month.toString().padLeft(2, '0')}-${tx.createdAt.day.toString().padLeft(2, '0')}';
            if (trendMap.containsKey(key)) {
              final currVal = trendMap[key]!;
              trendMap[key] = (revenueIdr: currVal.revenueIdr + tx.totalIdr, count: currVal.count + 1);
            }
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
          final dt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : DateTime.now();
          if (dt != null) {
            final key = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            if (trendMap.containsKey(key)) {
              final currVal = trendMap[key]!;
              final tot = row['total_idr'] as int? ?? 0;
              trendMap[key] = (revenueIdr: currVal.revenueIdr + tot, count: currVal.count + 1);
            }
          }
        }
      }
    }

    return trendMap.entries
        .map((e) => SalesTrendPoint(
              date: e.key,
              revenueIdr: e.value.revenueIdr,
              count: e.value.count,
            ))
        .toList();
  }
}
