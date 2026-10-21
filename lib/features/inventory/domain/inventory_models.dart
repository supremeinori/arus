import 'package:intl/intl.dart';

class IngredientModel {
  final String id;
  final String outletId;
  final String outletName;
  final String name;
  final String unit;
  final int stockQty;
  final int reorderLevel;
  final int costPerUnit;
  final String status; // 'ok' | 'low' | 'out'
  final DateTime updatedAt;

  const IngredientModel({
    required this.id,
    required this.outletId,
    required this.outletName,
    required this.name,
    required this.unit,
    required this.stockQty,
    required this.reorderLevel,
    required this.costPerUnit,
    required this.status,
    required this.updatedAt,
  });

  factory IngredientModel.fromJson(Map<String, dynamic> json) {
    final outletObj = json['outlet'] as Map<String, dynamic>?;
    final stock = json['stock_qty'] as int? ?? json['quantity'] as int? ?? 0;
    final reorder = json['reorder_level'] as int? ?? 100;
    String status = json['status'] as String? ?? '';
    if (status.isEmpty) {
      if (stock <= 0) {
        status = 'out';
      } else if (stock <= reorder) {
        status = 'low';
      } else {
        status = 'ok';
      }
    }

    return IngredientModel(
      id: json['id'] as String? ?? json['product_id'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      outletName: json['outlet_name'] as String? ?? outletObj?['name'] as String? ?? 'Outlet',
      name: json['name'] as String? ?? json['product_name'] as String? ?? '',
      unit: json['unit'] as String? ?? 'gram',
      stockQty: stock,
      reorderLevel: reorder,
      costPerUnit: json['cost_per_unit'] as int? ?? json['cost_idr'] as int? ?? 0,
      status: status,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  bool get isLowStock => status == 'low' || (stockQty <= reorderLevel && stockQty > 0);

  String get formattedStock {
    final formatter = NumberFormat.decimalPattern('id_ID');
    return '${formatter.format(stockQty)} $unit';
  }
  bool get isOutOfStock => status == 'out' || stockQty <= 0;


}

class InventoryStockItem {
  final String outletId;
  final String outletName;
  final String productId;
  final String sku;
  final String productName;
  final String unit;
  final int priceIdr;
  final int? costIdr;
  final int quantity;
  final int reorderLevel;
  final int avgLeadTimeDays;
  final bool isLowStock;
  final DateTime updatedAt;

  const InventoryStockItem({
    required this.outletId,
    required this.outletName,
    required this.productId,
    required this.sku,
    required this.productName,
    required this.unit,
    required this.priceIdr,
    this.costIdr,
    required this.quantity,
    required this.reorderLevel,
    required this.avgLeadTimeDays,
    required this.isLowStock,
    required this.updatedAt,
  });

  factory InventoryStockItem.fromJson(Map<String, dynamic> json) {
    final outletObj = json['outlet'] as Map<String, dynamic>?;
    final qty = json['stock_qty'] as int? ?? json['quantity'] as int? ?? 0;
    final reorder = json['reorder_level'] as int? ?? 100;
    final isLow = json['status'] == 'low' || (qty <= reorder && qty > 0) || (json['is_low_stock'] == true);

    return InventoryStockItem(
      outletId: json['outlet_id'] as String? ?? '',
      outletName: json['outlet_name'] as String? ?? outletObj?['name'] as String? ?? 'Outlet',
      productId: json['id'] as String? ?? json['product_id'] as String? ?? '',
      sku: json['sku'] as String? ?? (json['unit'] != null ? '${json['unit']}' : 'ING'),
      productName: json['name'] as String? ?? json['product_name'] as String? ?? '',
      unit: json['unit'] as String? ?? 'gram',
      priceIdr: json['price_idr'] as int? ?? 0,
      costIdr: json['cost_per_unit'] as int? ?? json['cost_idr'] as int?,
      quantity: qty,
      reorderLevel: reorder,
      avgLeadTimeDays: json['avg_lead_time_days'] as int? ?? 3,
      isLowStock: isLow,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }


}

class InventoryMovementItem {
  final String id;
  final String outletId;
  final String outletName;
  final String ingredientId;
  final String ingredientName;
  final String unit;
  final String movementType; // 'sale' | 'void_return' | 'restock' | 'correction' | 'waste'
  final int quantityDelta;
  final int quantityAfter;
  final String? note;
  final String creatorName;
  final String? receiptNo;
  final DateTime createdAt;

  const InventoryMovementItem({
    required this.id,
    required this.outletId,
    required this.outletName,
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.movementType,
    required this.quantityDelta,
    required this.quantityAfter,
    this.note,
    required this.creatorName,
    this.receiptNo,
    required this.createdAt,
  });

  String get productName => ingredientName;
  String get productId => ingredientId;

  factory InventoryMovementItem.fromJson(Map<String, dynamic> json) {
    final ing = (json['ingredient'] as Map<String, dynamic>?) ?? (json['product'] as Map<String, dynamic>?);
    final out = json['outlet'] as Map<String, dynamic>?;
    final user = json['creator'] as Map<String, dynamic>?;
    final trx = json['transaction'] as Map<String, dynamic>?;

    return InventoryMovementItem(
      id: json['id'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      outletName: out?['name'] as String? ?? 'Outlet',
      ingredientId: json['ingredient_id'] as String? ?? json['product_id'] as String? ?? '',
      ingredientName: ing?['name'] as String? ?? 'Bahan Baku',
      unit: ing?['unit'] as String? ?? 'unit',
      movementType: json['movement_type'] as String? ?? 'correction',
      quantityDelta: json['quantity_delta'] as int? ?? 0,
      quantityAfter: json['quantity_after'] as int? ?? 0,
      note: json['note'] as String?,
      creatorName: user?['name'] as String? ?? 'User',
      receiptNo: trx?['receipt_no'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get typeLabel {
    switch (movementType) {
      case 'sale':
        return 'Penjualan POS';
      case 'void_return':
        return 'Void/Refund';
      case 'restock':
        return 'Restock Masuk';
      case 'correction':
        return 'Koreksi Opname';
      case 'waste':
        return 'Barang Rusak/Hilang';
      default:
        return movementType;
    }
  }
}
