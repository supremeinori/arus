import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/operations/presentation/operations_hub_screen.dart';

void main() {
  group('OperationsHubScreen Widget Tests', () {
    testWidgets('OperationsHubScreen menampilkan Hero POS, Kategori Manajemen & Utilitas beserta kartu grid', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OperationsHubScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan AppBar dan Hero POS
      expect(find.text('Pusat Operasi'), findsOneWidget);
      expect(find.text('Mesin Kasir (POS)'), findsOneWidget);
      expect(find.text('Kasir Utama'), findsOneWidget);

      // Memastikan Kategori Manajemen dan Modulnya
      expect(find.text('Manajemen'), findsOneWidget);
      expect(find.text('5 Modul'), findsOneWidget);
      expect(find.text('Katalog & Kategori'), findsOneWidget);
      expect(find.text('Inventaris & Stok'), findsOneWidget);
      expect(find.text('Kelola Staf & Akun'), findsOneWidget);
      expect(find.text('Cabang & LBS'), findsOneWidget);
      expect(find.text('Integritas Ledger'), findsOneWidget);

      // Memastikan Kategori Fitur Tambahan dan Modulnya (Pengaturan Kurs & Sensor sudah dipindahkan ke Profil/Pengaturan)
      expect(find.text('Fitur Tambahan'), findsOneWidget);
      expect(find.text('1 Modul'), findsOneWidget);
      expect(find.text('Mini-Game Menu'), findsOneWidget);
      expect(find.text('Pengaturan Kurs'), findsNothing);
      expect(find.text('Sensor & Biometrik'), findsNothing);
      expect(find.text('Rekomendasi AI'), findsNothing);

      // Memastikan tidak ada render overflow exception
      expect(tester.takeException(), isNull);
    });
  });
}
