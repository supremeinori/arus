import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_models.dart';

class InventoryFilterState {
  final String status; // 'all' | 'ok' | 'low' | 'out'
  final String searchQuery;

  const InventoryFilterState({
    this.status = 'all',
    this.searchQuery = '',
  });

  bool get lowStockOnly => status == 'low';

  InventoryFilterState copyWith({
    String? status,
    String? searchQuery,
    bool? lowStockOnly,
  }) {
    return InventoryFilterState(
      status: status ?? (lowStockOnly == true ? 'low' : (lowStockOnly == false ? 'all' : this.status)),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final inventoryFilterProvider = StateProvider<InventoryFilterState>((ref) {
  return const InventoryFilterState();
});

final ingredientsListProvider = FutureProvider.autoDispose<List<IngredientModel>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final authUser = ref.watch(authProvider).user;
  // Khusus Manager: Terkunci ke cabang yang ditugaskan oleh Owner, tidak boleh memilih cabang lain
  final outletId = (authUser != null && authUser.role == UserRole.manager && authUser.outlets.isNotEmpty)
      ? authUser.outlets.first.id
      : ref.watch(selectedOutletFilterProvider);
  final filter = ref.watch(inventoryFilterProvider);

  return repo.getIngredients(
    outletId: outletId,
    status: filter.status == 'all' ? null : filter.status,
    search: filter.searchQuery.isEmpty ? null : filter.searchQuery,
  );
});

// Backward-compatible provider for existing widgets
final inventoryListProvider = FutureProvider.autoDispose<List<InventoryStockItem>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final authUser = ref.watch(authProvider).user;
  final outletId = (authUser != null && authUser.role == UserRole.manager && authUser.outlets.isNotEmpty)
      ? authUser.outlets.first.id
      : ref.watch(selectedOutletFilterProvider);
  final filter = ref.watch(inventoryFilterProvider);

  return repo.getStocks(
    outletId: outletId,
    lowStock: filter.status == 'low' ? true : null,
    search: filter.searchQuery.isEmpty ? null : filter.searchQuery,
  );
});

final inventoryMovementsProvider = FutureProvider.autoDispose.family<List<InventoryMovementItem>, String?>((ref, outletId) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final authUser = ref.watch(authProvider).user;
  final effectiveOutletId = (authUser != null && authUser.role == UserRole.manager && authUser.outlets.isNotEmpty)
      ? authUser.outlets.first.id
      : outletId;
  return repo.getMovements(outletId: effectiveOutletId);
});
