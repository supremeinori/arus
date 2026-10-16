import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../domain/notification_models.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return NotificationsRepository(client);
});

class NotificationsRepository {
  final ApiClient _client;

  NotificationsRepository(this._client);

  Future<NotificationsResponse> getNotifications() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/notifications');
      final data = response.data?['data'] as Map<String, dynamic>;
      return NotificationsResponse.fromJson(data);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Notifikasi tidak dapat dimuat.');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _client.patch<Map<String, dynamic>>('/notifications/$id/read');
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Gagal menandai notifikasi dibaca.');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _client.post<Map<String, dynamic>>('/notifications/read-all');
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Gagal menandai semua notifikasi dibaca.');
    }
  }

  Future<int> evaluateNotifications() async {
    try {
      final response = await _client.post<Map<String, dynamic>>('/notifications/evaluate');
      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      return data['triggered_count'] as int? ?? 0;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Gagal memperbarui evaluasi notifikasi.');
    }
  }
}
