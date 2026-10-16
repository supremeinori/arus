import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../domain/inventory_models.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InventoryRepository(apiClient);
});

class InventoryRepository {
  final ApiClient _client;

  InventoryRepository(this._client);

  Future<List<IngredientModel>> getIngredients({
    String? outletId,
    String? status,
    String? search,
  }) async {
    final query = <String, dynamic>{};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;
    if (status != null && status.isNotEmpty && status != 'all') query['status'] = status;
    if (search != null && search.isNotEmpty) query['q'] = search;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/inventory/ingredients',
        queryParameters: query,
      );

      final list = (response.data?['data'] ?? response.data?['ingredients']) as List<dynamic>? ?? [];
      return list.map((item) => IngredientModel.fromJson(item as Map<String, dynamic>)).toList();
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Data bahan baku tidak dapat dimuat.');
    }
  }

  Future<IngredientModel> createIngredient({
    required String outletId,
    required String name,
    required String unit,
    int? stockQty,
    int? reorderLevel,
    int? costPerUnit,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/inventory/ingredients',
        data: {
          'outlet_id': outletId,
          'name': name,
          'unit': unit,
          'stock_qty': stockQty ?? 0,
          'reorder_level': reorderLevel ?? 100,
          'cost_per_unit': costPerUnit ?? 0,
        },
      );
      final data = (response.data?['data'] ?? response.data?['ingredient']) as Map<String, dynamic>;
      return IngredientModel.fromJson(data);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Gagal menambahkan bahan baku.');
    }
  }

  Future<void> updateIngredient(
    String id, {
    String? name,
    String? unit,
    int? reorderLevel,
    int? costPerUnit,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (unit != null) payload['unit'] = unit;
      if (reorderLevel != null) payload['reorder_level'] = reorderLevel;
      if (costPerUnit != null) payload['cost_per_unit'] = costPerUnit;
      await _client.put('/inventory/ingredients/$id', data: payload);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Gagal memperbarui bahan baku.');
    }
  }

  Future<void> deleteIngredient(String id) async {
    try {
      await _client.delete('/inventory/ingredients/$id');
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Gagal menghapus bahan baku.');
    }
  }

  Future<void> createAdjustment({
    required String outletId,
    required String ingredientId,
    required String movementType,
    required int quantityDelta,
    String? note,
  }) async {
    try {
      await _client.post('/inventory/adjustments', data: {
        'outlet_id': outletId,
        'ingredient_id': ingredientId,
        'movement_type': movementType,
        'quantity_delta': quantityDelta,
        'note': note,
      });
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Gagal melakukan penyesuaian stok bahan baku.');
    }
  }

  Future<List<InventoryMovementItem>> getMovements({
    String? outletId,
    String? ingredientId,
    String? movementType,
  }) async {
    final query = <String, dynamic>{};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;
    if (ingredientId != null && ingredientId.isNotEmpty) query['ingredient_id'] = ingredientId;
    if (movementType != null && movementType.isNotEmpty) query['movement_type'] = movementType;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/inventory/movements',
        queryParameters: query,
      );

      final list = (response.data?['data'] ?? response.data?['movements']) as List<dynamic>? ?? [];
      return list.map((item) => InventoryMovementItem.fromJson(item as Map<String, dynamic>)).toList();
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Riwayat mutasi tidak dapat dimuat.');
    }
  }

  // Kompatibilitas mundur dengan InventoryStockItem
  Future<List<InventoryStockItem>> getStocks({
    String? outletId,
    bool? lowStock,
    String? categoryId,
    String? search,
  }) async {
    final status = lowStock == true ? 'low' : null;
    final ingredients = await getIngredients(outletId: outletId, status: status, search: search);
    return ingredients.map((i) => InventoryStockItem(
      outletId: i.outletId,
      outletName: i.outletName,
      productId: i.id,
      sku: i.unit,
      productName: i.name,
      unit: i.unit,
      priceIdr: i.costPerUnit,
      costIdr: i.costPerUnit,
      quantity: i.stockQty,
      reorderLevel: i.reorderLevel,
      avgLeadTimeDays: 3,
      isLowStock: i.isLowStock,
      updatedAt: i.updatedAt,
    )).toList();
  }
}
