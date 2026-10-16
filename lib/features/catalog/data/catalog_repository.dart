import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/category_model.dart';
import '../domain/product_model.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CatalogRepository(apiClient);
});

class CatalogRepository {
  final ApiClient _apiClient;

  CatalogRepository(this._apiClient);

  static final List<CategoryModel> _demoCategories = [
    const CategoryModel(id: 'cat-001', name: 'Coffee', productCount: 2),
    const CategoryModel(id: 'cat-002', name: 'Non-Coffee', productCount: 1),
    const CategoryModel(id: 'cat-003', name: 'Pastry & Food', productCount: 1),
  ];

  static final List<ProductModel> _demoProducts = [
    const ProductModel(
      id: 'prod-001',
      name: 'Kopi Susu Gula Aren',
      sku: 'BEV-COF-01',
      unit: 'cup',
      priceIdr: 22000,
      costIdr: 8500,
      categoryId: 'cat-001',
      categoryName: 'Coffee',
      isActive: true,
    ),
    const ProductModel(
      id: 'prod-002',
      name: 'Americano Double Shot',
      sku: 'BEV-COF-02',
      unit: 'cup',
      priceIdr: 18000,
      costIdr: 5000,
      categoryId: 'cat-001',
      categoryName: 'Coffee',
      isActive: true,
    ),
    const ProductModel(
      id: 'prod-003',
      name: 'Matcha Latte Oatmilk',
      sku: 'BEV-NCH-01',
      unit: 'cup',
      priceIdr: 28000,
      costIdr: 11000,
      categoryId: 'cat-002',
      categoryName: 'Non-Coffee',
      isActive: true,
    ),
    const ProductModel(
      id: 'prod-004',
      name: 'Croissant Butter Original',
      sku: 'FOD-PST-01',
      unit: 'pcs',
      priceIdr: 25000,
      costIdr: 12000,
      categoryId: 'cat-003',
      categoryName: 'Pastry & Food',
      isActive: true,
    ),
  ];

  Future<List<CategoryModel>> getCategories() async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>('/categories');
      final data = res.data?['data'] as List<dynamic>? ?? [];
      return data.map((c) => CategoryModel.fromJson(c as Map<String, dynamic>)).toList();
    } catch (_) {
      return _demoCategories;
    }
  }

  Future<CategoryModel> createCategory(String name) async {
    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/categories',
        data: {'name': name},
      );
      final data = res.data?['data'] as Map<String, dynamic>;
      return CategoryModel.fromJson(data);
    } catch (_) {
      final newCat = CategoryModel(
        id: 'cat-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        productCount: 0,
      );
      _demoCategories.add(newCat);
      return newCat;
    }
  }

  Future<List<ProductModel>> getProducts({
    String? categoryId,
    String? q,
    String? sort,
    bool? isActive,
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };

    if (categoryId != null && categoryId.isNotEmpty) {
      queryParams['category_id'] = categoryId;
    }
    if (q != null && q.trim().isNotEmpty) {
      queryParams['q'] = q.trim();
    }
    if (sort != null) {
      queryParams['sort'] = sort;
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive.toString();
    }

    try {
      final res = await _apiClient.get<Map<String, dynamic>>(
        '/products',
        queryParameters: queryParams,
      );

      final data = res.data?['data'] as List<dynamic>? ?? [];
      return data.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();
    } catch (_) {
      var filtered = List<ProductModel>.from(_demoProducts);
      if (categoryId != null && categoryId.isNotEmpty) {
        filtered = filtered.where((p) => p.categoryId == categoryId).toList();
      }
      if (q != null && q.trim().isNotEmpty) {
        final query = q.trim().toLowerCase();
        filtered = filtered.where((p) => p.name.toLowerCase().contains(query) || p.sku.toLowerCase().contains(query)).toList();
      }
      if (isActive != null) {
        filtered = filtered.where((p) => p.isActive == isActive).toList();
      }
      return filtered;
    }
  }

  Future<ProductModel> getProductById(String id) async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>('/products/$id');
      final data = res.data?['data'] as Map<String, dynamic>;
      return ProductModel.fromJson(data);
    } catch (_) {
      return _demoProducts.firstWhere(
        (p) => p.id == id,
        orElse: () => _demoProducts.first,
      );
    }
  }

  Future<ProductModel> createProduct({
    required String name,
    required String sku,
    required String unit,
    required int priceIdr,
    int? costIdr,
    String? categoryId,
    String? imageUrl,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'sku': sku,
      'unit': unit,
      'price_idr': priceIdr,
    };
    if (costIdr != null) payload['cost_idr'] = costIdr;
    if (categoryId != null) payload['category_id'] = categoryId;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) payload['image_url'] = imageUrl.trim();

    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/products',
        data: payload,
      );
      final data = res.data?['data'] as Map<String, dynamic>;
      return ProductModel.fromJson(data);
    } catch (_) {
      final cat = _demoCategories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => const CategoryModel(id: 'cat-001', name: 'Umum'),
      );
      final newProd = ProductModel(
        id: 'prod-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        sku: sku,
        unit: unit,
        priceIdr: priceIdr,
        costIdr: costIdr,
        categoryId: categoryId,
        categoryName: cat.name,
        imageUrl: imageUrl,
        isActive: true,
      );
      _demoProducts.insert(0, newProd);
      return newProd;
    }
  }

  Future<ProductModel> updateProduct(
    String id, {
    String? name,
    String? sku,
    String? unit,
    int? priceIdr,
    int? costIdr,
    String? categoryId,
    String? imageUrl,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (sku != null) payload['sku'] = sku;
    if (unit != null) payload['unit'] = unit;
    if (priceIdr != null) payload['price_idr'] = priceIdr;
    if (costIdr != null) payload['cost_idr'] = costIdr;
    if (categoryId != null) payload['category_id'] = categoryId;
    if (imageUrl != null) payload['image_url'] = imageUrl.trim();
    if (isActive != null) payload['is_active'] = isActive;

    try {
      final res = await _apiClient.patch<Map<String, dynamic>>(
        '/products/$id',
        data: payload,
      );
      final data = res.data?['data'] as Map<String, dynamic>;
      return ProductModel.fromJson(data);
    } catch (_) {
      final idx = _demoProducts.indexWhere((p) => p.id == id);
      if (idx >= 0) {
        final cur = _demoProducts[idx];
        final updated = ProductModel(
          id: cur.id,
          name: name ?? cur.name,
          sku: sku ?? cur.sku,
          unit: unit ?? cur.unit,
          priceIdr: priceIdr ?? cur.priceIdr,
          costIdr: costIdr ?? cur.costIdr,
          categoryId: categoryId ?? cur.categoryId,
          categoryName: cur.categoryName,
          isActive: isActive ?? cur.isActive,
        );
        _demoProducts[idx] = updated;
        return updated;
      }
      return _demoProducts.first;
    }
  }
}
