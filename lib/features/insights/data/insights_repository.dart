import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../domain/insight_models.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InsightsRepository(apiClient);
});

class InsightsRepository {
  final ApiClient _client;

  InsightsRepository(this._client);

  Future<void> triggerGeneration() async {
    try {
      await _client.post('/insights/generate');
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Gagal memicu insight baru.');
    }
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

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/insights',
        queryParameters: query,
      );
      final list = response.data?['data'] as List<dynamic>? ?? [];
      return list.map((item) => BusinessInsightModel.fromJson(item as Map<String, dynamic>)).toList();
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Insight bisnis tidak dapat dimuat.');
    }
  }

  Future<void> updateStatus(String id, String status) async {
    try {
      await _client.patch(
        '/insights/$id/status',
        data: {'status': status},
      );
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Gagal memperbarui status insight.');
    }
  }
}
