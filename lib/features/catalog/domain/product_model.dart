import 'package:intl/intl.dart';

class ProductOutletStock {
  final String outletId;
  final String outletName;
  final int quantity;
  final int reorderLevel;

  const ProductOutletStock({
    required this.outletId,
    required this.outletName,
    required this.quantity,
    this.reorderLevel = 5,
  });

  factory ProductOutletStock.fromJson(Map<String, dynamic> json) {
    return ProductOutletStock(
      outletId: json['outlet_id'] as String? ?? '',
      outletName: (json['outlet'] as Map<String, dynamic>?)?['name'] as String? ?? 'Outlet',
      quantity: json['quantity'] as int? ?? 0,
      reorderLevel: json['reorder_level'] as int? ?? 5,
    );
  }
}

class ProductModel {
  final String id;
  final String sku;
  final String name;
  final String unit;
  final int priceIdr;
  final int? costIdr; // Null jika role adalah Staff (HPP hidden)
  final String? categoryId;
  final String? categoryName;
  final String? imageUrl;
  final bool isActive;
  final List<ProductOutletStock> outletStock;

  const ProductModel({
    required this.id,
    required this.sku,
    required this.name,
    required this.unit,
    required this.priceIdr,
    this.costIdr,
    this.categoryId,
    this.categoryName,
    this.imageUrl,
    this.isActive = true,
    this.outletStock = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final catObj = json['category'] as Map<String, dynamic>?;
    final invList = json['inventory'] as List<dynamic>? ?? [];

    return ProductModel(
      id: json['id'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? 'pcs',
      priceIdr: json['price_idr'] as int? ?? 0,
      costIdr: json['cost_idr'] as int?,
      categoryId: json['category_id'] as String?,
      categoryName: catObj?['name'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      outletStock: invList
          .map((i) => ProductOutletStock.fromJson(i as Map<String, dynamic>))
          .toList(),
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
