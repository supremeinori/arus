import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/insights_repository.dart';
import '../domain/insight_models.dart';

final selectedSeverityFilterProvider = StateProvider<String?>((ref) => null);

final insightsListProvider = FutureProvider.autoDispose<List<BusinessInsightModel>>((ref) async {
  final repo = ref.watch(insightsRepositoryProvider);
  final severity = ref.watch(selectedSeverityFilterProvider);
  return repo.getInsights(severity: severity);
});
