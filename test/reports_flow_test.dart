import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/features/reports/domain/report_models.dart';
import 'package:arus/features/reports/presentation/reports_provider.dart';
import 'package:arus/features/reports/presentation/report_list_screen.dart';
import 'package:arus/features/reports/presentation/report_detail_screen.dart';

void main() {
  group('Reports & Tamper-evident Ledger Flow Widget Tests (Milestone 10)', () {
    const ownerUser = UserModel(
      id: 'u-owner-1',
      name: 'Rina Owner',
      email: 'owner@arus.demo',
      role: UserRole.owner,
    );

    final sampleReportItem = ReportSummaryItem(
      id: 'rep-1',
      type: 'sales_summary',
      title: 'Laporan Penjualan Mingguan',
      periodFrom: DateTime(2026, 10, 1),
      periodTo: DateTime(2026, 10, 7),
      outletScope: ['out-1'],
      payloadHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      createdByName: 'Rina Owner',
      createdAt: DateTime(2026, 10, 7),
    );

    final sampleReportDetail = ReportDetailModel(
      id: 'rep-1',
      type: 'sales_summary',
      title: 'Laporan Penjualan Mingguan',
      periodFrom: DateTime(2026, 10, 1),
      periodTo: DateTime(2026, 10, 7),
      outletScope: ['out-1'],
      payload: {
        'summary': {
          'total_revenue_idr': 12500000,
          'net_margin_idr': 4500000,
          'margin_percentage': 36.0,
          'transaction_count': 142,
          'average_basket_size_idr': 88000,
        },
        'top_items': [
          {'name': 'Kopi Susu Senja', 'quantity': 80, 'revenue': 1440000},
        ],
      },
      payloadHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      createdByName: 'Rina Owner',
      createdAt: DateTime(2026, 10, 7),
      verification: const ReportVerification(
        isValid: true,
        storedHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        computedHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        blockchainAnchored: true,
        blockIndex: 42,
      ),
    );

    testWidgets('ReportListScreen menampilkan daftar laporan dan badge hash SHA-256', (tester) async {
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
            reportsListProvider.overrideWith((ref) async => [sampleReportItem]),
          ],
          child: const MaterialApp(
            home: ReportListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Laporan & Audit Snapshot'), findsOneWidget);
      expect(find.text('Laporan Penjualan Mingguan'), findsOneWidget);
      expect(find.text('Ringkasan Penjualan'), findsOneWidget);
      expect(find.textContaining('SHA-256: e3b0c442...'), findsOneWidget);
      expect(find.text('Buat Laporan'), findsOneWidget);
    });

    testWidgets('ReportDetailScreen menampilkan status validasi hash SHA-256, metrik omzet, dan blok ledger', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reportDetailProvider('rep-1').overrideWith((ref) async => sampleReportDetail),
          ],
          child: const MaterialApp(
            home: ReportDetailScreen(reportId: 'rep-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Detail & Verifikasi Laporan'), findsOneWidget);
      expect(find.text('Integritas Snapshot: TERVERIFIKASI ASLI'), findsOneWidget);
      expect(find.textContaining('Tercatat di Blok #42'), findsOneWidget);
      expect(find.text('Total Omzet'), findsOneWidget);
      expect(find.textContaining('12.500.000'), findsOneWidget);
      expect(find.text('Estimasi Margin'), findsOneWidget);
      expect(find.textContaining('4.500.000'), findsOneWidget);
      expect(find.textContaining('36'), findsOneWidget);
      expect(find.text('Kopi Susu Senja'), findsOneWidget);
    });
  });
}
