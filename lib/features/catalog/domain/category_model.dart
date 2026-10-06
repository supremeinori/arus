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
      productCount: (json['_count'] as Map<String, dynamic>?)?['products'] as int? ?? 0,
    );
  }
}
