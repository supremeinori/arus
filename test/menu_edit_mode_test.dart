import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:arus/core/network/api_client.dart';
import 'package:arus/core/storage/local_db.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/features/catalog/domain/category_model.dart';
import 'package:arus/features/catalog/domain/product_model.dart';
import 'package:arus/features/catalog/presentation/catalog_provider.dart';
import 'package:arus/features/catalog/presentation/menu_create_screen.dart';
import 'package:arus/features/inventory/domain/inventory_models.dart';
import 'package:arus/features/inventory/presentation/inventory_provider.dart';

/// Payload produk seperti balasan API sungguhan (GET /api/products/:id).
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
};

class _FakeAdapter implements HttpClientAdapter {
  final List<String> requestedPaths = [];
  final List<Map<String, dynamic>> patchBodies = [];
  bool isActive = true;
  bool rawRow = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add('${options.method} ${options.path}');
    if (options.method == 'PATCH') {
      final raw = options.data;
      final body = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
      patchBodies.add(body);
      if (body['is_active'] is bool) {
        isActive = body['is_active'] as bool;
      }
      if (rawRow) {
        // PATCH di API asli membalas baris Prisma mentah: tanpa objek
        // 'category', tanpa 'recipes', tanpa 'estimated_portions'.
        return _json({
          'data': {
            'id': _liveProduct['id'],
            'category_id': _liveProduct['category_id'],
            'sku': _liveProduct['sku'],
            'name': _liveProduct['name'],
            'price_idr': 18500,
            'is_active': isActive,
            'created_at': _liveProduct['created_at'],
            'updated_at': _liveProduct['updated_at'],
          }
        });
      }
      final updated = Map<String, dynamic>.from(_liveProduct);
      updated['is_active'] = isActive;
      return _json({'data': updated});
    }
    return _json({'data': _liveProduct});
  }

  ResponseBody _json(Map<String, dynamic> payload) => ResponseBody.fromString(
        jsonEncode(payload),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

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
  Widget buildScreen(_FakeAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'))
      ..httpClientAdapter = adapter;
    return ProviderScope(
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
        home: MenuCreateScreen(productId: 'ac3c3a00-6c23-4964-806b-ec1a6ff1c517'),
      ),
    );
  }

  testWidgets('Form edit (wizard menu) memuat data produk yang ada', (tester) async {
    final adapter = _FakeAdapter();
    await tester.pumpWidget(buildScreen(adapter));
    await tester.pumpAndSettle();

    expect(find.text('Edit Menu / Produk'), findsOneWidget,
        reason: 'judul layar edit tidak berubah');
    expect(find.text('Americano Dingin'), findsOneWidget,
        reason: 'nama produk tidak terisi di form edit');
    expect(find.text('BEV-AME-01'), findsOneWidget,
        reason: 'SKU tidak terisi di form edit');
    expect(find.text('18000'), findsOneWidget,
        reason: 'harga jual tidak terisi di form edit');
    expect(find.text('Simpan Perubahan'), findsOneWidget,
        reason: 'tombol simpan harus mode edit');
    expect(find.text('Nonaktifkan Menu'), findsOneWidget,
        reason: 'tombol nonaktifkan harus ada di mode edit');

    // Resep: bahan tersimpan harus tampil walau tidak ada di daftar inventory.
    expect(find.textContaining('Biji Kopi Arabika'), findsWidgets,
        reason: 'bahan resep tidak tampil di dropdown');
    expect(find.textContaining('Air Mineral Purified'), findsWidgets,
        reason: 'bahan resep kedua tidak tampil di dropdown');

    expect(
      adapter.requestedPaths,
      contains('GET /products/ac3c3a00-6c23-4964-806b-ec1a6ff1c517'),
    );
  });

  testWidgets('Tombol Nonaktifkan mengirim is_active=false tanpa menghapus resep',
      (tester) async {
    final adapter = _FakeAdapter();
    await tester.pumpWidget(buildScreen(adapter));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Nonaktifkan Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Nonaktifkan Menu'));
    await tester.pumpAndSettle();

    expect(adapter.patchBodies, isNotEmpty, reason: 'tidak ada request PATCH');
    final body = adapter.patchBodies.last;
    expect(body['is_active'], isFalse, reason: 'is_active harus dikirim false');
    expect(body.containsKey('recipes'), isFalse,
        reason: 'toggle status tidak boleh mengirim/menghapus resep');
    expect(body.containsKey('image_url'), isFalse,
        reason: 'form ini tidak mengelola gambar, jadi tidak boleh dikirim');
    expect(find.text('Aktifkan Menu'), findsOneWidget,
        reason: 'tombol harus berubah jadi Aktifkan Menu');
  });

  testWidgets('Simpan perubahan memakai balasan PATCH asli (baris Prisma mentah)',
      (tester) async {
    final adapter = _FakeAdapter()..rawRow = true;
    await tester.pumpWidget(buildScreen(adapter));
    await tester.pumpAndSettle();

    // ubah harga jual jadi 18500
    final priceField = find.widgetWithText(TextFormField, '18000');
    expect(priceField, findsOneWidget);
    await tester.enterText(priceField, '18500');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Simpan Perubahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(adapter.patchBodies, isNotEmpty, reason: 'tidak ada request PATCH');
    expect(find.textContaining('Null check operator'), findsNothing,
        reason: 'penyimpanan harus tidak melempar error null check');
    expect(find.textContaining('Perubahan menu tersimpan'), findsOneWidget,
        reason: 'simpan harus berhasil dan memberi feedback');
  });

  /// Regresi: app memakai ShadApp.router yang TIDAK menyediakan
  /// ScaffoldMessenger. Sebelum diperbaiki, ScaffoldMessenger.of(context)
  /// melempar "Null check operator used on a null value" (release) /
  /// "No ScaffoldMessenger widget found" (debug) SETELAH PATCH sukses,
  /// sehingga user melihat error padahal data sudah tersimpan.
  testWidgets('Simpan tetap sukses tanpa ScaffoldMessenger ancestor (app shadcn)',
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
          ingredientsListProvider
              .overrideWith((ref) async => const <IngredientModel>[]),
        ],
        child: ShadApp.router(
          routerConfig: GoRouter(
            initialLocation: '/edit',
            routes: [
              GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
              GoRoute(
                path: '/edit',
                builder: (context, state) => const MenuCreateScreen(
                  productId: 'ac3c3a00-6c23-4964-806b-ec1a6ff1c517',
                ),
              ),
            ],
          ),
          materialThemeBuilder: (context, theme) => ThemeData.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Americano Dingin'), findsOneWidget,
        reason: 'produk harus ter-load sebelum disimpan');

    await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Simpan Perubahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(adapter.patchBodies, isNotEmpty, reason: 'tidak ada request PATCH');
    expect(find.textContaining('Null check operator'), findsNothing);
    expect(find.textContaining('No ScaffoldMessenger'), findsNothing);
    expect(find.textContaining('Perubahan menu tersimpan'), findsNothing,
        reason: 'tanpa ScaffoldMessenger tidak ada snackbar, tapi tidak boleh error');
  });
}
