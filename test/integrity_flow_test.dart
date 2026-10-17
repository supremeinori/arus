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
    'Owner sees live single-layer transaction blocks for the selected outlet',
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
          blockCount: 1,
          blocks: [
            IntegrityBlockItem(
              index: 1,
              eventId: 'sale:trx-1',
              eventType: 'sale',
              transactionId: 'trx-1',
              timestamp: '2026-10-15T10:30:00.000Z',
              hash: 'transaction-hash-live',
              previousHash:
                  '0000000000000000000000000000000000000000000000000000000000000000',
              dataHash: 'data-hash-live',
              data: {
                'receipt_no': 'INV-REAL-0001',
                'total_idr': 42000,
                'cashier_id': 'cashier-1',
              },
              recoverable: true,
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

      expect(find.text('BLOK #1 (GENESIS)'), findsOneWidget);
      expect(find.text('Struk: INV-REAL-0001'), findsOneWidget);
      expect(find.textContaining('42.000'), findsOneWidget);
      expect(find.text('transaction-hash-live'), findsOneWidget);
      expect(find.textContaining('VALID ·'), findsOneWidget);
      expect(find.text('Uji Integritas'), findsOneWidget);
    },
  );
}
