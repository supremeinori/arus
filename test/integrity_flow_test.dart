import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/features/integrity/domain/integrity_models.dart';
import 'package:arus/features/integrity/presentation/integrity_chain_screen.dart';
import 'package:arus/features/integrity/presentation/integrity_provider.dart';
import 'package:arus/features/outlets/domain/outlet_models.dart';
import 'package:arus/features/outlets/presentation/outlets_provider.dart';

void main() {
  testWidgets(
    'Owner sees live daily and transaction blocks for the selected outlet',
    (tester) async {
      const owner = UserModel(
        id: 'owner-1',
        name: 'Owner',
        email: 'owner@arus.test',
        role: UserRole.owner,
      );
      final outlet = OutletModel(
        id: 'outlet-1',
        name: 'Jakarta Outlet',
        address: 'Jakarta',
        latitude: -6.2,
        longitude: 106.8,
        timezone: 'Asia/Jakarta',
        createdAt: DateTime(2026, 10, 16),
      );
      const snapshot = IntegrityChainSnapshot(
        overview: IntegrityChainOverview(
          outletId: 'outlet-1',
          totalDays: 1,
          currentActiveTxCount: 0,
          days: [
            IntegrityDailyBlock(
              dayIndex: 0,
              date: '2026-10-15',
              parentHash: 'parent-hash-live',
              previousParentHash: 'genesis-hash',
              merkleRoot: 'merkle-live',
              timestamp: '2026-10-16T00:00:00.000Z',
              transactionCount: 1,
              transactions: [
                IntegrityTransactionBlock(
                  index: 0,
                  timestamp: '2026-10-15T10:30:00.000Z',
                  hash: 'transaction-hash-live',
                  previousHash: 'genesis-hash',
                  receiptNo: 'INV-REAL-0001',
                  totalAmount: 42000,
                  cashierId: 'cashier-1',
                  eventType: 'sale',
                  sourceId: 'transaction-1',
                ),
              ],
            ),
          ],
        ),
        validation: IntegrityValidation(
          isValid: true,
          status: 'VALID',
          message: 'Chain is valid.',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                ref.watch(authRepositoryProvider),
                ref.watch(secureStoreProvider),
              );
              notifier.state = AuthState.authenticated(owner);
              return notifier;
            }),
            outletsListProvider.overrideWith((ref) async => [outlet]),
            integrityChainProvider('outlet-1')
                .overrideWith((ref) async => snapshot),
          ],
          child: const MaterialApp(home: IntegrityChainScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Daily block #0'));
      await tester.pumpAndSettle();

      expect(find.text('INV-REAL-0001'), findsOneWidget);
      expect(find.textContaining('42.000'), findsOneWidget);
      expect(find.text('parent-hash-live'), findsOneWidget);
      expect(find.textContaining('VALID ·'), findsOneWidget);
      expect(find.text('Uji Integritas'), findsOneWidget);
    },
  );
}
