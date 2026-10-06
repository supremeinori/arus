import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_models.dart';

class InventoryFilterState {
  final String? outletId;
  final bool lowStockOnly;
  final String searchQuery;

  const InventoryFilterState({
    this.outletId,
    this.lowStockOnly = false,
    this.searchQuery = '',
  });

  InventoryFilterState copyWith({
    String? outletId,
    bool? lowStockOnly,
    String? searchQuery,
  }) {
    return InventoryFilterState(
      outletId: outletId ?? this.outletId,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final inventoryFilterProvider = StateProvider<InventoryFilterState>((ref) {
  return const InventoryFilterState();
});

final inventoryListProvider = FutureProvider.autoDispose<List<InventoryStockItem>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final filter = ref.watch(inventoryFilterProvider);

  return repo.getStocks(
    outletId: filter.outletId,
    lowStock: filter.lowStockOnly ? true : null,
    search: filter.searchQuery.isEmpty ? null : filter.searchQuery,
  );
});

final inventoryMovementsProvider = FutureProvider.autoDispose.family<List<InventoryMovementItem>, String?>((ref, outletId) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.getMovements(outletId: outletId);
});
