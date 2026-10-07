import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/pos_models.dart';

final posRepositoryProvider = Provider<PosRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PosRepository(apiClient);
});

class PosRepository {
  final ApiClient _client;

  PosRepository(this._client);

  static final List<PosTransactionModel> _demoTransactions = [
    PosTransactionModel(
      id: 'trx-demo-01',
      receiptNo: 'RCP-892101',
      outletId: 'out-001',
      outletName: 'ARUS Coffee Sudirman HQ',
      cashierName: 'Siti Rahma (Kasir)',
      subtotalIdr: 44000,
      discountIdr: 0,
      totalIdr: 44000,
      paymentMethod: 'qris',
      paidIdr: 44000,
      changeIdr: 0,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      items: const [
        PosCartItem(
          productId: 'p-01',
          productName: 'Kopi Susu Gula Aren',
          sku: 'KOP-01',
          unitPriceIdr: 22000,
          quantity: 2,
        ),
      ],
    ),
    PosTransactionModel(
      id: 'trx-demo-02',
      receiptNo: 'RCP-892102',
      outletId: 'out-001',
      outletName: 'ARUS Coffee Sudirman HQ',
      cashierName: 'Siti Rahma (Kasir)',
      subtotalIdr: 53000,
      discountIdr: 5000,
      totalIdr: 48000,
      paymentMethod: 'cash',
      paidIdr: 50000,
      changeIdr: 2000,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
      items: const [
        PosCartItem(
          productId: 'p-03',
          productName: 'Matcha Latte Oatmilk',
          sku: 'NON-01',
          unitPriceIdr: 28000,
          quantity: 1,
        ),
        PosCartItem(
          productId: 'p-05',
          productName: 'Butter Croissant Premium',
          sku: 'PAS-01',
          unitPriceIdr: 25000,
          quantity: 1,
        ),
      ],
    ),
  ];

  Future<PosTransactionModel> createTransaction({
    required String clientRequestId,
    required String outletId,
    required String paymentMethod,
    required int paidIdr,
    int discountIdr = 0,
    required List<PosCartItem> items,
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
      return PosTransactionModel.fromJson(data);
    } catch (_) {
      final subtotal = items.fold<int>(0, (sum, i) => sum + i.lineTotalIdr);
      final total = (subtotal - discountIdr).clamp(0, 999999999).toInt();
      final change = (paidIdr - total).clamp(0, 999999999).toInt();
      final now = DateTime.now();
      final receiptSuffix = now.millisecondsSinceEpoch.toString().substring(7);

      final demoTrx = PosTransactionModel(
        id: 'trx-$receiptSuffix',
        receiptNo: 'RCP-$receiptSuffix',
        outletId: outletId,
        outletName: 'ARUS Coffee Sudirman HQ',
        cashierName: 'Kasir Utama',
        subtotalIdr: subtotal,
        discountIdr: discountIdr,
        totalIdr: total,
        paymentMethod: paymentMethod,
        paidIdr: paidIdr,
        changeIdr: change,
        status: 'completed',
        createdAt: now,
        items: List.from(items),
      );
      _demoTransactions.insert(0, demoTrx);
      return demoTrx;
    }
  }

  Future<List<PosTransactionModel>> getTransactions({
    String? outletId,
    String? status,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;
      if (status != null && status.isNotEmpty) query['status'] = status;

      final response = await _client.get<Map<String, dynamic>>(
        '/transactions',
        queryParameters: query,
      );

      final list = response.data?['data'] as List<dynamic>? ?? [];
      return list.map((item) => PosTransactionModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return List.unmodifiable(_demoTransactions);
    }
  }

  Future<PosTransactionModel> voidTransaction({
    required String transactionId,
    required String reason,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/transactions/$transactionId/void',
        data: {'reason': reason},
      );

      final data = response.data?['data'] as Map<String, dynamic>;
      return PosTransactionModel.fromJson(data);
    } catch (_) {
      final index = _demoTransactions.indexWhere((t) => t.id == transactionId);
      if (index != -1) {
        final existing = _demoTransactions[index];
        final voided = PosTransactionModel(
          id: existing.id,
          receiptNo: existing.receiptNo,
          outletId: existing.outletId,
          outletName: existing.outletName,
          cashierName: existing.cashierName,
          subtotalIdr: existing.subtotalIdr,
          discountIdr: existing.discountIdr,
          totalIdr: existing.totalIdr,
          paymentMethod: existing.paymentMethod,
          paidIdr: existing.paidIdr,
          changeIdr: existing.changeIdr,
          status: 'voided',
          voidReason: reason,
          createdAt: existing.createdAt,
          items: existing.items,
        );
        _demoTransactions[index] = voided;
        return voided;
      }
      return _demoTransactions.first;
    }
  }
}
