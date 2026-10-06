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

  Future<PosTransactionModel> createTransaction({
    required String clientRequestId,
    required String outletId,
    required String paymentMethod,
    required int paidIdr,
    int discountIdr = 0,
    required List<PosCartItem> items,
  }) async {
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
  }

  Future<List<PosTransactionModel>> getTransactions({
    String? outletId,
    String? status,
  }) async {
    final query = <String, dynamic>{};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;
    if (status != null && status.isNotEmpty) query['status'] = status;

    final response = await _client.get<Map<String, dynamic>>(
      '/transactions',
      queryParameters: query,
    );

    final list = response.data?['data'] as List<dynamic>? ?? [];
    return list.map((item) => PosTransactionModel.fromJson(item as Map<String, dynamic>)).toList();
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
