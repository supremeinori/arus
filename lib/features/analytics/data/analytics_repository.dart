import 'dart:math' as math;
import 'dart:convert';
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

    final cacheKey = 'overview_${outletId ?? "all"}_${from ?? ""}_${to ?? ""}';

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/analytics/overview',
        queryParameters: query,
      );
      final data = response.data?['data'] as Map<String, dynamic>;
      final base = AnalyticsOverviewModel.fromJson(data);

      if (_localDb != null) {
        await _localDb.saveDailyAnalyticsCache(
          cacheKey: cacheKey,
          payload: jsonEncode(data),
        );

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
        final cachedPayload = await _localDb.getDailyAnalyticsCache(cacheKey);
        if (cachedPayload != null && cachedPayload.isNotEmpty) {
          try {
            final cachedData = jsonDecode(cachedPayload) as Map<String, dynamic>;
            final cachedBase = AnalyticsOverviewModel.fromJson(cachedData);
            final pendingRows = await _localDb.getPendingOfflineTransactions();
            final pending = _filterLocalRows(pendingRows, outletId: outletId, from: from, to: to);
            final pendingRev = pending.fold<int>(0, (s, r) => s + (r['total_idr'] as int? ?? 0));
            return cachedBase.copyWith(
              revenueIdr: cachedBase.revenueIdr + pendingRev,
              transactionCount: cachedBase.transactionCount + pending.length,
              pendingCount: pending.length,
              isOffline: true,
            );
          } catch (_) {}
        }
        return await _computeLocalOverview(outletId: outletId, from: from, to: to);
      }
      rethrow;
    } catch (_) {
      if (_localDb != null) {
        final cachedPayload = await _localDb.getDailyAnalyticsCache(cacheKey);
        if (cachedPayload != null && cachedPayload.isNotEmpty) {
          try {
            final cachedData = jsonDecode(cachedPayload) as Map<String, dynamic>;
            final cachedBase = AnalyticsOverviewModel.fromJson(cachedData);
            final pendingRows = await _localDb.getPendingOfflineTransactions();
            final pending = _filterLocalRows(pendingRows, outletId: outletId, from: from, to: to);
            final pendingRev = pending.fold<int>(0, (s, r) => s + (r['total_idr'] as int? ?? 0));
            return cachedBase.copyWith(
              revenueIdr: cachedBase.revenueIdr + pendingRev,
              transactionCount: cachedBase.transactionCount + pending.length,
              pendingCount: pending.length,
              isOffline: true,
            );
          } catch (_) {}
        }
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

    final cacheKey = 'sales_trend_${outletId ?? "all"}_${days ?? 0}_${from ?? ""}_${to ?? ""}';

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/analytics/sales-trend',
        queryParameters: query,
      );
      final list = response.data?['data'] as List<dynamic>? ?? [];
      var points = list.map((item) => SalesTrendPoint.fromJson(item as Map<String, dynamic>)).toList();

      if (_localDb != null) {
        await _localDb.saveDailyAnalyticsCache(
          cacheKey: cacheKey,
          payload: jsonEncode(list),
        );

        final pendingRows = await _localDb.getPendingOfflineTransactions();
        final pending = _filterLocalRows(pendingRows, outletId: outletId, from: from, to: to);
        if (pending.isNotEmpty) {
          points = _mergePendingIntoSalesTrend(points, pending);
        }
      }

      return points;
    } on AppException {
      if (_localDb != null) {
        final cachedPayload = await _localDb.getDailyAnalyticsCache(cacheKey);
        if (cachedPayload != null && cachedPayload.isNotEmpty) {
          try {
            final cachedList = jsonDecode(cachedPayload) as List<dynamic>? ?? [];
            var cachedPoints = cachedList.map((item) => SalesTrendPoint.fromJson(item as Map<String, dynamic>)).toList();
            final pendingRows = await _localDb.getPendingOfflineTransactions();
            final pending = _filterLocalRows(pendingRows, outletId: outletId, from: from, to: to);
            if (pending.isNotEmpty) {
              cachedPoints = _mergePendingIntoSalesTrend(cachedPoints, pending);
            }
            return cachedPoints;
          } catch (_) {}
        }
        return await _computeLocalSalesTrend(outletId: outletId, days: days, from: from, to: to);
      }
      rethrow;
    } catch (_) {
      if (_localDb != null) {
        final cachedPayload = await _localDb.getDailyAnalyticsCache(cacheKey);
        if (cachedPayload != null && cachedPayload.isNotEmpty) {
          try {
            final cachedList = jsonDecode(cachedPayload) as List<dynamic>? ?? [];
            var cachedPoints = cachedList.map((item) => SalesTrendPoint.fromJson(item as Map<String, dynamic>)).toList();
            final pendingRows = await _localDb.getPendingOfflineTransactions();
            final pending = _filterLocalRows(pendingRows, outletId: outletId, from: from, to: to);
            if (pending.isNotEmpty) {
              cachedPoints = _mergePendingIntoSalesTrend(cachedPoints, pending);
            }
            return cachedPoints;
          } catch (_) {}
        }
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

    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final cacheKey = 'shift_summary_${outletId ?? "all"}_$todayKey';

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/analytics/shift-summary',
        queryParameters: query,
      );
      final data = response.data?['data'] as Map<String, dynamic>;

      int pendingCount = 0;
      if (_localDb != null) {
        await _localDb.saveDailyAnalyticsCache(
          cacheKey: cacheKey,
          payload: jsonEncode(data),
        );

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
        final cachedPayload = await _localDb.getDailyAnalyticsCache(cacheKey);
        if (cachedPayload != null && cachedPayload.isNotEmpty) {
          try {
            final cachedData = jsonDecode(cachedPayload) as Map<String, dynamic>;
            final cachedModel = ShiftSummaryModel.fromJson(cachedData);
            final pendingRows = await _localDb.getPendingOfflineTransactions();
            final startOfToday = DateTime(now.year, now.month, now.day);
            final todayPending = pendingRows.where((r) {
              if (outletId != null && outletId.isNotEmpty) {
                final rowOutlet = r['outlet_id'] as String?;
                if (rowOutlet != null && rowOutlet.isNotEmpty && rowOutlet != outletId) return false;
              }
              final dt = DateTime.tryParse(r['created_at'] as String? ?? '');
              return dt == null || !dt.isBefore(startOfToday);
            }).toList();

            final pendingRev = todayPending.fold<int>(0, (s, r) => s + (r['total_idr'] as int? ?? 0));
            final pendingCash = todayPending.where((r) => r['payment_method'] == 'cash').fold<int>(0, (s, r) => s + (r['total_idr'] as int? ?? 0));
            final pendingQris = pendingRev - pendingCash;

            return ShiftSummaryModel(
              todayRevenueIdr: cachedModel.todayRevenueIdr + pendingRev,
              cashRevenueIdr: cachedModel.cashRevenueIdr + pendingCash,
              qrisRevenueIdr: cachedModel.qrisRevenueIdr + pendingQris,
              transactionCount: cachedModel.transactionCount + todayPending.length,
              isOffline: true,
              pendingCount: todayPending.length,
              isDataAvailable: true,
            );
          } catch (_) {}
        }
        return await _computeLocalShiftSummary(outletId: outletId);
      }
      rethrow;
    } catch (_) {
      if (_localDb != null) {
        final cachedPayload = await _localDb.getDailyAnalyticsCache(cacheKey);
        if (cachedPayload != null && cachedPayload.isNotEmpty) {
          try {
            final cachedData = jsonDecode(cachedPayload) as Map<String, dynamic>;
            final cachedModel = ShiftSummaryModel.fromJson(cachedData);
            final pendingRows = await _localDb.getPendingOfflineTransactions();
            final startOfToday = DateTime(now.year, now.month, now.day);
            final todayPending = pendingRows.where((r) {
              if (outletId != null && outletId.isNotEmpty) {
                final rowOutlet = r['outlet_id'] as String?;
                if (rowOutlet != null && rowOutlet.isNotEmpty && rowOutlet != outletId) return false;
              }
              final dt = DateTime.tryParse(r['created_at'] as String? ?? '');
              return dt == null || !dt.isBefore(startOfToday);
            }).toList();

            final pendingRev = todayPending.fold<int>(0, (s, r) => s + (r['total_idr'] as int? ?? 0));
            final pendingCash = todayPending.where((r) => r['payment_method'] == 'cash').fold<int>(0, (s, r) => s + (r['total_idr'] as int? ?? 0));
            final pendingQris = pendingRev - pendingCash;

            return ShiftSummaryModel(
              todayRevenueIdr: cachedModel.todayRevenueIdr + pendingRev,
              cashRevenueIdr: cachedModel.cashRevenueIdr + pendingCash,
              qrisRevenueIdr: cachedModel.qrisRevenueIdr + pendingQris,
              transactionCount: cachedModel.transactionCount + todayPending.length,
              isOffline: true,
              pendingCount: todayPending.length,
              isDataAvailable: true,
            );
          } catch (_) {}
        }
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
      if (_localDb != null) {
        return await _computeLocalSalesForecast(outletId: outletId, horizonDays: horizon);
      }
      rethrow;
    } catch (_) {
      if (_localDb != null) {
        return await _computeLocalSalesForecast(outletId: outletId, horizonDays: horizon);
      }
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
      if (_localDb != null) {
        return _computeOfflineStockoutForecast();
      }
      rethrow;
    } catch (_) {
      if (_localDb != null) {
        return _computeOfflineStockoutForecast();
      }
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

    final cacheKey = 'leaderboard_${outletId ?? "all"}_${limit}_${from ?? ""}_${to ?? ""}';

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/analytics/leaderboard',
        queryParameters: query,
      );
      final list = response.data?['data'] as List<dynamic>? ?? [];

      if (_localDb != null) {
        await _localDb.saveDailyAnalyticsCache(
          cacheKey: cacheKey,
          payload: jsonEncode(list),
        );
      }

      return list.map((item) => TopSellingProductModel.fromJson(item as Map<String, dynamic>)).toList();
    } on AppException {
      if (_localDb != null) {
        final cachedPayload = await _localDb.getDailyAnalyticsCache(cacheKey);
        if (cachedPayload != null && cachedPayload.isNotEmpty) {
          try {
            final cachedList = jsonDecode(cachedPayload) as List<dynamic>? ?? [];
            return cachedList.map((item) => TopSellingProductModel.fromJson(item as Map<String, dynamic>)).toList();
          } catch (_) {}
        }
        return [];
      }
      rethrow;
    } catch (_) {
      if (_localDb != null) {
        final cachedPayload = await _localDb.getDailyAnalyticsCache(cacheKey);
        if (cachedPayload != null && cachedPayload.isNotEmpty) {
          try {
            final cachedList = jsonDecode(cachedPayload) as List<dynamic>? ?? [];
            return cachedList.map((item) => TopSellingProductModel.fromJson(item as Map<String, dynamic>)).toList();
          } catch (_) {}
        }
        return [];
      }
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
      startDate = DateTime.tryParse('${from}T00:00:00.000Z') ?? DateTime.tryParse(from) ?? DateTime.now();
      endDate = to != null && to.isNotEmpty
          ? (DateTime.tryParse('${to}T23:59:59.999Z') ?? DateTime.tryParse(to) ?? DateTime.now())
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
  static const _indonesianDays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  String _dayNameOf(DateTime dt) => _indonesianDays[dt.weekday - 1];

  StockoutForecastModel _computeOfflineStockoutForecast() {
    return const StockoutForecastModel(
      summary: StockoutSummary(
        criticalCount: 0,
        warningCount: 0,
        safeCount: 0,
        totalItems: 0,
        aiRecommendation: 'Mode offline: Analisis peramalan stok bahan memerlukan sinkronisasi data inventaris dari server.',
      ),
      items: [],
    );
  }

  Future<SalesForecastModel> _computeLocalSalesForecast({
    String? outletId,
    int horizonDays = 7,
  }) async {
    final effectiveHorizon = horizonDays > 0 ? horizonDays : 7;
    final historyDays = math.max(effectiveHorizon * 2, 30);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final histStart = today.subtract(Duration(days: historyDays - 1));

    // Kalender histori kontinu: setiap hari selalu ada, termasuk yang bernilai 0.
    final historicalMap = <String, int>{};
    var currHist = DateTime(histStart.year, histStart.month, histStart.day);
    while (!currHist.isAfter(today)) {
      final key = '${currHist.year.toString().padLeft(4, '0')}-${currHist.month.toString().padLeft(2, '0')}-${currHist.day.toString().padLeft(2, '0')}';
      historicalMap[key] = 0;
      currHist = currHist.add(const Duration(days: 1));
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
            if (historicalMap.containsKey(key)) {
              historicalMap[key] = (historicalMap[key] ?? 0) + tx.totalIdr;
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
            if (historicalMap.containsKey(key)) {
              final tot = row['total_idr'] as int? ?? 0;
              historicalMap[key] = (historicalMap[key] ?? 0) + tot;
            }
          }
        }
      }
    }

    final historicalPoints = historicalMap.entries.map((e) {
      final dt = DateTime.tryParse(e.key) ?? DateTime.now();
      return ForecastPoint(
        date: e.key,
        dayName: _dayNameOf(dt),
        revenueIdr: e.value,
        lowerBoundIdr: e.value,
        upperBoundIdr: e.value,
        isProjected: false,
      );
    }).toList();

    final totalHistRev = historicalPoints.fold<int>(0, (s, p) => s + p.revenueIdr);
    final activeDays = historicalPoints.where((p) => p.revenueIdr > 0).length;

    if (activeDays == 0 || totalHistRev == 0) {
      final forecastPoints = <ForecastPoint>[];
      var currFcst = DateTime(today.year, today.month, today.day);
      for (int i = 0; i < effectiveHorizon; i++) {
        final key =
            '${currFcst.year.toString().padLeft(4, '0')}-${currFcst.month.toString().padLeft(2, '0')}-${currFcst.day.toString().padLeft(2, '0')}';
        forecastPoints.add(ForecastPoint(
          date: key,
          dayName: _dayNameOf(currFcst),
          revenueIdr: 0,
          lowerBoundIdr: 0,
          upperBoundIdr: 0,
          isProjected: true,
        ));
        currFcst = currFcst.add(const Duration(days: 1));
      }

      return SalesForecastModel(
        horizonDays: effectiveHorizon,
        historical: historicalPoints,
        forecast: forecastPoints,
        summary: SalesForecastSummary(
          projectedTotalRevenueIdr: 0,
          previousPeriodRevenueIdr: 0,
          growthPct: 0.0,
          avgDailyProjectedIdr: 0,
          peakProjectedDay: PeakProjectedDay(
            date: forecastPoints.first.date,
            dayName: forecastPoints.first.dayName,
            revenueIdr: 0,
          ),
          aiInsight:
              'Mode offline: Belum ada transaksi penjualan lokal. Catat transaksi di kasir untuk mengaktifkan peramalan deret waktu AI.',
        ),
        evaluation: const SalesForecastEvaluation(
          status: 'offline_insufficient_history',
          trainDays: 0,
          testDays: 0,
          seasonalNaiveMae: 0.0,
          modelMae: 0.0,
          chosenModel: 'zero_baseline',
        ),
      );
    }

    // Hari berjalan (parsial) dikeluarkan dari pemodelan agar omzet setengah hari
    // tidak menekan baseline. Hari selesai tetap dipakai, termasuk yang bernilai 0.
    var modelEntries = historicalPoints.sublist(0, historicalPoints.length - 1);
    if (modelEntries.isEmpty || modelEntries.every((p) => p.revenueIdr == 0)) {
      modelEntries = List<ForecastPoint>.from(historicalPoints);
    }

    // Mulai dari hari penjualan pertama agar nol sebelum toko buka tidak menggeser tren.
    final firstActiveIdx = modelEntries.indexWhere((p) => p.revenueIdr > 0);
    final win = modelEntries.sublist(firstActiveIdx >= 0 ? firstActiveIdx : 0);
    final winValues = win.map((p) => p.revenueIdr).toList();
    final winDays = winValues.length;

    // 1. Base level recency-aware: EWMA (alpha 0.35). Hari 0 ikut menurunkan baseline.
    const double alpha = 0.35;
    double ewma = winValues.isNotEmpty ? winValues.first.toDouble() : 0.0;
    for (int i = 1; i < winDays; i++) {
      ewma = alpha * winValues[i] + (1 - alpha) * ewma;
    }
    final overallAvg = winDays > 0 ? winValues.fold<int>(0, (a, b) => a + b) / winDays : 0.0;
    final baseLevel = math.max(1, ewma.round());

    // 2. Musiman day-of-week dengan Bayesian shrinkage (termasuk hari 0).
    final rawRetailPrior = <int, double>{
      1: 0.82, // Senin
      2: 0.87, // Selasa
      3: 0.92, // Rabu
      4: 0.97, // Kamis
      5: 1.16, // Jumat
      6: 1.35, // Sabtu
      7: 1.25, // Minggu
    };

    final dowMultipliers = <int, double>{};
    for (int w = 1; w <= 7; w++) {
      double sum = 0;
      int count = 0;
      for (final p in win) {
        final dt = DateTime.tryParse(p.date);
        if (dt != null && dt.weekday == w) {
          sum += p.revenueIdr;
          count++;
        }
      }
      final dowAvg = count > 0 ? sum / count : overallAvg;
      final empMult = overallAvg > 0 ? dowAvg / overallAvg : 1.0;
      final credibility = count / (count + 5.0);
      final blended = credibility * empMult + (1.0 - credibility) * (rawRetailPrior[w] ?? 1.0);
      dowMultipliers[w] = blended.clamp(0.60, 1.80);
    }

    // 3. Tren linear pada indeks kalender (14 hari selesai terakhir, hari 0 ikut).
    final regWindow = math.min(winDays, 14);
    final regStart = winDays - regWindow;
    double slope = 0.0;
    if (regWindow >= 3) {
      double sumX = 0;
      double sumY = 0;
      double sumXY = 0;
      double sumXX = 0;
      for (int i = 0; i < regWindow; i++) {
        final v = winValues[regStart + i].toDouble();
        sumX += i;
        sumY += v;
        sumXY += i * v;
        sumXX += i * i;
      }
      final denom = regWindow * sumXX - sumX * sumX;
      final rawSlope = denom != 0 ? (regWindow * sumXY - sumX * sumY) / denom : 0.0;
      final maxSlope = 0.06 * baseLevel;
      slope = rawSlope.clamp(-maxSlope, maxSlope);
    }

    // 4. Drought factor: makin lama 0 berturut-turut, proyeksi makin ditekan.
    int streakZero = 0;
    for (int i = winValues.length - 1; i >= 0; i--) {
      if (winValues[i] == 0) {
        streakZero++;
      } else {
        break;
      }
    }
    double drought = 1.0;
    if (streakZero >= 2) {
      drought = math.pow(0.7, math.min(streakZero - 1, 6)).toDouble();
    } else if (streakZero == 1) {
      drought = 0.85;
    }

    // 5. Volatilitas residual untuk confidence interval (kalender, hari 0 ikut).
    double residualSumSq = 0;
    for (int i = 0; i < regWindow; i++) {
      final p = win[regStart + i];
      final dt = DateTime.tryParse(p.date);
      final w = dt?.weekday ?? 1;
      final mult = dowMultipliers[w] ?? 1.0;
      final expected = (baseLevel + slope * (i - (regWindow - 1) / 2)) * mult;
      final diff = p.revenueIdr - expected;
      residualSumSq += diff * diff;
    }
    final sampleStdDev = math.sqrt(residualSumSq / math.max(1, regWindow - 1));
    final baseStdDev = math.max(baseLevel * 0.12, sampleStdDev);

    const double phi = 0.92;
    final forecastPoints = <ForecastPoint>[];
    var currFcst = DateTime(today.year, today.month, today.day);

    for (int h = 1; h <= effectiveHorizon; h++) {
      final key =
          '${currFcst.year.toString().padLeft(4, '0')}-${currFcst.month.toString().padLeft(2, '0')}-${currFcst.day.toString().padLeft(2, '0')}';
      final w = currFcst.weekday;
      final mult = dowMultipliers[w] ?? 1.0;

      final dampenedTrend = slope * (phi * (1 - math.pow(phi, h)) / (1 - phi));
      final trendBase = math.max(baseLevel * 0.4, baseLevel + dampenedTrend);
      final predicted = math.max(0, (trendBase * mult * drought).round());

      final horizonUncertainty = math.sqrt(1.0 + 0.05 * (h - 1));
      final marginOfError = math.max((predicted * 0.12).round(), (1.28 * baseStdDev * horizonUncertainty).round());
      final lowerBound = math.max(0, predicted - marginOfError);
      final upperBound = predicted + marginOfError;

      forecastPoints.add(ForecastPoint(
        date: key,
        dayName: _dayNameOf(currFcst),
        revenueIdr: predicted,
        lowerBoundIdr: lowerBound,
        upperBoundIdr: upperBound,
        isProjected: true,
      ));
      currFcst = currFcst.add(const Duration(days: 1));
    }

    final projectedTotalRevenue = forecastPoints.fold<int>(0, (s, p) => s + p.revenueIdr);
    final recentWindow = modelEntries.length > effectiveHorizon
        ? modelEntries.sublist(modelEntries.length - effectiveHorizon)
        : modelEntries;
    final previousPeriodRevenue = recentWindow.fold<int>(0, (s, p) => s + p.revenueIdr);
    final growthPct = previousPeriodRevenue > 0
        ? ((projectedTotalRevenue - previousPeriodRevenue) / previousPeriodRevenue * 100)
        : 0.0;
    final avgDailyProjected = effectiveHorizon > 0 ? (projectedTotalRevenue ~/ effectiveHorizon) : 0;

    ForecastPoint peakDay = forecastPoints.first;
    for (final p in forecastPoints) {
      if (p.revenueIdr > peakDay.revenueIdr) {
        peakDay = p;
      }
    }

    final growthSign = growthPct >= 0 ? '+' : '';
    final aiInsight = streakZero >= 2
        ? 'Mode offline: $streakZero hari terakhir tanpa transaksi. Proyeksi omzet $effectiveHorizon hari ke depan diturunkan menjadi Rp $projectedTotalRevenue ($growthSign${growthPct.toStringAsFixed(1)}% vs $effectiveHorizon hari terakhir).'
        : activeDays < 7
            ? 'Mode offline: Proyeksi dihitung dari data aktif $activeDays hari dengan pola musiman ritel (puncak ${peakDay.dayName}). Estimasi $effectiveHorizon hari ke depan Rp $projectedTotalRevenue ($growthSign${growthPct.toStringAsFixed(1)}% vs $effectiveHorizon hari terakhir).'
            : 'Mode offline: Proyeksi dihitung dari data aktif $activeDays hari. Estimasi omzet $effectiveHorizon hari ke depan Rp $projectedTotalRevenue ($growthSign${growthPct.toStringAsFixed(1)}% vs $effectiveHorizon hari terakhir) dengan puncak ${peakDay.dayName} (Rp ${peakDay.revenueIdr}).';

    return SalesForecastModel(
      horizonDays: effectiveHorizon,
      historical: historicalPoints,
      forecast: forecastPoints,
      summary: SalesForecastSummary(
        projectedTotalRevenueIdr: projectedTotalRevenue,
        previousPeriodRevenueIdr: previousPeriodRevenue,
        growthPct: growthPct,
        avgDailyProjectedIdr: avgDailyProjected,
        peakProjectedDay: PeakProjectedDay(
          date: peakDay.date,
          dayName: peakDay.dayName,
          revenueIdr: peakDay.revenueIdr,
        ),
        aiInsight: aiInsight,
      ),
      evaluation: SalesForecastEvaluation(
        status: 'offline_evaluated',
        trainDays: activeDays,
        testDays: 0,
        seasonalNaiveMae: 0.0,
        modelMae: 0.0,
        chosenModel: 'ewma_bayesian_seasonal_dampened',
      ),
    );
  }
}
