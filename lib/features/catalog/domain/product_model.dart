import 'package:intl/intl.dart';

class ProductRecipeModel {
  final String? id;
  final String ingredientId;
  final String? ingredientName;
  final String? ingredientUnit;
  final int amountNeeded;
  final int? costPerUnit;

  const ProductRecipeModel({
    this.id,
    required this.ingredientId,
    this.ingredientName,
    this.ingredientUnit,
    required this.amountNeeded,
    this.costPerUnit,
  });

  factory ProductRecipeModel.fromJson(Map<String, dynamic> json) {
    final ingObj = json['ingredient'] as Map<String, dynamic>?;
    return ProductRecipeModel(
      id: json['id'] as String?,
      ingredientId: json['ingredient_id'] as String? ?? (ingObj?['id'] as String? ?? ''),
      ingredientName: json['ingredient_name'] as String? ?? ingObj?['name'] as String?,
      ingredientUnit: json['ingredient_unit'] as String? ?? ingObj?['unit'] as String?,
      amountNeeded: json['amount_needed'] as int? ?? 0,
      costPerUnit: json['cost_per_unit'] as int? ?? ingObj?['cost_per_unit'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'ingredient_id': ingredientId,
      'amount_needed': amountNeeded,
      if (ingredientName != null) 'ingredient_name': ingredientName,
      if (ingredientUnit != null) 'ingredient_unit': ingredientUnit,
      if (costPerUnit != null) 'cost_per_unit': costPerUnit,
    };
  }
}

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
      quantity: json['quantity'] as int? ?? json['stock_qty'] as int? ?? 0,
      reorderLevel: json['reorder_level'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outlet_id': outletId,
      'quantity': quantity,
      'reorder_level': reorderLevel,
      'outlet': {'name': outletName},
    };
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
  final int estimatedPortions;
  final List<ProductRecipeModel> recipes;
  final List<ProductOutletStock> outletStock;

  const ProductModel({
    required this.id,
    required this.sku,
    required this.name,
    this.unit = 'porsi',
    required this.priceIdr,
    this.costIdr,
    this.categoryId,
    this.categoryName,
    this.imageUrl,
    this.isActive = true,
    this.estimatedPortions = 0,
    this.recipes = const [],
    this.outletStock = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final catObj = json['category'] as Map<String, dynamic>?;
    final invList = json['inventory'] as List<dynamic>? ?? [];
    final recipeList = json['recipes'] as List<dynamic>? ?? [];

    final estPortions = json['estimated_portions'] as int? ??
        (invList.isNotEmpty ? (invList.first['quantity'] as int? ?? 0) : 0);

    return ProductModel(
      id: json['id'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? 'porsi',
      priceIdr: json['price_idr'] as int? ?? 0,
      costIdr: json['cost_idr'] as int?,
      categoryId: json['category_id'] as String?,
      categoryName: catObj?['name'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      estimatedPortions: estPortions,
      recipes: recipeList
          .map((r) => ProductRecipeModel.fromJson(r as Map<String, dynamic>))
          .toList(),
      outletStock: invList.isNotEmpty
          ? invList.map((i) => ProductOutletStock.fromJson(i as Map<String, dynamic>)).toList()
          : [
              ProductOutletStock(
                outletId: 'default',
                outletName: 'Cabang',
                quantity: estPortions,
              )
            ],
    );
  }

  ProductModel copyWith({
    String? id,
    String? sku,
    String? name,
    String? unit,
    int? priceIdr,
    int? costIdr,
    String? categoryId,
    String? categoryName,
    String? imageUrl,
    bool? isActive,
    int? estimatedPortions,
    List<ProductRecipeModel>? recipes,
    List<ProductOutletStock>? outletStock,
  }) {
    return ProductModel(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      priceIdr: priceIdr ?? this.priceIdr,
      costIdr: costIdr ?? this.costIdr,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      estimatedPortions: estimatedPortions ?? this.estimatedPortions,
      recipes: recipes ?? this.recipes,
      outletStock: outletStock ?? this.outletStock,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'unit': unit,
      'price_idr': priceIdr,
      'cost_idr': costIdr,
      'category_id': categoryId,
      'category': categoryName != null ? {'name': categoryName} : null,
      'image_url': imageUrl,
      'is_active': isActive,
      'estimated_portions': estimatedPortions,
      'recipes': recipes.map((r) => r.toJson()).toList(),
      'inventory': outletStock.map((s) => s.toJson()).toList(),
    };
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

  bool get isOutOfStock => estimatedPortions <= 0;
}
