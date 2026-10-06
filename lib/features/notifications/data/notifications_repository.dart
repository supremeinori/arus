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

  Future<NotificationsResponse> getNotifications() async {
    final response = await _client.get<Map<String, dynamic>>('/notifications');
    final data = response.data?['data'] as Map<String, dynamic>;
    return NotificationsResponse.fromJson(data);
  }

  Future<void> markAsRead(String id) async {
    await _client.patch<Map<String, dynamic>>('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _client.post<Map<String, dynamic>>('/notifications/read-all');
  }

  Future<int> evaluateNotifications() async {
    final response = await _client.post<Map<String, dynamic>>('/notifications/evaluate');
    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return data['triggered_count'] as int? ?? 0;
  }
}
