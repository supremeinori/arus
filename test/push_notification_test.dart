import 'package:arus/features/notifications/domain/notification_models.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
