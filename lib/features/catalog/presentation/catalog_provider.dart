import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
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
  final authUser = ref.watch(authProvider).user;
  final outletId = (authUser != null &&
          (authUser.role == UserRole.staff || authUser.role == UserRole.manager) &&
          authUser.outlets.isNotEmpty)
      ? authUser.outlets.first.id
      : ref.watch(selectedOutletFilterProvider);

  return repo.getProducts(
    outletId: outletId,
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
