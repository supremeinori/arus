import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/features/users/data/user_management_repository.dart';
import 'package:arus/features/users/presentation/user_management_provider.dart';
import 'package:arus/features/users/presentation/user_management_screen.dart';

void main() {
  group('User Management & Staff RBAC Tests', () {
    const ownerUser = UserModel(
      id: 'u-owner-001',
      name: 'Rina Kartika',
      email: 'owner@arus.demo',
      role: UserRole.owner,
      outlets: [
        OutletSummary(id: 'out-sudirman', name: 'Kopi Arus - Sudirman (HQ)', timezone: 'Asia/Jakarta'),
        OutletSummary(id: 'out-senopati', name: 'Kopi Arus - Senopati', timezone: 'Asia/Jakarta'),
      ],
    );

    const managerSudirman = UserModel(
      id: 'u-mgr-001',
      name: 'Budi Santoso',
      email: 'manager@arus.demo',
      role: UserRole.manager,
      outlets: [
        OutletSummary(id: 'out-sudirman', name: 'Kopi Arus - Sudirman (HQ)', timezone: 'Asia/Jakarta'),
      ],
    );

    test('Repository dapat melakukan CRUD dasar', () async {
      final repo = UserManagementRepository(null);
      final users = await repo.getUsers();
      expect(users.isNotEmpty, true);

      // Create
      final created = await repo.createUser(
        name: 'Staff Baru Test',
        email: 'staff.test@arus.demo',
        role: UserRole.staff,
        outletId: 'out-sudirman',
        outletName: 'Kopi Arus - Sudirman (HQ)',
        phone: '08123456789',
      );
      expect(created.name, 'Staff Baru Test');
      expect(created.role, UserRole.staff);

      // Read
      final updatedList = await repo.getUsers();
      expect(updatedList.any((u) => u.id == created.id), true);

      // Update
      final updated = await repo.updateUser(
        id: created.id,
        name: 'Staff Updated',
      );
      expect(updated.name, 'Staff Updated');

      // Delete
      await repo.deleteUser(created.id);
      final afterDelete = await repo.getUsers();
      expect(afterDelete.any((u) => u.id == created.id), false);
    });

    test('Owner: Dapat melihat semua pengguna dan membuat akun Manager & Kasir dengan assignment outlet', () async {
      final repo = UserManagementRepository(null);
      final containerRef = ProviderContainer(
        overrides: [
          userManagementRepositoryProvider.overrideWithValue(repo),
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(
              ref.watch(authRepositoryProvider),
              ref.watch(secureStoreProvider),
            );
            notifier.state = AuthState.authenticated(ownerUser);
            return notifier;
          }),
        ],
      );

      // Wait initial load
      await containerRef.read(userManagementProvider.notifier).loadUsers();

      // Owner dapat melihat semua pengguna
      final visible = containerRef.read(visibleUsersProvider);
      expect(visible.any((u) => u.role == UserRole.owner), true);
      expect(visible.any((u) => u.role == UserRole.manager), true);
      expect(visible.any((u) => u.role == UserRole.staff), true);

      // Owner dapat membuat Manager baru dengan assign outlet
      final newManager = await containerRef.read(userManagementProvider.notifier).createUser(
            name: 'Pak Joko Manager',
            email: 'joko@arus.demo',
            role: UserRole.manager,
            outletId: 'out-bsd',
            outletName: 'Kopi Arus - BSD Serpong',
          );
      expect(newManager.role, UserRole.manager);
      expect(newManager.outletId, 'out-bsd');

      // Owner dapat membuat Kasir baru dengan assign outlet
      final newStaff = await containerRef.read(userManagementProvider.notifier).createUser(
            name: 'Ani Kasir',
            email: 'ani@arus.demo',
            role: UserRole.staff,
            outletId: 'out-bsd',
            outletName: 'Kopi Arus - BSD Serpong',
          );
      expect(newStaff.role, UserRole.staff);
      expect(newStaff.outletId, 'out-bsd');

      // Owner dapat mengupdate outlet Manager
      final updatedManager = await containerRef.read(userManagementProvider.notifier).updateUser(
            id: newManager.id,
            outletId: 'out-senopati',
            outletName: 'Kopi Arus - Senopati',
          );
      expect(updatedManager.outletId, 'out-senopati');

      // Owner dapat menghapus Manager
      await containerRef.read(userManagementProvider.notifier).deleteUser(newManager.id);
      final afterDelete = containerRef.read(visibleUsersProvider);
      expect(afterDelete.any((u) => u.id == newManager.id), false);
    });

    test('Manager: HANYA dapat melihat dan mengelola kasir di cabangnya sendiri', () async {
      final repo = UserManagementRepository(null);
      final containerRef = ProviderContainer(
        overrides: [
          userManagementRepositoryProvider.overrideWithValue(repo),
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(
              ref.watch(authRepositoryProvider),
              ref.watch(secureStoreProvider),
            );
            notifier.state = AuthState.authenticated(managerSudirman);
            return notifier;
          }),
        ],
      );

      await containerRef.read(userManagementProvider.notifier).loadUsers();

      // Manager HANYA boleh melihat kasir di cabangnya (out-sudirman)
      final visible = containerRef.read(visibleUsersProvider);
      expect(visible.every((u) => u.role == UserRole.staff), true);
      expect(visible.every((u) => u.outletId == 'out-sudirman'), true);
      // Tidak melihat kasir cabang Senopati (u-staff-003, out-senopati)
      expect(visible.any((u) => u.outletId == 'out-senopati'), false);

      // Manager dapat menambah kasir di cabangnya sendiri
      final kasirBaru = await containerRef.read(userManagementProvider.notifier).createUser(
            name: 'Rudi Kasir Sudirman',
            email: 'rudi@arus.demo',
            role: UserRole.staff,
            outletId: 'out-sudirman',
            outletName: 'Kopi Arus - Sudirman (HQ)',
          );
      expect(kasirBaru.name, 'Rudi Kasir Sudirman');
      expect(kasirBaru.outletId, 'out-sudirman');

      // Manager TIDAK BISA membuat Manager (akan throw exception)
      expect(
        () => containerRef.read(userManagementProvider.notifier).createUser(
              name: 'Hacker Manager',
              email: 'hacker@arus.demo',
              role: UserRole.manager,
              outletId: 'out-sudirman',
              outletName: 'Kopi Arus - Sudirman (HQ)',
            ),
        throwsA(isA<Exception>()),
      );

      // Manager TIDAK BISA menambah kasir ke cabang lain (misal out-senopati)
      expect(
        () => containerRef.read(userManagementProvider.notifier).createUser(
              name: 'Kasir Nyasar',
              email: 'nyasar@arus.demo',
              role: UserRole.staff,
              outletId: 'out-senopati',
              outletName: 'Kopi Arus - Senopati',
            ),
        throwsA(isA<Exception>()),
      );

      // Manager dapat menghapus kasir di cabangnya
      await containerRef.read(userManagementProvider.notifier).deleteUser(kasirBaru.id);

      // Manager TIDAK BISA menghapus kasir cabang lain (misal u-staff-003 di Senopati)
      expect(
        () => containerRef.read(userManagementProvider.notifier).deleteUser('u-staff-003'),
        throwsA(isA<Exception>()),
      );
    });

    testWidgets('Widget Test: UserManagementScreen tampilan Owner', (tester) async {
      final repo = UserManagementRepository(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userManagementRepositoryProvider.overrideWithValue(repo),
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
            home: UserManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Manajemen Pengguna & Tim'), findsOneWidget);
      expect(find.text('Tambah Akun'), findsOneWidget);
      expect(find.text('Total Pengguna'), findsOneWidget);
      expect(find.text('Manager'), findsWidgets);
      expect(find.text('Kasir'), findsWidgets);
    });

    testWidgets('Widget Test: UserManagementScreen tampilan Manager', (tester) async {
      final repo = UserManagementRepository(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userManagementRepositoryProvider.overrideWithValue(repo),
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                ref.watch(authRepositoryProvider),
                ref.watch(secureStoreProvider),
              );
              notifier.state = AuthState.authenticated(managerSudirman);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: UserManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kelola Kasir Cabang'), findsOneWidget);
      expect(find.text('Tambah Kasir'), findsOneWidget);
      expect(find.textContaining('Akses Terbatas Cabang Manager'), findsOneWidget);
      expect(find.textContaining('Kopi Arus - Sudirman (HQ)'), findsWidgets);
      // Tidak boleh ada kasir Senopati (Ahmad Fauzi)
      expect(find.text('Ahmad Fauzi'), findsNothing);
    });
  });
}
