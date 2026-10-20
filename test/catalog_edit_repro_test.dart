import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arus/core/network/api_client.dart';
import 'package:arus/core/storage/local_db.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/features/catalog/domain/category_model.dart';
import 'package:arus/features/catalog/domain/product_model.dart';
import 'package:arus/features/catalog/presentation/catalog_provider.dart';
import 'package:arus/features/catalog/presentation/product_form_screen.dart';
import 'package:arus/features/inventory/domain/inventory_models.dart';
import 'package:arus/features/inventory/presentation/inventory_provider.dart';

/// Payload persis seperti balasan API sungguhan untuk GET /api/products/:id
/// (diambil dari server lokal saat verifikasi).
const Map<String, dynamic> _liveProduct = {
  'id': 'ac3c3a00-6c23-4964-806b-ec1a6ff1c517',
  'name': 'Americano Dingin',
  'sku': 'BEV-AME-01',
  'price_idr': 18000,
  'image_url':
      'https://images.unsplash.com/photo-1551030173-122aabc4489c?auto=format&fit=crop&w=500&q=80',
  'category_id': '4d5cfc73-9c40-44c5-8052-d405ce434fd2',
  'category': {'id': '4d5cfc73-9c40-44c5-8052-d405ce434fd2', 'name': 'Minuman'},
  'is_active': true,
  'estimated_portions': 64,
  'cost_idr': 3360,
  'recipes': [
    {
      'id': 'r-1',
      'ingredient_id': '6afadbee-1111-4111-8111-111111111111',
      'amount_needed': 20,
      'ingredient_name': 'Biji Kopi Arabika House Blend',
      'ingredient_unit': 'gram',
      'stock_qty': 1000,
      'cost_per_unit': 120,
    },
    {
      'id': 'r-2',
      'ingredient_id': '3e9b7c53-2222-4222-8222-222222222222',
      'amount_needed': 180,
      'ingredient_name': 'Air Mineral Purified',
      'ingredient_unit': 'ml',
      'stock_qty': 5000,
      'cost_per_unit': 2,
    },
  ],
  'created_at': '2026-10-01T00:00:00.000Z',
  'updated_at': '2026-10-01T00:00:00.000Z',
};

class _FakeAdapter implements HttpClientAdapter {
  final List<String> requestedPaths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    final payload = jsonEncode({'data': _liveProduct});
    return ResponseBody.fromString(
      payload,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeSecureStore extends Fake implements SecureStore {
  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<String?> getRefreshToken() async => null;
}

class _FakeLocalDb extends Fake implements LocalDatabase {
  final List<ProductModel> cached = [];

  @override
  Future<void> cacheSingleProduct(ProductModel product) async => cached.add(product);

  @override
  Future<List<ProductModel>> getCachedProducts({String? categoryId, String? search}) async =>
      const [];
}

void main() {
  testWidgets(
    'Form edit memuat data produk dari balasan API (jalur repository nyata)',
    (tester) async {
      final adapter = _FakeAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'))
        ..httpClientAdapter = adapter;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStoreProvider.overrideWithValue(_FakeSecureStore()),
            localDbProvider.overrideWithValue(_FakeLocalDb()),
            apiClientProvider.overrideWithValue(
              ApiClient(secureStore: _FakeSecureStore(), customDio: dio),
            ),
            categoriesProvider.overrideWith((ref) async => const <CategoryModel>[]),
            ingredientsListProvider.overrideWith((ref) async => const <IngredientModel>[]),
          ],
          child: const MaterialApp(
            home: ProductFormScreen(productId: 'ac3c3a00-6c23-4964-806b-ec1a6ff1c517'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Form harus dalam mode edit
      expect(find.text('Edit Menu / Produk'), findsOneWidget);

      // Data produk harus terisi ke field
      expect(find.text('Americano Dingin'), findsOneWidget,
          reason: 'nama produk tidak terisi di form edit');
      expect(find.text('BEV-AME-01'), findsOneWidget,
          reason: 'SKU tidak terisi di form edit');
      expect(find.text('18000'), findsOneWidget,
          reason: 'harga jual tidak terisi di form edit');
      expect(find.text('3360'), findsOneWidget,
          reason: 'HPP tidak terisi di form edit');
      expect(
        find.text(
            'https://images.unsplash.com/photo-1551030173-122aabc4489c?auto=format&fit=crop&w=500&q=80'),
        findsOneWidget,
        reason: 'URL gambar tidak terisi di form edit',
      );

      // Resep: bahan harus tampil, walau tidak ada di daftar inventory
      expect(find.textContaining('Biji Kopi Arabika'), findsWidgets,
          reason: 'bahan resep tidak tampil di dropdown');

      expect(adapter.requestedPaths, contains('/products/ac3c3a00-6c23-4964-806b-ec1a6ff1c517'));
    },
  );
}
