import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/core/network/api_client.dart';
import 'package:arus/core/storage/local_db.dart';
import 'package:arus/features/analytics/data/analytics_repository.dart';
import 'package:arus/features/analytics/presentation/analytics_provider.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/pos/data/pos_repository.dart';
import 'package:arus/features/pos/domain/pos_models.dart';
import 'package:arus/features/pos/presentation/pos_catalog_provider.dart';
import 'package:arus/features/pos/presentation/pos_history_screen.dart';
import 'package:arus/features/pos/presentation/pos_receipt_dialog.dart';
import 'package:arus/features/shell/presentation/main_shell.dart';

class MockApiClient extends Fake implements ApiClient {
  final Map<String, dynamic>? Function(String path, {Map<String, dynamic>? queryParameters})? onGet;
  final Map<String, dynamic>? Function(String path, {dynamic data})? onPost;

  MockApiClient({this.onGet, this.onPost});

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (onGet != null) {
      final res = onGet!(path, queryParameters: queryParameters);
      if (res != null) {
        return Response<T>(
          data: res as T,
          statusCode: 200,
          requestOptions: RequestOptions(path: path),
        );
      }
    }
    throw DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionError,
      message: 'Koneksi ke web service terputus.',
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (onPost != null) {
      final res = onPost!(path, data: data);
      if (res != null) {
        return Response<T>(
          data: res as T,
          statusCode: 200,
          requestOptions: RequestOptions(path: path),
        );
      }
    }
    throw DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionError,
      message: 'Koneksi ke web service terputus.',
    );
  }
}

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(super.initialState);

  @override
  Future<void> checkAuth([bool requireBiometricIfEnabled = true]) async {}

  @override
  Future<bool> login(String email, String password) async => true;

  @override
  Future<bool> authenticateWithBiometric() async => true;

  @override
  Future<void> toggleBiometric(bool enabled) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<UserModel?> getPersistedUser() async => state.user;

  @override
  void setUnauthenticated([String? message]) {
    state = AuthState.unauthenticated(message);
  }

  @override
  void restoreSessionInstant(UserModel user, [String? refreshToken]) {
    state = AuthState.authenticated(user);
  }

  @override
  Future<void> applyDisplayCurrency(String currency) async {
    final user = state.user;
    if (user == null) return;
    state = AuthState.authenticated(
      user.copyWith(
        settings: user.settings.copyWith(displayCurrency: currency),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockCashierUser = UserModel(
    id: 'user_cashier_001',
    name: 'Siti Kasir',
    email: 'siti@arus.id',
    role: UserRole.staff,
    outlets: const [
      OutletSummary(id: 'outlet_pahlawan', name: 'Cabang Pahlawan', timezone: 'Asia/Jakarta'),
    ],
    settings: const UserSettingsSummary(),
  );

  group('Daily Analytics Caching System Tests', () {
    final localDb = LocalDatabase.instance;

    setUp(() async {
      await localDb.clearLocalDatabase();
    });

    test('getOverview caches online payload and serves complete data when offline + adds pending tx', () async {
      // 1. Online fetch: caches data
      final onlineClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (path == '/analytics/overview') {
            return {
              'data': {
                'revenue_idr': 480000,
                'subtotal_idr': 500000,
                'discount_idr': 20000,
                'transaction_count': 10,
                'avg_basket_size_idr': 48000,
                'gross_profit_idr': 280000,
              }
            };
          }
          return null;
        },
      );

      final onlineRepo = AnalyticsRepository(onlineClient, localDb);
      final onlineOverview = await onlineRepo.getOverview(outletId: 'outlet_pahlawan', from: '2026-10-27', to: '2026-10-27');
      expect(onlineOverview.revenueIdr, 480000);
      expect(onlineOverview.transactionCount, 10);
      expect(onlineOverview.isOffline, false);

      // Verify cached in LocalDatabase
      final cached = await localDb.getDailyAnalyticsCache('overview_outlet_pahlawan_2026-10-27_2026-10-27');
      expect(cached, isNotNull);
      expect(cached, contains('480000'));

      // 2. Add offline pending transaction locally
      final offlineTx = PosTransactionModel(
        id: 'tx_offline_001',
        receiptNo: 'OFF-20261027-999',
        outletId: 'outlet_pahlawan',
        outletName: 'Cabang Pahlawan',
        cashierName: 'Siti Kasir',
        subtotalIdr: 50000,
        discountIdr: 0,
        totalIdr: 50000,
        paymentMethod: 'cash',
        paidIdr: 50000,
        changeIdr: 0,
        status: 'offline_pending',
        createdAt: DateTime.parse('2026-10-27T10:00:00.000Z'),
        items: const [
          PosCartItem(
            productId: 'prod_1',
            productName: 'Kopi Susu Gula Aren',
            sku: 'KOP-01',
            unitPriceIdr: 25000,
            quantity: 2,
          ),
        ],
        isOfflinePending: true,
        clientRequestId: 'req_offline_001',
      );
      await localDb.saveOfflineTransaction(
        transaction: offlineTx,
        clientRequestId: 'req_offline_001',
        isSynced: false,
      );

      // 3. Offline fetch: repository fails network request, retrieves cached overview and merges pending
      final offlineClient = MockApiClient(); // Always throws connection error
      final offlineRepo = AnalyticsRepository(offlineClient, localDb);

      final offlineOverview = await offlineRepo.getOverview(outletId: 'outlet_pahlawan', from: '2026-10-27', to: '2026-10-27');
      expect(offlineOverview.isOffline, true);
      // Base (480,000) + offline pending (50,000) = 530,000! Not just 50,000!
      expect(offlineOverview.revenueIdr, 530000);
      expect(offlineOverview.transactionCount, 11);
      expect(offlineOverview.pendingCount, 1);
    });

    test('getShiftSummary caches online shift data and merges offline pending transactions without wipe', () async {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 1. Online fetch
      final onlineClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (path == '/analytics/shift-summary') {
            return {
              'data': {
                'today_revenue_idr': 300000,
                'cash_revenue_idr': 200000,
                'qris_revenue_idr': 100000,
                'transaction_count': 6,
              }
            };
          }
          return null;
        },
      );

      final onlineRepo = AnalyticsRepository(onlineClient, localDb);
      final onlineShift = await onlineRepo.getShiftSummary(outletId: 'outlet_pahlawan');
      expect(onlineShift.todayRevenueIdr, 300000);
      expect(onlineShift.cashRevenueIdr, 200000);
      expect(onlineShift.qrisRevenueIdr, 100000);
      expect(onlineShift.transactionCount, 6);
      expect(onlineShift.isOffline, false);

      // 2. Add pending offline cash transaction
      final offlineTx = PosTransactionModel(
        id: 'tx_shift_off_1',
        receiptNo: 'OFF-$todayStr-111',
        outletId: 'outlet_pahlawan',
        outletName: 'Cabang Pahlawan',
        cashierName: 'Siti Kasir',
        subtotalIdr: 40000,
        discountIdr: 0,
        totalIdr: 40000,
        paymentMethod: 'cash',
        paidIdr: 50000,
        changeIdr: 10000,
        status: 'offline_pending',
        createdAt: now,
        items: const [],
        isOfflinePending: true,
        clientRequestId: 'req_shift_off_1',
      );
      await localDb.saveOfflineTransaction(
        transaction: offlineTx,
        clientRequestId: 'req_shift_off_1',
        isSynced: false,
      );

      // 3. Offline fetch: merges with cached shift summary
      final offlineClient = MockApiClient();
      final offlineRepo = AnalyticsRepository(offlineClient, localDb);
      final offlineShift = await offlineRepo.getShiftSummary(outletId: 'outlet_pahlawan');

      expect(offlineShift.isOffline, true);
      expect(offlineShift.todayRevenueIdr, 340000); // 300k + 40k
      expect(offlineShift.cashRevenueIdr, 240000); // 200k + 40k
      expect(offlineShift.qrisRevenueIdr, 100000);
      expect(offlineShift.transactionCount, 7); // 6 + 1
      expect(offlineShift.pendingCount, 1);
    });
  });

  group('Cashier Transaction History Filtering Tests', () {
    final localDb = LocalDatabase.instance;

    setUp(() async {
      await localDb.clearLocalDatabase();
    });

    test('posHistoryProvider respects date filters (from and to)', () async {
      String? requestedFrom;
      String? requestedTo;

      final mockClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (path == '/transactions') {
            requestedFrom = queryParameters?['from'] as String?;
            requestedTo = queryParameters?['to'] as String?;
            return {
              'data': [
                {
                  'id': 'tx_001',
                  'receipt_no': 'REC-001',
                  'outlet_id': 'outlet_pahlawan',
                  'outlet_name': 'Cabang Pahlawan',
                  'cashier_name': 'Siti Kasir',
                  'subtotal_idr': 50000,
                  'discount_idr': 0,
                  'total_idr': 50000,
                  'payment_method': 'cash',
                  'paid_idr': 50000,
                  'change_idr': 0,
                  'status': 'completed',
                  'created_at': DateTime.now().toIso8601String(),
                  'items': [],
                }
              ]
            };
          }
          return null;
        },
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(AuthState.authenticated(mockCashierUser))),
          posRepositoryProvider.overrideWith((ref) => PosRepository(mockClient, localDb)),
        ],
      );

      // Default: Today filter
      final listToday = await container.read(posHistoryProvider.future);
      expect(listToday.length, 1);
      final todayFormatted = resolveDashboardDateRange(DashboardDateFilter.today, null).from;
      expect(requestedFrom, todayFormatted);
      expect(requestedTo, todayFormatted);

      // Change filter to last 7 days
      container.read(selectedDateFilterProvider.notifier).state = DashboardDateFilter.last7Days;
      final range7 = resolveDashboardDateRange(DashboardDateFilter.last7Days, null);

      final list7Days = await container.read(posHistoryProvider.future);
      expect(list7Days.length, 1);
      expect(requestedFrom, range7.from);
      expect(requestedTo, range7.to);

      container.dispose();
    });

    testWidgets('PosHistoryScreen displays quick filter chips and allows cashier to filter', (tester) async {
      final mockClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (path == '/transactions') {
            return {
              'data': [
                {
                  'id': 'tx_001',
                  'receipt_no': 'REC-001',
                  'outlet_id': 'outlet_pahlawan',
                  'outlet_name': 'Cabang Pahlawan',
                  'cashier_name': 'Siti Kasir',
                  'subtotal_idr': 25000,
                  'discount_idr': 0,
                  'total_idr': 25000,
                  'payment_method': 'cash',
                  'paid_idr': 30000,
                  'change_idr': 5000,
                  'status': 'completed',
                  'created_at': DateTime.now().toIso8601String(),
                  'items': [],
                }
              ]
            };
          }
          return null;
        },
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(AuthState.authenticated(mockCashierUser))),
          posRepositoryProvider.overrideWith((ref) => PosRepository(mockClient, localDb)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: PosHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header filter banner is visible for Cashier
      expect(find.textContaining('Cabang Pahlawan'), findsWidgets);

      // Check Quick Filter Chips are visible
      expect(find.text('Hari Ini'), findsOneWidget);
      expect(find.text('Kemarin'), findsOneWidget);
      expect(find.text('7 Hari Terakhir'), findsOneWidget);
      expect(find.text('30 Hari Terakhir'), findsOneWidget);
      expect(find.text('Bulan Ini'), findsOneWidget);
      expect(find.text('Kalender'), findsOneWidget);

      // Tap "7 Hari Terakhir" chip
      await tester.tap(find.text('7 Hari Terakhir'));
      await tester.pumpAndSettle();

      // Verify selectedDateFilterProvider updated to last7Days
      expect(container.read(selectedDateFilterProvider), DashboardDateFilter.last7Days);

      container.dispose();
    });

    testWidgets('PosHistoryScreen displays Detail button and opens detail dialog when tapped', (tester) async {
      final mockClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (path == '/transactions') {
            return {
              'data': [
                {
                  'id': 'tx_detail_001',
                  'receipt_no': 'REC-DETAIL-001',
                  'outlet_id': 'outlet_pahlawan',
                  'outlet_name': 'Cabang Pahlawan',
                  'cashier_name': 'Siti Kasir',
                  'subtotal_idr': 50000,
                  'discount_idr': 5000,
                  'total_idr': 45000,
                  'payment_method': 'cash',
                  'paid_idr': 50000,
                  'change_idr': 5000,
                  'status': 'completed',
                  'created_at': DateTime.now().toIso8601String(),
                  'items': [
                    {
                      'product_id': 'prod_kopi',
                      'product_name_snapshot': 'Kopi Susu Aren',
                      'sku': 'KOP-01',
                      'unit_price_idr': 25000,
                      'quantity': 2,
                    }
                  ],
                }
              ]
            };
          }
          return null;
        },
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(AuthState.authenticated(mockCashierUser))),
          posRepositoryProvider.overrideWith((ref) => PosRepository(mockClient, localDb)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: PosHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure transaction card and Detail button exist
      expect(find.text('REC-DETAIL-001'), findsOneWidget);
      expect(find.text('Detail'), findsOneWidget);

      // Tap Detail button
      await tester.tap(find.text('Detail'));
      await tester.pumpAndSettle();

      // Verify detail dialog is shown
      expect(find.byType(PosReceiptDialog), findsOneWidget);
      expect(find.text('Detail Transaksi'), findsOneWidget);
      expect(find.textContaining('Kopi Susu Aren'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(PosReceiptDialog), findsNothing);

      container.dispose();
    });

    testWidgets('MainShell hides AI companion FAB for cashier role', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(AuthState.authenticated(mockCashierUser))),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MainShell(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Staff/Kasir role must NOT see the AI companion floating button
      expect(find.byTooltip('ARUS AI Companion'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);

      container.dispose();
    });
  });
}
