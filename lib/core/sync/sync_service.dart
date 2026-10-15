import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../storage/local_db.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final client = ref.watch(apiClientProvider);
  final localDb = ref.watch(localDbProvider);
  return SyncService(client, localDb);
});

class SyncResult {
  final int totalPending;
  final int syncedCount;
  final int failedCount;
  final String? message;

  const SyncResult({
    required this.totalPending,
    required this.syncedCount,
    required this.failedCount,
    this.message,
  });
}

class SyncService {
  final ApiClient _client;
  final LocalDatabase _localDb;
  bool _isSyncing = false;

  SyncService(this._client, this._localDb);

  bool get isSyncing => _isSyncing;

  /// Sinkronisasi seluruh transaksi offline yang tertunda ke server Supabase
  Future<SyncResult> syncPendingTransactions() async {
    if (_isSyncing) {
      return const SyncResult(totalPending: 0, syncedCount: 0, failedCount: 0, message: 'Sinkronisasi sedang berjalan.');
    }

    _isSyncing = true;
    int synced = 0;
    int failed = 0;

    try {
      final pendingList = await _localDb.getPendingOfflineTransactions();
      if (pendingList.isEmpty) {
        return const SyncResult(totalPending: 0, syncedCount: 0, failedCount: 0, message: 'Tidak ada transaksi tertunda.');
      }

      for (final txMap in pendingList) {
        final clientRequestId = txMap['client_request_id'] as String;
        final outletId = txMap['outlet_id'] as String;
        final paymentMethod = txMap['payment_method'] as String;
        final paidIdr = txMap['paid_idr'] as int;
        final discountIdr = txMap['discount_idr'] as int? ?? 0;
        final rawItemsJson = txMap['items_json'] as String;

        try {
          final itemsList = (jsonDecode(rawItemsJson) as List<dynamic>)
              .map((it) => {
                    'product_id': it['product_id'],
                    'quantity': it['quantity'],
                  })
              .toList();

          final response = await _client.post<Map<String, dynamic>>(
            '/transactions',
            data: {
              'client_request_id': clientRequestId,
              'outlet_id': outletId,
              'payment_method': paymentMethod,
              'paid_idr': paidIdr,
              'discount_idr': discountIdr,
              'items': itemsList,
            },
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = response.data?['data'] as Map<String, dynamic>?;
            final receiptNo = data?['receipt_no'] as String? ?? txMap['receipt_no'] as String;
            await _localDb.markTransactionSynced(
              clientRequestId: clientRequestId,
              serverReceiptNo: receiptNo,
            );
            synced++;
          } else {
            failed++;
          }
        } catch (e) {
          failed++;
          debugPrint('Sync failed for $clientRequestId: $e');
          await _localDb.markTransactionSyncError(clientRequestId, e.toString());
        }
      }

      return SyncResult(
        totalPending: pendingList.length,
        syncedCount: synced,
        failedCount: failed,
        message: 'Sinkronisasi selesai: $synced berhasil, $failed gagal.',
      );
    } finally {
      _isSyncing = false;
    }
  }
}
