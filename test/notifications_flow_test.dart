import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/notifications/domain/notification_models.dart';
import 'package:arus/features/notifications/presentation/notifications_provider.dart';
import 'package:arus/features/notifications/presentation/notification_screen.dart';

void main() {
  group('Notifications Flow Widget Tests (Milestone 12)', () {
    final sampleNotifs = NotificationsResponse(
      unreadCount: 1,
      notifications: [
        NotificationModel(
          id: 'notif-1',
          userId: 'u-1',
          type: 'low_stock',
          priority: 'high',
          title: 'Peringatan Stok Menipis: Susu UHT',
          body: 'Sisa stok di Outlet Tebet tersisa 2 liter.',
          readAt: null,
          createdAt: DateTime.now(),
        ),
        NotificationModel(
          id: 'notif-2',
          userId: 'u-1',
          type: 'target_achieved',
          priority: 'normal',
          title: 'Target Omzet Harian Tercapai!',
          body: 'Selamat! Target penjualan harian Rp 2.500.000 telah terlampaui.',
          readAt: DateTime.now().subtract(const Duration(hours: 2)),
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ],
    );

    testWidgets('NotificationScreen menampilkan daftar pesan dan badge belum dibaca', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsListProvider.overrideWith((ref) async => sampleNotifs),
          ],
          child: const MaterialApp(
            home: NotificationScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pusat Notifikasi'), findsOneWidget);
      expect(find.text('1 pesan belum dibaca'), findsOneWidget);
      expect(find.text('Peringatan Stok Menipis: Susu UHT'), findsOneWidget);
      expect(find.text('Target Omzet Harian Tercapai!'), findsOneWidget);
    });

    testWidgets('NotificationScreen filter Belum Dibaca menyaring notifikasi dengan benar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsListProvider.overrideWith((ref) async => sampleNotifs),
          ],
          child: const MaterialApp(
            home: NotificationScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Klik filter chip Belum Dibaca
      final unreadChip = find.text('Belum Dibaca');
      expect(unreadChip, findsOneWidget);
      await tester.tap(unreadChip);
      await tester.pumpAndSettle();

      // Hanya notif-1 (belum dibaca) yang tampil
      expect(find.text('Peringatan Stok Menipis: Susu UHT'), findsOneWidget);
      expect(find.text('Target Omzet Harian Tercapai!'), findsNothing);
    });
  });
}
