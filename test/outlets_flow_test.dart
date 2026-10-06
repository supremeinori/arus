import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/features/outlets/domain/outlet_models.dart';
import 'package:arus/features/outlets/presentation/outlets_provider.dart';
import 'package:arus/features/outlets/presentation/outlet_list_screen.dart';
import 'package:arus/features/outlets/presentation/outlet_detail_screen.dart';

void main() {
  group('Outlets & LBS Flow Widget Tests (Milestone 11)', () {
    const ownerUser = UserModel(
      id: 'u-owner-1',
      name: 'Rina Owner',
      email: 'owner@arus.demo',
      role: UserRole.owner,
    );

    final sampleOutlets = [
      OutletModel(
        id: 'out-jogja',
        name: 'ARUS Jogja Malioboro',
        address: 'Jl. Malioboro No. 45, Yogyakarta',
        latitude: -7.7828,
        longitude: 110.3670,
        timezone: 'Asia/Jakarta',
        isActive: true,
        inventoryCount: 35,
        assignedUsersCount: 4,
        createdAt: DateTime(2026, 1, 1),
      ),
      OutletModel(
        id: 'out-london',
        name: 'ARUS London Oxford',
        address: '14 Oxford Street, London',
        latitude: 51.5074,
        longitude: -0.1278,
        timezone: 'Europe/London',
        isActive: true,
        inventoryCount: 20,
        assignedUsersCount: 2,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    final sampleNearest = NearestOutletResult(
      nearestOutlet: const NearbyOutletItem(
        id: 'out-jogja',
        name: 'ARUS Jogja Malioboro',
        address: 'Jl. Malioboro No. 45, Yogyakarta',
        latitude: -7.7828,
        longitude: 110.3670,
        timezone: 'Asia/Jakarta',
        distanceKm: 0.8,
      ),
      allOutletsSorted: const [
        NearbyOutletItem(
          id: 'out-jogja',
          name: 'ARUS Jogja Malioboro',
          address: 'Jl. Malioboro No. 45, Yogyakarta',
          latitude: -7.7828,
          longitude: 110.3670,
          timezone: 'Asia/Jakarta',
          distanceKm: 0.8,
        ),
      ],
    );

    testWidgets('OutletListScreen menampilkan daftar cabang dan tombol Tambah Cabang', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                ref.watch(authRepositoryProvider),
                ref.watch(secureStoreProvider),
              );
              notifier.state = AuthState.authenticated(ownerUser);
              return notifier;
            }),
            outletsListProvider.overrideWith((ref) async => sampleOutlets),
            nearestOutletProvider.overrideWith((ref) async => sampleNearest),
          ],
          child: const MaterialApp(
            home: OutletListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Manajemen Cabang & LBS'), findsOneWidget);
      expect(find.text('ARUS Jogja Malioboro'), findsOneWidget);
      expect(find.text('ARUS London Oxford'), findsOneWidget);
      expect(find.text('35 SKU Produk'), findsOneWidget);
      expect(find.text('Tambah Cabang'), findsOneWidget);
    });

    testWidgets('OutletListScreen Tab LBS menampilkan highlight cabang terdekat dan simulasi GPS', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                ref.watch(authRepositoryProvider),
                ref.watch(secureStoreProvider),
              );
              notifier.state = AuthState.authenticated(ownerUser);
              return notifier;
            }),
            outletsListProvider.overrideWith((ref) async => sampleOutlets),
            nearestOutletProvider.overrideWith((ref) async => sampleNearest),
          ],
          child: const MaterialApp(
            home: OutletListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pindah ke Tab Peta & LBS
      final lbsTab = find.text('Peta & LBS Terdekat');
      expect(lbsTab, findsOneWidget);
      await tester.tap(lbsTab);
      await tester.pumpAndSettle();

      expect(find.text('Simulasi Posisi Pengguna (LBS GPS)'), findsOneWidget);
      expect(find.text('CABANG TERDEKAT (LBS)'), findsOneWidget);
      expect(find.textContaining('0.8 km'), findsAtLeastNWidgets(1));
      expect(find.text('Buka Detail Cabang Terdekat'), findsOneWidget);
    });

    testWidgets('OutletDetailScreen menampilkan koordinat GPS, live jam lokal, dan staf bertugas', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            outletDetailProvider('out-jogja').overrideWith((ref) async => sampleOutlets.first),
          ],
          child: const MaterialApp(
            home: OutletDetailScreen(outletId: 'out-jogja'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Detail Cabang'), findsOneWidget);
      expect(find.text('ARUS Jogja Malioboro'), findsOneWidget);
      expect(find.text('Operasional Aktif'), findsOneWidget);
      expect(find.textContaining('Koordinat GPS: -7.7828, 110.3670'), findsOneWidget);
      expect(find.text('35 Produk'), findsOneWidget);
      expect(find.text('4 Orang'), findsOneWidget);
      expect(find.text('Lihat Inventaris Cabang Ini'), findsOneWidget);
    });
  });
}
