import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../catalog/domain/product_model.dart';
import '../domain/pos_models.dart';

/// Item katalog kasir: produk + ketersediaan stok per outlet.
class PosCatalogItem {
  final ProductModel product;
  final bool isAvailable;
  final int maxPortions;

  const PosCatalogItem({
    required this.product,
    required this.isAvailable,
    required this.maxPortions,
  });

  factory PosCatalogItem.fromJson(Map<String, dynamic> json) {
    // Bentuk backend /api/pos/catalog flat; map ulang ke ProductModel
    // agar grid POS bisa reuse formatter & badge yang sudah ada.
    final product = ProductModel.fromJson({
      'id': json['id'],
      'sku': json['sku'],
      'name': json['name'],
      'price_idr': json['price_idr'],
      'cost_idr': json['unit_cost_idr'],
      'category_id': json['category_id'],
      'category': json['category'],
      'image_url': json['image_url'],
      'is_active': true,
      'estimated_portions': json['max_portions'],
      'recipes': [],
    });
    return PosCatalogItem(
      product: product,
      isAvailable: json['is_available'] as bool? ?? false,
      maxPortions: json['max_portions'] as int? ?? 0,
    );
  }
}

final posCatalogRepositoryProvider = Provider<PosCatalogRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PosCatalogRepository(apiClient);
});

/// Repository khusus endpoint /api/pos/* (katalog kasir, checkout, void).
/// Repository transaksi lama (pos_repository.dart) tetap dipakai untuk
/// mode offline — modul ini hanya menambah jalur online sesuai spek.
class PosCatalogRepository {
  final ApiClient _client;

  PosCatalogRepository(this._client);

  Future<List<PosCatalogItem>> getCatalog(String outletId) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/pos/catalog',
      queryParameters: {'outlet_id': outletId},
    );
    final list = res.data?['data'] as List<dynamic>? ?? [];
    return list.map((e) => PosCatalogItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PosTransactionModel> checkout({
    required String outletId,
    required String clientRequestId,
    required String paymentMethod,
    required int paidIdr,
    int discountIdr = 0,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/pos/checkout',
      data: {
        'outlet_id': outletId,
        'client_request_id': clientRequestId,
        'payment_method': paymentMethod,
        'paid_idr': paidIdr,
        'discount_idr': discountIdr,
        'items': items,
      },
    );
    return PosTransactionModel.fromJson(res.data?['data'] as Map<String, dynamic>);
  }

  Future<PosTransactionModel> voidTransaction({
    required String transactionId,
    String? outletId,
    required String reason,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/pos/void',
      data: {
        'transaction_id': transactionId,
        if (outletId != null && outletId.isNotEmpty) 'outlet_id': outletId,
        'reason': reason,
      },
    );
    return PosTransactionModel.fromJson(res.data?['data'] as Map<String, dynamic>);
  }
}

/// Outlet aktif kasir: staff/manager terkunci ke outlet pertama,
/// owner memakai pilihan inventory (atau outlet pertama bila belum pilih).
/// Dipakai katalog POS, checkout, dan riwayat agar konsisten satu sumber.
final activePosOutletProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null || user.outlets.isEmpty) return null;
  if (user.role != UserRole.owner) return user.outlets.first.id;
  return null; // owner: fallback ke outlet pertama di screen via selectedInventoryOutlet
});
