import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/utils/uuid_generator.dart';
import '../domain/pos_models.dart';

final posRepositoryProvider = Provider<PosRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final localDb = ref.watch(localDbProvider);
  return PosRepository(apiClient, localDb);
});

class PosRepository {
  final ApiClient _client;
  final LocalDatabase _localDb;

  PosRepository(this._client, this._localDb);

  Future<PosTransactionModel> createTransaction({
    required String clientRequestId,
    required String outletId,
    required String paymentMethod,
    required int paidIdr,
    int discountIdr = 0,
    required List<PosCartItem> items,
    String? cashierName,
    String? outletName,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/transactions',
        data: {
          'client_request_id': clientRequestId,
          'outlet_id': outletId,
          'payment_method': paymentMethod,
          'paid_idr': paidIdr,
          'discount_idr': discountIdr,
          'items': items
              .map((item) => {
                    'product_id': item.productId,
                    'quantity': item.quantity,
                  })
              .toList(),
        },
      );

      final data = response.data?['data'] as Map<String, dynamic>;
      final transaction = PosTransactionModel.fromJson(data);

      // Simpan receipt ke cadangan SQLite lokal (status synced = true)
      await _localDb.saveOfflineTransaction(
        transaction: transaction,
        clientRequestId: clientRequestId,
        isSynced: true,
      );

      return transaction;
    } on AppException catch (appErr) {
      if (appErr.statusCode != null &&
          appErr.statusCode! >= 400 &&
          appErr.statusCode! < 500) {
        throw Exception(appErr.message);
      }
      return await _saveLocalOfflineTransaction(
        clientRequestId: clientRequestId,
        outletId: outletId,
        paymentMethod: paymentMethod,
        paidIdr: paidIdr,
        discountIdr: discountIdr,
        items: items,
        cashierName: cashierName,
        outletName: outletName,
      );
    } on DioException catch (dioErr) {
      // Jika respons 4xx dari server (misal validasi input atau stok tidak cukup),
      // lemparkan pesan kesalahan langsung ke kasir.
      if (dioErr.response?.statusCode != null &&
          dioErr.response!.statusCode! >= 400 &&
          dioErr.response!.statusCode! < 500) {
        final errData = dioErr.response?.data;
        String msg = 'Transaksi gagal.';
        if (errData is Map && errData['error'] is Map) {
          msg = errData['error']['message'] ?? msg;
        }
        throw Exception(msg);
      }

      // KONDISI OFFLINE: Simpan ke database offline lokal SQLite
      return await _saveLocalOfflineTransaction(
        clientRequestId: clientRequestId,
        outletId: outletId,
        paymentMethod: paymentMethod,
        paidIdr: paidIdr,
        discountIdr: discountIdr,
        items: items,
        cashierName: cashierName,
        outletName: outletName,
      );
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      // Simpan ke antrean offline lokal
      return await _saveLocalOfflineTransaction(
        clientRequestId: clientRequestId,
        outletId: outletId,
        paymentMethod: paymentMethod,
        paidIdr: paidIdr,
        discountIdr: discountIdr,
        items: items,
        cashierName: cashierName,
        outletName: outletName,
      );
    }
  }

  Future<PosTransactionModel> _saveLocalOfflineTransaction({
    required String clientRequestId,
    required String outletId,
    required String paymentMethod,
    required int paidIdr,
    required int discountIdr,
    required List<PosCartItem> items,
    String? cashierName,
    String? outletName,
  }) async {
    final subtotal = items.fold<int>(0, (sum, i) => sum + i.lineTotalIdr);
    final total = (subtotal - discountIdr).clamp(0, 999999999).toInt();
    final change = (paidIdr - total).clamp(0, 999999999).toInt();
    final now = DateTime.now();
    final datePart = now.toIso8601String().slice(0, 10).replaceAll('-', '');
    final receiptSuffix = now.millisecondsSinceEpoch.toString().substring(8);
    final receiptNo = 'OFF-$datePart-$receiptSuffix';

    final offlineTx = PosTransactionModel(
      id: UuidGenerator.v4(),
      receiptNo: receiptNo,
      outletId: outletId,
      outletName: outletName ?? 'Outlet ARUS',
      cashierName: cashierName ?? 'Kasir Utama',
      subtotalIdr: subtotal,
      discountIdr: discountIdr,
      totalIdr: total,
      paymentMethod: paymentMethod,
      paidIdr: paidIdr,
      changeIdr: change,
      status: 'offline_pending',
      createdAt: now,
      items: List.from(items),
      isOfflinePending: true,
      clientRequestId: clientRequestId,
    );

    // Simpan ke tabel SQLite offline_transactions & backup_transactions (is_synced = 0)
    await _localDb.saveOfflineTransaction(
      transaction: offlineTx,
      clientRequestId: clientRequestId,
      isSynced: false,
    );

    return offlineTx;
  }

  Future<List<PosTransactionModel>> getTransactions({
    String? outletId,
    String? status,
    String? from,
    String? to,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (from != null && from.isNotEmpty) query['from'] = from;
      if (to != null && to.isNotEmpty) query['to'] = to;
      // Riwayat dashboard butuh daftar panjang, bukan satu halaman 20 baris.
      query['page'] = 1;
      query['page_size'] = 100;

      final response = await _client.get<Map<String, dynamic>>(
        '/transactions',
        queryParameters: query,
      );

      final list = response.data?['data'] as List<dynamic>? ?? [];
      final serverTxList = list
          .map((item) => PosTransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();

      // Perbarui cache backup_transactions dengan transaksi terbaru dari server
      for (final tx in serverTxList.take(20)) {
        await _localDb.backupTransaction({
          'transaction_id': tx.id,
          'receipt_no': tx.receiptNo,
          'outlet_name': tx.outletName,
          'total_idr': tx.totalIdr,
          'payment_method': tx.paymentMethod,
          'status': tx.status,
          'raw_json': jsonEncode(tx.toJson()),
          'created_at': tx.createdAt.toIso8601String(),
        });
      }

      // Ambil transaksi offline lokal yang belum tersinkronisasi agar tidak lenyap saat kasir online
      final pendingRows = await _localDb.getPendingOfflineTransactions();
      final unconfirmedPending = <PosTransactionModel>[];

      for (final row in pendingRows) {
        final rowOutletId = row['outlet_id'] as String?;
        if (outletId != null && outletId.isNotEmpty && rowOutletId != null && rowOutletId.isNotEmpty && rowOutletId != outletId) {
          continue;
        }

        final clientReqId = row['client_request_id'] as String?;
        final rowId = row['id'] as String?;

        // Jika transaksi sudah ada di respons server, berarti sudah tersinkronisasi
        final alreadyInServer = serverTxList.any((stx) =>
            (clientReqId != null && clientReqId.isNotEmpty && stx.clientRequestId == clientReqId) ||
            (rowId != null && rowId.isNotEmpty && stx.id == rowId));

        if (!alreadyInServer) {
          List<PosCartItem> parsedItems = [];
          try {
            final rawItems = jsonDecode(row['items_json'] as String) as List<dynamic>;
            parsedItems = rawItems.map((item) {
              final m = item as Map<String, dynamic>;
              return PosCartItem(
                productId: m['product_id'] as String? ?? '',
                productName: m['product_name_snapshot'] as String? ?? m['product_name'] as String? ?? '',
                sku: m['sku'] as String? ?? '',
                unitPriceIdr: m['unit_price_idr'] as int? ?? 0,
                quantity: m['quantity'] as int? ?? 1,
              );
            }).toList();
          } catch (_) {}

          unconfirmedPending.add(PosTransactionModel(
            id: row['id'] as String? ?? '',
            receiptNo: row['receipt_no'] as String? ?? '',
            outletId: row['outlet_id'] as String? ?? '',
            outletName: 'Outlet ARUS',
            cashierName: row['cashier_name'] as String? ?? 'Kasir Utama',
            subtotalIdr: row['subtotal_idr'] as int? ?? 0,
            discountIdr: row['discount_idr'] as int? ?? 0,
            totalIdr: row['total_idr'] as int? ?? 0,
            paymentMethod: row['payment_method'] as String? ?? 'cash',
            paidIdr: row['paid_idr'] as int? ?? 0,
            changeIdr: row['change_idr'] as int? ?? 0,
            status: row['sync_error'] != null ? 'failed' : 'offline_pending',
            createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
            items: parsedItems,
            isOfflinePending: true,
            clientRequestId: clientReqId,
          ));
        }
      }

      // Tampilkan transaksi pending lokal di paling atas
      return [...unconfirmedPending, ...serverTxList];
    } catch (_) {
      // OFFLINE: Ambil dari riwayat cache SQLite lokal + antrean pending
      return await _getLocalTransactions(
        outletId: outletId,
        status: status,
        from: from,
        to: to,
      );
    }
  }

  Future<List<PosTransactionModel>> _getLocalTransactions({
    String? outletId,
    String? status,
    String? from,
    String? to,
  }) async {
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
    final unconfirmedPending = <PosTransactionModel>[];
    final confirmedOrBackup = <PosTransactionModel>[];

    for (final row in pendingRows) {
      final rowOutletId = row['outlet_id'] as String?;
      if (outletId != null && outletId.isNotEmpty && rowOutletId != null && rowOutletId.isNotEmpty && rowOutletId != outletId) {
        continue;
      }
      final clientReqId = row['client_request_id'] as String?;
      final rowId = row['id'] as String?;

      if (rowId != null && rowId.isNotEmpty) seenKeys.add(rowId);
      if (clientReqId != null && clientReqId.isNotEmpty) seenKeys.add(clientReqId);

      final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();
      if (startDate != null && createdAt.isBefore(startDate)) continue;
      if (endDate != null && createdAt.isAfter(endDate)) continue;

      final rowStatus = row['sync_error'] != null ? 'failed' : 'offline_pending';
      if (status != null && status.isNotEmpty && rowStatus != status) continue;

      List<PosCartItem> parsedItems = [];
      try {
        final rawItems = jsonDecode(row['items_json'] as String) as List<dynamic>;
        parsedItems = rawItems.map((item) {
          final m = item as Map<String, dynamic>;
          return PosCartItem(
            productId: m['product_id'] as String? ?? '',
            productName: m['product_name_snapshot'] as String? ?? m['product_name'] as String? ?? '',
            sku: m['sku'] as String? ?? '',
            unitPriceIdr: m['unit_price_idr'] as int? ?? 0,
            quantity: m['quantity'] as int? ?? 1,
          );
        }).toList();
      } catch (_) {}

      unconfirmedPending.add(PosTransactionModel(
        id: row['id'] as String? ?? '',
        receiptNo: row['receipt_no'] as String? ?? '',
        outletId: row['outlet_id'] as String? ?? '',
        outletName: 'Outlet ARUS',
        cashierName: row['cashier_name'] as String? ?? 'Kasir Utama',
        subtotalIdr: row['subtotal_idr'] as int? ?? 0,
        discountIdr: row['discount_idr'] as int? ?? 0,
        totalIdr: row['total_idr'] as int? ?? 0,
        paymentMethod: row['payment_method'] as String? ?? 'cash',
        paidIdr: row['paid_idr'] as int? ?? 0,
        changeIdr: row['change_idr'] as int? ?? 0,
        status: rowStatus,
        createdAt: createdAt,
        items: parsedItems,
        isOfflinePending: true,
        clientRequestId: clientReqId,
      ));
    }

    for (final tx in backupList) {
      final idMatch = tx.id.isNotEmpty && seenKeys.contains(tx.id);
      final reqMatch = tx.clientRequestId != null && tx.clientRequestId!.isNotEmpty && seenKeys.contains(tx.clientRequestId);
      if (!idMatch && !reqMatch) {
        if (tx.id.isNotEmpty) seenKeys.add(tx.id);
        if (tx.clientRequestId != null && tx.clientRequestId!.isNotEmpty) seenKeys.add(tx.clientRequestId!);

        if (status != null && status.isNotEmpty && tx.status != status) continue;
        if (startDate != null && tx.createdAt.isBefore(startDate)) continue;
        if (endDate != null && tx.createdAt.isAfter(endDate)) continue;

        confirmedOrBackup.add(tx);
      }
    }

    return [...unconfirmedPending, ...confirmedOrBackup];
  }

  Future<PosTransactionModel> voidTransaction({
    required String transactionId,
    required String reason,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/transactions/$transactionId/void',
      data: {'reason': reason},
    );

    final data = response.data?['data'] as Map<String, dynamic>;
    return PosTransactionModel.fromJson(data);
  }
}

extension on String {
  String slice(int start, [int? end]) {
    final s = start < 0 ? length + start : start;
    final e = end == null
        ? length
        : end < 0
            ? length + end
            : end;
    return substring(s.clamp(0, length), e.clamp(0, length));
  }
}
