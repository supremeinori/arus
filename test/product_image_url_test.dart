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
import 'package:arus/features/catalog/presentation/menu_create_screen.dart';
import 'package:arus/features/catalog/presentation/widgets/product_image_url_field.dart';
import 'package:arus/features/inventory/domain/inventory_models.dart';
import 'package:arus/features/inventory/presentation/inventory_provider.dart';

const String _kProductId = 'ac3c3a00-6c23-4964-806b-ec1a6ff1c517';
const String _kImageUrl =
    'https://images.unsplash.com/photo-1551030173-122aabc4489c?auto=format&fit=crop&w=500&q=80';

/// Balasan GET /api/products/:id yang persis seperti server.
const Map<String, dynamic> _liveProduct = {
  'id': _kProductId,
  'name': 'Americano Dingin',
  'sku': 'BEV-AME-01',
  'price_idr': 18000,
  'image_url': _kImageUrl,
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
  ],
};

class _FakeAdapter implements HttpClientAdapter {
  final List<String> requestedPaths = [];
  final List<Map<String, dynamic>> postBodies = [];
  final List<Map<String, dynamic>> patchBodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add('${options.method} ${options.path}');

    final raw = options.data;
    Map<String, dynamic> body = const {};
    if (raw is String) {
      body = jsonDecode(raw) as Map<String, dynamic>;
    } else if (raw is Map) {
      body = Map<String, dynamic>.from(raw);
    }

    if (options.method == 'POST') {
      postBodies.add(body);
      return _json({
        'data': {
          ..._liveProduct,
          'id': 'new-product-id',
          'name': body['name'],
          'sku': body['sku'],
          'image_url': body['image_url'],
          'recipes': body['recipes'],
        }
      });
    }
    if (options.method == 'PATCH') {
      patchBodies.add(body);
      return _json({'data': _liveProduct});
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
  @override
  Future<void> cacheSingleProduct(ProductModel product) async {}

  @override
  Future<List<ProductModel>> getCachedProducts({String? categoryId, String? search}) async =>
      const [];
}

Widget _wrap(_FakeAdapter adapter, {String? productId}) {
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
    child: MaterialApp(
      home: MenuCreateScreen(productId: productId),
    ),
  );
}

void main() {
  group('Normalisasi & validasi URL gambar produk', () {
    test('URL kosong dianggap tidak ada gambar (field opsional)', () {
      expect(normalizeImageUrl(null), isNull);
      expect(normalizeImageUrl(''), isNull);
      expect(normalizeImageUrl('   '), isNull);
      expect(validateImageUrlField(''), isNull);
      expect(validateImageUrlField(null), isNull);
    });

    test('Hanya http/https dengan host yang diterima', () {
      expect(normalizeImageUrl('https://example.com/a.png'), 'https://example.com/a.png');
      expect(normalizeImageUrl('http://example.com/a.png'), 'http://example.com/a.png');
      expect(normalizeImageUrl('ftp://example.com/a.png'), isNull);
      expect(normalizeImageUrl('file:///etc/passwd'), isNull);
      expect(normalizeImageUrl('javascript:alert(1)'), isNull);
      expect(normalizeImageUrl('https://'), isNull);
      expect(normalizeImageUrl('bukan-url'), isNull);
    });

    test('Validator menolak URL tidak valid dengan pesan yang jelas', () {
      expect(
        validateImageUrlField('bukan-url'),
        'URL gambar tidak valid (harus diawali http:// atau https://)',
      );
      expect(validateImageUrlField('https://example.com/a.png'), isNull);
    });
  });

  group('Form produk — field URL gambar (opsional)', () {
    testWidgets('Mode edit memuat image_url dari API ke field', (tester) async {
      final adapter = _FakeAdapter();
      await tester.pumpWidget(_wrap(adapter, productId: _kProductId));
      await tester.pumpAndSettle();

      expect(find.text('Edit Menu / Produk'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, _kImageUrl),
        findsOneWidget,
        reason: 'image_url dari server harus terisi di field URL gambar',
      );
    });

    testWidgets('Mode edit mengirim image_url saat disimpan', (tester) async {
      final adapter = _FakeAdapter();
      await tester.pumpWidget(_wrap(adapter, productId: _kProductId));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Simpan Perubahan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(adapter.patchBodies, isNotEmpty, reason: 'tidak ada request PATCH');
      expect(
        adapter.patchBodies.last['image_url'],
        _kImageUrl,
        reason: 'image_url harus dikirim apa adanya saat form edit disimpan',
      );
    });

    testWidgets('URL dikosongkan di mode edit menghapus gambar di server', (tester) async {
      final adapter = _FakeAdapter();
      await tester.pumpWidget(_wrap(adapter, productId: _kProductId));
      await tester.pumpAndSettle();

      // Kosongkan lewat tombol hapus (suffixIcon).
      await tester.tap(find.byTooltip('Kosongkan URL gambar'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Simpan Perubahan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(adapter.patchBodies, isNotEmpty, reason: 'tidak ada request PATCH');
      expect(
        adapter.patchBodies.last.containsKey('image_url'),
        isTrue,
        reason: 'field gambar harus dikirim eksplisit',
      );
      expect(
        adapter.patchBodies.last['image_url'],
        isNull,
        reason: 'URL yang dikosongkan harus menjadi null di server',
      );
    });

    testWidgets('URL tidak valid ditolak validator form dan tidak disimpan',
        (tester) async {
      final adapter = _FakeAdapter();
      await tester.pumpWidget(_wrap(adapter, productId: _kProductId));
      await tester.pumpAndSettle();

      final field = find.widgetWithText(TextFormField, _kImageUrl);
      await tester.enterText(field, 'bukan-url');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Simpan Perubahan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(
        find.text('URL gambar tidak valid (harus diawali http:// atau https://)'),
        findsOneWidget,
        reason: 'validator harus menolak URL tidak valid',
      );
      expect(
        adapter.patchBodies,
        isEmpty,
        reason: 'form tidak boleh tersimpan dengan URL tidak valid',
      );
    });

    testWidgets('Preview menampilkan penanda untuk URL tidak valid', (tester) async {
      final adapter = _FakeAdapter();
      await tester.pumpWidget(_wrap(adapter, productId: _kProductId));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, _kImageUrl),
        'bukan-url',
      );
      await tester.pumpAndSettle();

      expect(find.text('URL tidak valid'), findsOneWidget);
    });

    testWidgets('Preview menampilkan placeholder saat URL kosong', (tester) async {
      final adapter = _FakeAdapter();
      await tester.pumpWidget(_wrap(adapter));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada gambar'), findsOneWidget);
      expect(find.text('Tambah Menu Baru'), findsOneWidget);
    });

    testWidgets('Gambar yang gagal dimuat tidak crash, tampil pesan gagal', (tester) async {
      final adapter = _FakeAdapter();
      await tester.pumpWidget(_wrap(adapter));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'https://images.unsplash.com/...'),
        'https://invalid.host.ganti/pic.png',
      );
      await tester.pumpAndSettle();

      // Tunggu jeda debounce preview, lalu waktu untuk request gambar gagal.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(
        find.text('Gagal memuat'),
        findsOneWidget,
        reason: 'gambar yang gagal dimuat harus punya fallback, bukan crash',
      );
    });
  });
}
