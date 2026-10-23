import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/features/operations/presentation/operations_hub_screen.dart';

void main() {
  group('OperationsHubScreen RBAC Widget Tests', () {
    const ownerUser = UserModel(
      id: 'u-owner-1',
      name: 'Rina Owner',
      email: 'owner@arus.demo',
      role: UserRole.owner,
    );

    const managerUser = UserModel(
      id: 'u-mgr-1',
      name: 'Doni Manager',
      email: 'manager@arus.demo',
      role: UserRole.manager,
    );

    testWidgets('Owner melihat 4 blok: Produk, Inventaris, Kelola Staf & Akun, Hiburan', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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
          ],
          child: const MaterialApp(
            home: OperationsHubScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pusat Operasi'), findsOneWidget);
      expect(find.text('Produk'), findsOneWidget);
      expect(find.text('Inventaris'), findsOneWidget);
      expect(find.text('Kelola Staf & Akun'), findsOneWidget);
      expect(find.text('Hiburan'), findsOneWidget);
      // Revisi 22 Okt 2026: kartu POS, Cabang, dan Ledger dipindahkan dari Pusat Operasi.
      expect(find.text('Mesin Kasir'), findsNothing);
      expect(find.text('Cabang'), findsNothing);
      expect(find.text('Ledger'), findsNothing);
      expect(find.text('Mini-Game Menu'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Manager TIDAK melihat blok Produk, layout menyesuaikan rapi', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                ref.watch(authRepositoryProvider),
                ref.watch(secureStoreProvider),
              );
              notifier.state = AuthState.authenticated(managerUser);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: OperationsHubScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pusat Operasi'), findsOneWidget);
      // Sembunyikan sepenuhnya Produk untuk Manager
      expect(find.text('Produk'), findsNothing);
      expect(find.text('Cabang'), findsNothing);

      // Fitur operasional manajerial tetap ada
      expect(find.text('Inventaris'), findsOneWidget);
      expect(find.text('Kelola Staf & Akun'), findsOneWidget);
      expect(find.text('Hiburan'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
