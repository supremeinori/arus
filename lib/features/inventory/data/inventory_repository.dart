import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/inventory_models.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InventoryRepository(apiClient);
});

class InventoryRepository {
  final ApiClient _client;

  InventoryRepository(this._client);

  Future<List<InventoryStockItem>> getStocks({
    String? outletId,
    bool? lowStock,
    String? categoryId,
    String? search,
  }) async {
    final query = <String, dynamic>{};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;
    if (lowStock == true) query['low_stock'] = 'true';
    if (categoryId != null && categoryId.isNotEmpty) query['category_id'] = categoryId;
    if (search != null && search.isNotEmpty) query['q'] = search;

    final response = await _client.get<Map<String, dynamic>>(
      '/inventory/stocks',
      queryParameters: query,
    );

    final list = response.data?['data'] as List<dynamic>? ?? [];
    return list.map((item) => InventoryStockItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> createAdjustment({
    required String outletId,
    required String productId,
    required String movementType,
    required int quantityDelta,
    String? note,
  }) async {
    await _client.post('/inventory/adjustments', data: {
      'outlet_id': outletId,
      'product_id': productId,
      'movement_type': movementType,
      'quantity_delta': quantityDelta,
      'note': note,
    });
  }

  Future<List<InventoryMovementItem>> getMovements({
    String? outletId,
    String? productId,
    String? movementType,
  }) async {
    final query = <String, dynamic>{};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;
    if (productId != null && productId.isNotEmpty) query['product_id'] = productId;
    if (movementType != null && movementType.isNotEmpty) query['movement_type'] = movementType;

    final response = await _client.get<Map<String, dynamic>>(
      '/inventory/movements',
      queryParameters: query,
    );

    final list = response.data?['data'] as List<dynamic>? ?? [];
    return list.map((item) => InventoryMovementItem.fromJson(item as Map<String, dynamic>)).toList();
  }
}
