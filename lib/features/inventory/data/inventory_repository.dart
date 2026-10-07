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

  static final List<InventoryStockItem> _demoStocks = [
    InventoryStockItem(
      outletId: 'out-001',
      outletName: 'Kopi Arus - Sudirman (HQ)',
      productId: 'prod-001',
      sku: 'BEV-COF-01',
      productName: 'Kopi Susu Gula Aren',
      unit: 'cup',
      priceIdr: 22000,
      costIdr: 8500,
      quantity: 45,
      reorderLevel: 10,
      avgLeadTimeDays: 2,
      isLowStock: false,
      updatedAt: DateTime.now(),
    ),
    InventoryStockItem(
      outletId: 'out-001',
      outletName: 'Kopi Arus - Sudirman (HQ)',
      productId: 'prod-002',
      sku: 'BEV-COF-02',
      productName: 'Americano Double Shot',
      unit: 'cup',
      priceIdr: 18000,
      costIdr: 5000,
      quantity: 4,
      reorderLevel: 10,
      avgLeadTimeDays: 2,
      isLowStock: true,
      updatedAt: DateTime.now(),
    ),
    InventoryStockItem(
      outletId: 'out-001',
      outletName: 'Kopi Arus - Sudirman (HQ)',
      productId: 'prod-003',
      sku: 'BEV-NCH-01',
      productName: 'Matcha Latte Oatmilk',
      unit: 'cup',
      priceIdr: 28000,
      costIdr: 11000,
      quantity: 18,
      reorderLevel: 5,
      avgLeadTimeDays: 3,
      isLowStock: false,
      updatedAt: DateTime.now(),
    ),
    InventoryStockItem(
      outletId: 'out-001',
      outletName: 'Kopi Arus - Sudirman (HQ)',
      productId: 'prod-004',
      sku: 'FOD-PST-01',
      productName: 'Croissant Butter Original',
      unit: 'pcs',
      priceIdr: 25000,
      costIdr: 12000,
      quantity: 3,
      reorderLevel: 8,
      avgLeadTimeDays: 1,
      isLowStock: true,
      updatedAt: DateTime.now(),
    ),
  ];

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

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/inventory/stocks',
        queryParameters: query,
      );

      final list = response.data?['data'] as List<dynamic>? ?? [];
      return list.map((item) => InventoryStockItem.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      var filtered = List<InventoryStockItem>.from(_demoStocks);
      if (lowStock == true) {
        filtered = filtered.where((i) => i.isLowStock).toList();
      }
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        filtered = filtered.where((i) => i.productName.toLowerCase().contains(q) || i.sku.toLowerCase().contains(q)).toList();
      }
      return filtered;
    }
  }

  Future<void> createAdjustment({
    required String outletId,
    required String productId,
    required String movementType,
    required int quantityDelta,
    String? note,
  }) async {
    try {
      await _client.post('/inventory/adjustments', data: {
        'outlet_id': outletId,
        'product_id': productId,
        'movement_type': movementType,
        'quantity_delta': quantityDelta,
        'note': note,
      });
    } catch (_) {
      final idx = _demoStocks.indexWhere((i) => i.productId == productId);
      if (idx >= 0) {
        final current = _demoStocks[idx];
        final newQty = current.quantity + quantityDelta;
        _demoStocks[idx] = InventoryStockItem(
          outletId: current.outletId,
          outletName: current.outletName,
          productId: current.productId,
          sku: current.sku,
          productName: current.productName,
          unit: current.unit,
          priceIdr: current.priceIdr,
          costIdr: current.costIdr,
          quantity: newQty < 0 ? 0 : newQty,
          reorderLevel: current.reorderLevel,
          avgLeadTimeDays: current.avgLeadTimeDays,
          isLowStock: newQty <= current.reorderLevel,
          updatedAt: DateTime.now(),
        );
      }
    }
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
          id: 'mov-1',
          outletId: 'out-001',
          outletName: 'Kopi Arus - Sudirman (HQ)',
          productId: 'prod-001',
          productName: 'Kopi Susu Gula Aren',
          sku: 'BEV-COF-01',
          unit: 'cup',
          movementType: 'sale',
          quantityDelta: -2,
          quantityAfter: 45,
          receiptNo: 'TRX-101',
          creatorName: 'Siti Rahma (Kasir)',
          note: 'Penjualan POS',
          createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        ),
        InventoryMovementItem(
          id: 'mov-2',
          outletId: 'out-001',
          outletName: 'Kopi Arus - Sudirman (HQ)',
          productId: 'prod-002',
          productName: 'Americano Double Shot',
          sku: 'BEV-COF-02',
          unit: 'cup',
          movementType: 'restock',
          quantityDelta: 10,
          quantityAfter: 14,
          receiptNo: 'PO-202',
          creatorName: 'Budi Santoso (Manager)',
          note: 'Penerimaan stok harian',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ];
    }
  }
}
