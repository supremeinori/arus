import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/insight_models.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InsightsRepository(apiClient);
});

class InsightsRepository {
  final ApiClient _client;

  InsightsRepository(this._client);

  Future<void> triggerGeneration() async {
    await _client.post('/insights/generate');
  }

  Future<List<BusinessInsightModel>> getInsights({
    String? outletId,
    String? severity,
    String? status,
  }) async {
    final query = <String, dynamic>{};
    if (outletId != null && outletId.isNotEmpty) query['outlet_id'] = outletId;
    if (severity != null && severity.isNotEmpty) query['severity'] = severity;
    if (status != null && status.isNotEmpty) query['status'] = status;

    final response = await _client.get<Map<String, dynamic>>(
      '/insights',
      queryParameters: query,
    );
    final list = response.data?['data'] as List<dynamic>? ?? [];
    return list.map((item) => BusinessInsightModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> updateStatus(String id, String status) async {
    await _client.patch(
      '/insights/$id/status',
      data: {'status': status},
    );
  }
}
