import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/catalog_repository.dart';
import '../domain/category_model.dart';
import '../domain/product_model.dart';

// Kategori
final categoriesProvider = FutureProvider.autoDispose<List<CategoryModel>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.getCategories();
});

// State Filter
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');

// Daftar Produk
final productListProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final categoryId = ref.watch(selectedCategoryProvider);
  final query = ref.watch(searchQueryProvider);

  return repo.getProducts(
    categoryId: categoryId,
    q: query,
  );
});

// Detail Produk
final productDetailProvider =
    FutureProvider.family.autoDispose<ProductModel, String>((ref, productId) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.getProductById(productId);
});
