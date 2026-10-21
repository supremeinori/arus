import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
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

      return serverTxList;
    } catch (_) {
      // OFFLINE: Ambil dari riwayat cache SQLite lokal
      return await _localDb.getBackupTransactions();
    }
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
