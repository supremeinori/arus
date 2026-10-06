import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class HealthStatus {
  final String status;
  final String db;
  final String time;
  final String version;

  const HealthStatus({
    required this.status,
    required this.db,
    required this.time,
    required this.version,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String? ?? 'unknown',
      db: json['db'] as String? ?? 'unknown',
      time: json['time'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
    );
  }
}

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HealthRepository(apiClient);
});

class HealthRepository {
  final ApiClient _apiClient;

  HealthRepository(this._apiClient);

  Future<HealthStatus> checkHealth() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/health');
    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return HealthStatus.fromJson(data);
  }
}
