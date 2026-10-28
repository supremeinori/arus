import 'package:flutter_test/flutter_test.dart';
import 'package:arus/core/utils/datetime_utils.dart';
import 'package:arus/features/catalog/domain/product_model.dart';
import 'package:arus/features/pos/domain/pos_models.dart';
import 'package:arus/features/pos/presentation/pos_provider.dart';

void main() {
  group('Realtime Cart Portion Validation Tests', () {
    const testProduct = ProductModel(
      id: 'prod-latte',
      sku: 'LATTE-01',
      name: 'Cafe Latte',
      priceIdr: 25000,
      estimatedPortions: 3,
    );

    test('addProduct berhasil jika stok bahan baku mencukupi', () {
      final notifier = PosCartNotifier();
      final added = notifier.addProduct(testProduct, maxPortions: 3);

      expect(added, isTrue);
      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.first.quantity, 1);
    });

    test('addProduct gagal jika estimasi porsi 0 (bahan baku habis)', () {
      final notifier = PosCartNotifier();
      final added = notifier.addProduct(testProduct, maxPortions: 0);

      expect(added, isFalse);
      expect(notifier.state.items.isEmpty, isTrue);
    });

    test('incrementProductWithValidation menolak penambahan saat melebihi maxPortions', () {
      final notifier = PosCartNotifier();
      notifier.addProduct(testProduct, maxPortions: 2);
      notifier.incrementProduct(testProduct.id, maxPortions: 2); // Qty jadi 2

      expect(notifier.state.items.first.quantity, 2);

      // Coba tambah lagi porsi ke-3
      final error = notifier.incrementProductWithValidation(
        testProduct.id,
        maxPortions: 2,
        productName: testProduct.name,
      );

      expect(error, isNotNull);
      expect(error, contains('Maksimal estimasi porsi untuk "Cafe Latte" tercapai'));
      expect(error, contains('2 porsi'));
      expect(notifier.state.items.first.quantity, 2); // Tidak bertambah
    });

    test('incrementProductWithValidation menolak jika bahan baku habis (0 porsi)', () {
      final notifier = PosCartNotifier();
      // Misal item sudah ada di keranjang tapi stok cabang tiba-tiba 0
      notifier.state = notifier.state.copyWith(items: [
        PosCartItem(
          productId: testProduct.id,
          productName: testProduct.name,
          sku: testProduct.sku,
          unitPriceIdr: 25000,
          quantity: 1,
        ),
      ]);

      final error = notifier.incrementProductWithValidation(
        testProduct.id,
        maxPortions: 0,
        productName: testProduct.name,
      );

      expect(error, isNotNull);
      expect(error, contains('habis di cabang ini (0 porsi)'));
    });
  });

  group('Datetime Device Realtime Conversion Tests', () {
    test('parseToDeviceLocal mengonversi ISO UTC string dengan Z ke waktu lokal perangkat', () {
      const utcString = '2026-10-28T09:06:00.000Z';
      final localDt = parseToDeviceLocal(utcString);

      expect(localDt.isUtc, isFalse);
      final expectedHour = DateTime.parse(utcString).toLocal().hour;
      expect(localDt.hour, expectedHour);
    });

    test('parseToDeviceLocal mengonversi timestamp UTC tanpa Z ke waktu lokal perangkat', () {
      const rawDbString = '2026-10-28 09:06:00';
      final localDt = parseToDeviceLocal(rawDbString);

      expect(localDt.isUtc, isFalse);
      final expectedHour = DateTime.parse('2026-10-28T09:06:00Z').toLocal().hour;
      expect(localDt.hour, expectedHour);
    });

    test('parseToDeviceLocal menangani input null dan string kosong dengan aman', () {
      final dtNull = parseToDeviceLocal(null);
      final dtEmpty = parseToDeviceLocal('');

      expect(dtNull.isUtc, isFalse);
      expect(dtEmpty.isUtc, isFalse);
    });
  });
}
