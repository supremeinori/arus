class CategoryModel {
  final String id;
  final String name;
  final int productCount;

  const CategoryModel({
    required this.id,
    required this.name,
    this.productCount = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      productCount: (json['_count'] as Map<String, dynamic>?)?['products'] as int? ?? (json['product_count'] as int? ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'product_count': productCount,
      '_count': {'products': productCount},
    };
  }
}
