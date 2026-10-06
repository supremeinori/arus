import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/health_repository.dart';

final healthCheckProvider = FutureProvider.autoDispose<HealthStatus>((ref) async {
  final repo = ref.watch(healthRepositoryProvider);
  return repo.checkHealth();
});
