import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';

final selectedOutletFilterProvider = StateProvider<String?>((ref) => null);

final analyticsOverviewProvider = FutureProvider.autoDispose<AnalyticsOverviewModel>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = ref.watch(selectedOutletFilterProvider);
  return repo.getOverview(outletId: outletId);
});

final salesTrendProvider = FutureProvider.autoDispose<List<SalesTrendPoint>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = ref.watch(selectedOutletFilterProvider);
  return repo.getSalesTrend(outletId: outletId, days: 7);
});

final peakHoursProvider = FutureProvider.autoDispose<List<PeakHourPoint>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = ref.watch(selectedOutletFilterProvider);
  return repo.getPeakHours(outletId: outletId);
});

final shiftSummaryProvider = FutureProvider.autoDispose<ShiftSummaryModel>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = ref.watch(selectedOutletFilterProvider);
  return repo.getShiftSummary(outletId: outletId);
});
