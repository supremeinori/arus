import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/notification_models.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return NotificationsRepository(client);
});

class NotificationsRepository {
  final ApiClient _client;

  NotificationsRepository(this._client);

  static final List<NotificationModel> _demoNotifications = [
    NotificationModel(
      id: 'notif-1',
      userId: 'u-owner-001',
      type: 'low_stock',
      priority: 'high',
      title: 'Peringatan Stok Menipis',
      body: 'Stok Croissant Butter Original di Sudirman tersisa 3 pcs (di bawah batas minimum 8 pcs).',
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    NotificationModel(
      id: 'notif-2',
      userId: 'u-owner-001',
      type: 'sales_change',
      priority: 'normal',
      title: 'Lonjakan Penjualan Terdeteksi',
      body: 'Omset Kopi Susu Gula Aren naik 35% pada jam istirahat siang hari ini.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NotificationModel(
      id: 'notif-3',
      userId: 'u-owner-001',
      type: 'system',
      priority: 'low',
      title: 'Verifikasi Ledger Integritas Selesai',
      body: 'Snapshot audit otomatis berhasil dibuat dengan SHA-256 dan ditautkan ke blockchain ledger.',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  Future<NotificationsResponse> getNotifications() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/notifications');
      final data = response.data?['data'] as Map<String, dynamic>;
      return NotificationsResponse.fromJson(data);
    } catch (_) {
      final unread = _demoNotifications.where((n) => !n.isRead).length;
      return NotificationsResponse(
        unreadCount: unread,
        notifications: List.from(_demoNotifications),
      );
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _client.patch<Map<String, dynamic>>('/notifications/$id/read');
    } catch (_) {
      final idx = _demoNotifications.indexWhere((n) => n.id == id);
      if (idx >= 0) {
        final cur = _demoNotifications[idx];
        _demoNotifications[idx] = NotificationModel(
          id: cur.id,
          userId: cur.userId,
          type: cur.type,
          priority: cur.priority,
          title: cur.title,
          body: cur.body,
          payload: cur.payload,
          readAt: DateTime.now(),
          createdAt: cur.createdAt,
        );
      }
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _client.post<Map<String, dynamic>>('/notifications/read-all');
    } catch (_) {
      for (var i = 0; i < _demoNotifications.length; i++) {
        final cur = _demoNotifications[i];
        _demoNotifications[i] = NotificationModel(
          id: cur.id,
          userId: cur.userId,
          type: cur.type,
          priority: cur.priority,
          title: cur.title,
          body: cur.body,
          payload: cur.payload,
          readAt: DateTime.now(),
          createdAt: cur.createdAt,
        );
      }
    }
  }

  Future<int> evaluateNotifications() async {
    try {
      final response = await _client.post<Map<String, dynamic>>('/notifications/evaluate');
      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      return data['triggered_count'] as int? ?? 0;
    } catch (_) {
      return 1;
    }
  }
}
