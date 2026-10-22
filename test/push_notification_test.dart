import 'package:arus/core/push/notification_service.dart';
import 'package:arus/features/notifications/domain/notification_models.dart';
import 'package:arus/shared/widgets/test_push_notification_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake layanan notifikasi — method [show] ditimpa agar tidak menyentuh
/// plugin native (tidak tersedia di environment test).
class _FakeNotificationService extends NotificationService {
  _FakeNotificationService({this.result = true});

  final bool result;
  int showCount = 0;
  String? lastTitle;
  String? lastBody;

  @override
  Future<bool> show({
    required String title,
    required String body,
    String? payload,
    bool requestPermissionIfMissing = true,
  }) async {
    showCount++;
    lastTitle = title;
    lastBody = body;
    return result;
  }
}

void main() {
  group('NotificationModel Contract (Prisma is_read)', () {
    test('is_read=true berarti notifikasi sudah dibaca', () {
      final model = NotificationModel.fromJson({
        'id': 'notif-1',
        'user_id': 'u-1',
        'type': 'low_stock',
        'title': 'Stok Menipis',
        'body': 'Susu UHT sisa 2 liter',
        'is_read': true,
        'created_at': '2026-10-20T10:00:00.000Z',
      });

      expect(model.isRead, isTrue);
    });

    test('is_read=false berarti notifikasi belum dibaca', () {
      final model = NotificationModel.fromJson({
        'id': 'notif-2',
        'user_id': 'u-1',
        'type': 'ai_result',
        'title': 'Jawaban AI siap',
        'body': 'Ringkasan omset harian',
        'is_read': false,
        'created_at': '2026-10-20T10:00:00.000Z',
      });

      expect(model.isRead, isFalse);
      expect(model.type, 'ai_result');
    });

    test('Field yang tidak ada tidak membuat crash', () {
      final model = NotificationModel.fromJson({});

      expect(model.id, '');
      expect(model.type, 'system');
      expect(model.isRead, isFalse);
      expect(model.createdAt, isA<DateTime>());
    });
  });

  group('Push Notification Test Button', () {
    testWidgets('Tombol menampilkan notifikasi sistem lewat NotificationService', (tester) async {
      final fake = _FakeNotificationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [notificationServiceProvider.overrideWithValue(fake)],
          child: const MaterialApp(
            home: Scaffold(body: TestPushNotificationButton()),
          ),
        ),
      );

      expect(find.text('Test Push Notification'), findsOneWidget);

      await tester.tap(find.text('Test Push Notification'));
      await tester.pumpAndSettle();

      expect(fake.showCount, 1);
      expect(fake.lastTitle, 'Test Push Notification');
      expect(fake.lastBody, isNotEmpty);
      expect(
        find.textContaining('heads-up di bagian atas layar'),
        findsOneWidget,
      );
    });

    testWidgets('Tombol memberi umpan balik saat notifikasi gagal', (tester) async {
      final fake = _FakeNotificationService(result: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [notificationServiceProvider.overrideWithValue(fake)],
          child: const MaterialApp(
            home: Scaffold(body: TestPushNotificationButton()),
          ),
        ),
      );

      await tester.tap(find.text('Test Push Notification'));
      await tester.pumpAndSettle();

      expect(fake.showCount, 1);
      expect(
        find.textContaining('Aktifkan notifikasi ARUS di pengaturan sistem'),
        findsOneWidget,
      );
    });
  });
}
