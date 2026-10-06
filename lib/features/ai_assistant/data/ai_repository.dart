import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/ai_models.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AiRepository(apiClient);
});

class AiRepository {
  final ApiClient _client;

  AiRepository(this._client);

  Future<AiMessageModel> sendMessage({
    String? conversationId,
    required String message,
    String? outletId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/ai/chat',
      data: {
        'conversation_id': conversationId,
        'message': message,
        'outlet_id': outletId,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>;
    final msgJson = data['message'] as Map<String, dynamic>;
    return AiMessageModel.fromJson(msgJson);
  }
}
