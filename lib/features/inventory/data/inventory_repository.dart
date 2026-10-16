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

  static final List<IngredientModel> _demoIngredients = [
    IngredientModel(
      id: 'ing-001',
      outletId: 'out-001',
      outletName: 'Kopi Arus - Sudirman (HQ)',
      name: 'Biji Kopi Arabika House Blend',
      unit: 'gram',
      stockQty: 2400,
      reorderLevel: 500,
      costPerUnit: 150,
      status: 'ok',
      updatedAt: DateTime.now(),
    ),
    IngredientModel(
      id: 'ing-002',
      outletId: 'out-001',
      outletName: 'Kopi Arus - Sudirman (HQ)',
      name: 'Susu Fresh Milk UHT',
      unit: 'ml',
      stockQty: 350,
      reorderLevel: 1000,
      costPerUnit: 20,
      status: 'low',
      updatedAt: DateTime.now(),
    ),
    IngredientModel(
      id: 'ing-003',
      outletId: 'out-001',
      outletName: 'Kopi Arus - Sudirman (HQ)',
      name: 'Air Mineral Purified',
      unit: 'ml',
      stockQty: 15000,
      reorderLevel: 2000,
      costPerUnit: 2,
      status: 'ok',
      updatedAt: DateTime.now(),
    ),
    IngredientModel(
      id: 'ing-004',
      outletId: 'out-001',
      outletName: 'Kopi Arus - Sudirman (HQ)',
      name: 'Gula Aren Cair Asli',
      unit: 'ml',
      stockQty: 0,
      reorderLevel: 500,
      costPerUnit: 35,
      status: 'out',
      updatedAt: DateTime.now(),
    ),
    IngredientModel(
      id: 'ing-005',
      outletId: 'out-001',
      outletName: 'Kopi Arus - Sudirman (HQ)',
      name: 'Adonan Croissant Butter',
      unit: 'pcs',
      stockQty: 25,
      reorderLevel: 10,
      costPerUnit: 8000,
      status: 'ok',
      updatedAt: DateTime.now(),
    ),
  ];

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
    } catch (_) {
      var filtered = List<IngredientModel>.from(_demoIngredients);
      if (outletId != null && outletId.isNotEmpty) {
        filtered = filtered.where((i) => i.outletId == outletId).toList();
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        filtered = filtered.where((i) => i.status == status).toList();
      }
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        filtered = filtered.where((i) => i.name.toLowerCase().contains(q)).toList();
      }
      return filtered;
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
      final data = response.data?['data'] as Map<String, dynamic>;
      return IngredientModel.fromJson(data);
    } catch (_) {
      final newIng = IngredientModel(
        id: 'ing-${DateTime.now().millisecondsSinceEpoch}',
        outletId: outletId,
        outletName: 'Cabang Lokal',
        name: name,
        unit: unit,
        stockQty: stockQty ?? 0,
        reorderLevel: reorderLevel ?? 100,
        costPerUnit: costPerUnit ?? 0,
        status: (stockQty ?? 0) <= 0 ? 'out' : ((stockQty ?? 0) <= (reorderLevel ?? 100) ? 'low' : 'ok'),
        updatedAt: DateTime.now(),
      );
      _demoIngredients.insert(0, newIng);
      return newIng;
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
      await _client.put('/inventory/ingredients/$id', data: {
        if (name != null) 'name': name,
        if (unit != null) 'unit': unit,
        if (reorderLevel != null) 'reorder_level': reorderLevel,
        if (costPerUnit != null) 'cost_per_unit': costPerUnit,
      });
    } catch (_) {
      final idx = _demoIngredients.indexWhere((i) => i.id == id);
      if (idx >= 0) {
        final current = _demoIngredients[idx];
        _demoIngredients[idx] = IngredientModel(
          id: current.id,
          outletId: current.outletId,
          outletName: current.outletName,
          name: name ?? current.name,
          unit: unit ?? current.unit,
          stockQty: current.stockQty,
          reorderLevel: reorderLevel ?? current.reorderLevel,
          costPerUnit: costPerUnit ?? current.costPerUnit,
          status: current.status,
          updatedAt: DateTime.now(),
        );
      }
    }
  }

  Future<void> deleteIngredient(String id) async {
    try {
      await _client.delete('/inventory/ingredients/$id');
    } catch (_) {
      _demoIngredients.removeWhere((i) => i.id == id);
    }
  }

  Future<void> createAdjustment({
    required String outletId,
    required String ingredientId,
    required String movementType,
    required int quantityDelta,
    String? note,
  }) async {
    void updateLocal() {
      final idx = _demoIngredients.indexWhere((i) => i.id == ingredientId);
      if (idx >= 0) {
        final current = _demoIngredients[idx];
        final newQty = (current.stockQty + quantityDelta).clamp(0, 9999999);
        final status = newQty <= 0 ? 'out' : (newQty <= current.reorderLevel ? 'low' : 'ok');
        _demoIngredients[idx] = IngredientModel(
          id: current.id,
          outletId: current.outletId,
          outletName: current.outletName,
          name: current.name,
          unit: current.unit,
          stockQty: newQty,
          reorderLevel: current.reorderLevel,
          costPerUnit: current.costPerUnit,
          status: status,
          updatedAt: DateTime.now(),
        );
      }
    }

    try {
      await _client.post('/inventory/adjustments', data: {
        'outlet_id': outletId,
        'ingredient_id': ingredientId,
        'movement_type': movementType,
        'quantity_delta': quantityDelta,
        'note': note,
      });
      updateLocal();
    } catch (_) {
      updateLocal();
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

      final list = response.data?['data'] as List<dynamic>? ?? [];
      return list.map((item) => InventoryMovementItem.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [
        InventoryMovementItem(
          id: 'mov-demo-01',
          outletId: outletId ?? 'out-001',
          outletName: 'Kopi Arus - Sudirman (HQ)',
          ingredientId: ingredientId ?? 'ing-001',
          ingredientName: 'Biji Kopi Arabika House Blend',
          unit: 'gram',
          movementType: 'restock',
          quantityDelta: 2000,
          quantityAfter: 2400,
          note: 'Penerimaan stok bahan baku baru',
          creatorName: 'Rina Kartika (Owner)',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ];
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
