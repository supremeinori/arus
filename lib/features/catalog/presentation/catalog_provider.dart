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
/// Tampilkan juga menu yang dinonaktifkan (is_active = false) supaya owner
/// bisa mengaktifkannya kembali kapan menu itu mau dipakai lagi.
final showInactiveProvider = StateProvider<bool>((ref) => false);

final productListProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final categoryId = ref.watch(selectedCategoryProvider);
  final query = ref.watch(searchQueryProvider);
  final showInactive = ref.watch(showInactiveProvider);

  return repo.getProducts(
    categoryId: categoryId,
    q: query,
    includeInactive: showInactive,
  );
});

// Detail Produk
final productDetailProvider =
    FutureProvider.family.autoDispose<ProductModel, String>((ref, productId) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.getProductById(productId);
});
