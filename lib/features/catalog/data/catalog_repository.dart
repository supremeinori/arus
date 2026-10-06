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

  Future<List<CategoryModel>> getCategories() async {
    final res = await _apiClient.get<Map<String, dynamic>>('/categories');
    final data = res.data?['data'] as List<dynamic>? ?? [];
    return data.map((c) => CategoryModel.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<CategoryModel> createCategory(String name) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/categories',
      data: {'name': name},
    );
    final data = res.data?['data'] as Map<String, dynamic>;
    return CategoryModel.fromJson(data);
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

    final res = await _apiClient.get<Map<String, dynamic>>(
      '/products',
      queryParameters: queryParams,
    );

    final data = res.data?['data'] as List<dynamic>? ?? [];
    return data.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<ProductModel> getProductById(String id) async {
    final res = await _apiClient.get<Map<String, dynamic>>('/products/$id');
    final data = res.data?['data'] as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }

  Future<ProductModel> createProduct({
    required String name,
    required String sku,
    required String unit,
    required int priceIdr,
    int? costIdr,
    String? categoryId,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'sku': sku,
      'unit': unit,
      'price_idr': priceIdr,
    };
    if (costIdr != null) payload['cost_idr'] = costIdr;
    if (categoryId != null) payload['category_id'] = categoryId;

    final res = await _apiClient.post<Map<String, dynamic>>(
      '/products',
      data: payload,
    );
    final data = res.data?['data'] as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }

  Future<ProductModel> updateProduct(
    String id, {
    String? name,
    String? sku,
    String? unit,
    int? priceIdr,
    int? costIdr,
    String? categoryId,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (sku != null) payload['sku'] = sku;
    if (unit != null) payload['unit'] = unit;
    if (priceIdr != null) payload['price_idr'] = priceIdr;
    if (costIdr != null) payload['cost_idr'] = costIdr;
    if (categoryId != null) payload['category_id'] = categoryId;
    if (isActive != null) payload['is_active'] = isActive;

    final res = await _apiClient.patch<Map<String, dynamic>>(
      '/products/$id',
      data: payload,
    );
    final data = res.data?['data'] as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }
}
