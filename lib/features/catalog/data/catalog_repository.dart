import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/utils/uuid_generator.dart';
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
      outletStock: [ProductOutletStock(outletId: 'out-001', outletName: 'ARUS Coffee Sudirman HQ', quantity: 30)],
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
      outletStock: [ProductOutletStock(outletId: 'out-001', outletName: 'ARUS Coffee Sudirman HQ', quantity: 30)],
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
      outletStock: [ProductOutletStock(outletId: 'out-001', outletName: 'ARUS Coffee Sudirman HQ', quantity: 30)],
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
      outletStock: [ProductOutletStock(outletId: 'out-001', outletName: 'ARUS Coffee Sudirman HQ', quantity: 30)],
    ),
  ];

  /// Mengambil daftar kategori produk (Offline-first / Cache-first)
  Future<List<CategoryModel>> getCategories() async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>('/categories');
      final data = res.data?['data'] as List<dynamic>? ?? [];
      final categories = data.map((c) => CategoryModel.fromJson(c as Map<String, dynamic>)).toList();

      // Simpan ke database SQLite lokal
      await _localDb.cacheCategories(categories);
      return categories;
    } catch (_) {
      // Kondisi Offline: Baca dari SQLite lokal
      final cached = await _localDb.getCachedCategories();
      if (cached.isNotEmpty) {
        return cached;
      }
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
      final cat = CategoryModel.fromJson(data);

      final current = await _localDb.getCachedCategories();
      await _localDb.cacheCategories([...current, cat]);
      return cat;
    } catch (_) {
      final newCat = CategoryModel(
        id: UuidGenerator.v4(),
        name: name,
        productCount: 0,
      );
      final current = await _localDb.getCachedCategories();
      await _localDb.cacheCategories([...current, newCat]);
      return newCat;
    }
  }

  /// Mengambil daftar produk (Offline-first / Cache-first)
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
      final products = data.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();

      // Simpan seluruh produk ke SQLite lokal
      await _localDb.cacheProducts(products);
      return products;
    } catch (_) {
      // Kondisi Offline: Ambil dari cache SQLite lokal HP
      final cached = await _localDb.getCachedProducts(categoryId: categoryId, search: q);
      if (cached.isNotEmpty) {
        return cached;
      }

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
      final prod = ProductModel.fromJson(data);
      await _localDb.cacheSingleProduct(prod);
      return prod;
    } catch (_) {
      final cached = await _localDb.getCachedProducts();
      final found = cached.where((p) => p.id == id).toList();
      if (found.isNotEmpty) return found.first;

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
      final prod = ProductModel.fromJson(data);

      // Simpan cadangan ke SQLite lokal
      await _localDb.cacheSingleProduct(prod);
      return prod;
    } catch (_) {
      // Offline fallback: simpan langsung ke SQLite lokal
      final categories = await _localDb.getCachedCategories();
      final cat = categories.where((c) => c.id == categoryId).toList();
      final categoryName = cat.isNotEmpty ? cat.first.name : 'Umum';

      final newProd = ProductModel(
        id: UuidGenerator.v4(),
        name: name,
        sku: sku,
        unit: unit,
        priceIdr: priceIdr,
        costIdr: costIdr,
        categoryId: categoryId,
        categoryName: categoryName,
        imageUrl: imageUrl,
        isActive: true,
        outletStock: const [
          ProductOutletStock(
            outletId: 'local',
            outletName: 'Lokal',
            quantity: 50,
          )
        ],
      );
      await _localDb.cacheSingleProduct(newProd);
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
      final prod = ProductModel.fromJson(data);
      await _localDb.cacheSingleProduct(prod);
      return prod;
    } catch (_) {
      final cached = await _localDb.getCachedProducts();
      final idx = cached.indexWhere((p) => p.id == id);
      if (idx >= 0) {
        final cur = cached[idx];
        final updated = cur.copyWith(
          name: name,
          sku: sku,
          unit: unit,
          priceIdr: priceIdr,
          costIdr: costIdr,
          categoryId: categoryId,
          imageUrl: imageUrl,
          isActive: isActive,
        );
        await _localDb.cacheSingleProduct(updated);
        return updated;
      }
      return _demoProducts.first;
    }
  }
}
