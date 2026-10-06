import 'package:intl/intl.dart';

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
    return InventoryStockItem(
      outletId: json['outlet_id'] as String? ?? '',
      outletName: json['outlet_name'] as String? ?? 'Outlet',
      productId: json['product_id'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      unit: json['unit'] as String? ?? 'pcs',
      priceIdr: json['price_idr'] as int? ?? 0,
      costIdr: json['cost_idr'] as int?,
      quantity: json['quantity'] as int? ?? 0,
      reorderLevel: json['reorder_level'] as int? ?? 5,
      avgLeadTimeDays: json['avg_lead_time_days'] as int? ?? 3,
      isLowStock: json['is_low_stock'] as bool? ?? false,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get formattedPrice {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(priceIdr);
  }

  String? get formattedCost {
    if (costIdr == null) return null;
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(costIdr);
  }
}

class InventoryMovementItem {
  final String id;
  final String outletId;
  final String outletName;
  final String productId;
  final String productName;
  final String sku;
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
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.movementType,
    required this.quantityDelta,
    required this.quantityAfter,
    this.note,
    required this.creatorName,
    this.receiptNo,
    required this.createdAt,
  });

  factory InventoryMovementItem.fromJson(Map<String, dynamic> json) {
    final prod = json['product'] as Map<String, dynamic>?;
    final out = json['outlet'] as Map<String, dynamic>?;
    final user = json['creator'] as Map<String, dynamic>?;
    final trx = json['transaction'] as Map<String, dynamic>?;

    return InventoryMovementItem(
      id: json['id'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      outletName: out?['name'] as String? ?? 'Outlet',
      productId: json['product_id'] as String? ?? '',
      productName: prod?['name'] as String? ?? '',
      sku: prod?['sku'] as String? ?? '',
      unit: prod?['unit'] as String? ?? 'pcs',
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
