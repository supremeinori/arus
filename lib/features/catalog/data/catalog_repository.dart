import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/local_db.dart';
import '../domain/category_model.dart';
import '../domain/product_model.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final localDb = ref.watch(localDbProvider);
  return CatalogRepository(apiClient, localDb);
});

class CatalogRepository {
  final ApiClient _apiClient;
  final LocalDatabase _localDb;

  CatalogRepository(this._apiClient, this._localDb);

  /// Mengambil daftar kategori produk (Database / Cache-first jika offline)
  Future<List<CategoryModel>> getCategories() async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>('/categories');
      final data = res.data?['data'] as List<dynamic>? ?? [];
      final categories = data.map((c) => CategoryModel.fromJson(c as Map<String, dynamic>)).toList();

      // Simpan ke database SQLite lokal
      await _localDb.cacheCategories(categories);
      return categories;
    } on AppException {
      final cached = await _localDb.getCachedCategories();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    } catch (_) {
      final cached = await _localDb.getCachedCategories();
      if (cached.isNotEmpty) {
        return cached;
      }
      throw AppException('Koneksi ke web service terputus. Kategori produk tidak dapat dimuat.');
    }
  }

  Future<CategoryModel> createCategory(String name) async {
    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/categories',
        data: {'name': name.trim()},
      );
      final data = res.data?['data'] as Map<String, dynamic>;
      final cat = CategoryModel.fromJson(data);

      final current = await _localDb.getCachedCategories();
      await _localDb.cacheCategories([...current, cat]);
      return cat;
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus. Gagal menambahkan kategori.');
    }
  }

  /// Mengambil daftar produk (Database / Cache SQLite jika offline)
  Future<List<ProductModel>> getProducts({
    String? outletId,
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

    if (outletId != null && outletId.isNotEmpty) {
      queryParams['outlet_id'] = outletId;
    }
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
      final products = data.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();

      // Simpan seluruh produk ke SQLite lokal
      await _localDb.cacheProducts(products);
      return products;
    } on AppException {
      final cached = await _localDb.getCachedProducts(categoryId: categoryId, search: q);
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    } catch (_) {
      final cached = await _localDb.getCachedProducts(categoryId: categoryId, search: q);
      if (cached.isNotEmpty) {
        return cached;
      }
      throw AppException('Koneksi ke web service terputus. Produk tidak dapat dimuat.');
    }
  }

  Future<ProductModel> getProductById(String id) async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>('/products/$id');
      final data = res.data?['data'] as Map<String, dynamic>;
      final prod = ProductModel.fromJson(data);
      await _localDb.cacheSingleProduct(prod);
      return prod;
    } on AppException {
      final cached = await _localDb.getCachedProducts();
      final found = cached.where((p) => p.id == id).toList();
      if (found.isNotEmpty) return found.first;
      rethrow;
    } catch (_) {
      final cached = await _localDb.getCachedProducts();
      final found = cached.where((p) => p.id == id).toList();
      if (found.isNotEmpty) return found.first;
      throw AppException('Koneksi ke web service terputus. Produk tidak ditemukan.');
    }
  }

  Future<ProductModel> createProduct({
    required String name,
    required String sku,
    String? unit,
    required int priceIdr,
    int? costIdr,
    String? categoryId,
    String? imageUrl,
    List<Map<String, dynamic>>? recipes,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'sku': sku.trim().toUpperCase(),
      'price_idr': priceIdr,
    };
    if (unit != null) payload['unit'] = unit.trim();
    if (costIdr != null) payload['cost_idr'] = costIdr;
    if (categoryId != null) payload['category_id'] = categoryId;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) payload['image_url'] = imageUrl.trim();
    if (recipes != null && recipes.isNotEmpty) payload['recipes'] = recipes;

    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/products',
        data: payload,
      );
      final data = res.data?['data'] as Map<String, dynamic>;
      final prod = ProductModel.fromJson(data);

      await _localDb.cacheSingleProduct(prod);
      return prod;
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus. Gagal membuat produk.');
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
    List<Map<String, dynamic>>? recipes,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (sku != null) payload['sku'] = sku.trim().toUpperCase();
    if (unit != null) payload['unit'] = unit.trim();
    if (priceIdr != null) payload['price_idr'] = priceIdr;
    if (costIdr != null) payload['cost_idr'] = costIdr;
    if (categoryId != null) payload['category_id'] = categoryId;
    if (imageUrl != null) payload['image_url'] = imageUrl.trim();
    if (isActive != null) payload['is_active'] = isActive;
    if (recipes != null) payload['recipes'] = recipes;

    try {
      final res = await _apiClient.patch<Map<String, dynamic>>(
        '/products/$id',
        data: payload,
      );
      final data = res.data?['data'] as Map<String, dynamic>;
      final prod = ProductModel.fromJson(data);
      await _localDb.cacheSingleProduct(prod);
      return prod;
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus. Gagal memperbarui produk.');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _apiClient.delete('/products/$id');
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus. Gagal menghapus produk.');
    }
  }
}
