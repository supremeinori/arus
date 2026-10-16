import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../catalog/domain/product_model.dart';
import '../data/pos_repository.dart';
import '../domain/pos_models.dart';

class PosCartState {
  final List<PosCartItem> items;
  final int discountIdr;
  final String paymentMethod; // 'cash' | 'qris_simulated' | 'card_simulated'

  const PosCartState({
    this.items = const [],
    this.discountIdr = 0,
    this.paymentMethod = 'cash',
  });

  int get subtotalIdr => items.fold(0, (sum, item) => sum + item.lineTotalIdr);
  int get totalIdr => (subtotalIdr - discountIdr).clamp(0, double.infinity).toInt();
  int get totalItemsCount => items.fold(0, (sum, item) => sum + item.quantity);

  PosCartState copyWith({
    List<PosCartItem>? items,
    int? discountIdr,
    String? paymentMethod,
  }) {
    return PosCartState(
      items: items ?? this.items,
      discountIdr: discountIdr ?? this.discountIdr,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

class PosCartNotifier extends StateNotifier<PosCartState> {
  PosCartNotifier() : super(const PosCartState());

  /// Tambah produk ke keranjang; qty dibatasi [maxPortions] bila diberikan.
  /// Mengembalikan false bila batas tercapai (UI tampilkan snackbar).
  bool addProduct(ProductModel product, {int? maxPortions}) {
    final cap = maxPortions ?? product.estimatedPortions;
    final existingIndex = state.items.indexWhere((item) => item.productId == product.id);

    if (existingIndex >= 0) {
      final current = state.items[existingIndex];
      if (cap > 0 && current.quantity + 1 > cap) return false;
      final updatedList = List<PosCartItem>.from(state.items);
      updatedList[existingIndex] = current.copyWith(quantity: current.quantity + 1);
      state = state.copyWith(items: updatedList);
      return true;
    } else {
      if (cap <= 0) return false;
      final newItem = PosCartItem(
        productId: product.id,
        productName: product.name,
        sku: product.sku,
        unitPriceIdr: product.priceIdr,
        quantity: 1,
      );
      state = state.copyWith(items: [...state.items, newItem]);
      return true;
    }
  }

  /// Increment dari sheet keranjang (tanpa objek produk) — butuh batas max.
  bool incrementProduct(String productId, {required int maxPortions}) {
    final existingIndex = state.items.indexWhere((item) => item.productId == productId);
    if (existingIndex < 0) return false;
    final current = state.items[existingIndex];
    if (maxPortions > 0 && current.quantity + 1 > maxPortions) return false;
    final updatedList = List<PosCartItem>.from(state.items);
    updatedList[existingIndex] = current.copyWith(quantity: current.quantity + 1);
    state = state.copyWith(items: updatedList);
    return true;
  }

  /// Alias untuk sheet keranjang lama.
  bool addProductById(String productId, {int maxPortions = 0}) =>
      incrementProduct(productId, maxPortions: maxPortions);

  void decrementProduct(String productId) {
    final existingIndex = state.items.indexWhere((item) => item.productId == productId);
    if (existingIndex < 0) return;

    final current = state.items[existingIndex];
    if (current.quantity > 1) {
      final updatedList = List<PosCartItem>.from(state.items);
      updatedList[existingIndex] = current.copyWith(quantity: current.quantity - 1);
      state = state.copyWith(items: updatedList);
    } else {
      state = state.copyWith(
        items: state.items.where((i) => i.productId != productId).toList(),
      );
    }
  }

  void removeProduct(String productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.productId != productId).toList(),
    );
  }

  void setDiscount(int discount) {
    state = state.copyWith(discountIdr: discount);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void clearCart() {
    state = const PosCartState();
  }
}

final posCartProvider = StateNotifierProvider<PosCartNotifier, PosCartState>((ref) {
  return PosCartNotifier();
});

final posTransactionsProvider = FutureProvider.autoDispose.family<List<PosTransactionModel>, String?>((ref, outletId) async {
  final repo = ref.watch(posRepositoryProvider);
  return repo.getTransactions(outletId: outletId);
});
