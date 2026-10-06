import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/reports_repository.dart';
import '../domain/report_models.dart';

final selectedReportTypeFilterProvider = StateProvider<String?>((ref) => null);

final reportsListProvider = FutureProvider.autoDispose<List<ReportSummaryItem>>((ref) async {
  final repo = ref.watch(reportsRepositoryProvider);
  final typeFilter = ref.watch(selectedReportTypeFilterProvider);
  return repo.getReports(type: typeFilter);
});

final reportDetailProvider = FutureProvider.autoDispose.family<ReportDetailModel, String>((ref, reportId) async {
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getReportById(reportId);
});

class ReportGenerationState {
  final bool isLoading;
  final String? error;
  final ReportDetailModel? generatedReport;

  const ReportGenerationState({
    this.isLoading = false,
    this.error,
    this.generatedReport,
  });
}

class ReportGenerationNotifier extends StateNotifier<ReportGenerationState> {
  final ReportsRepository _repo;
  final Ref _ref;

  ReportGenerationNotifier(this._repo, this._ref) : super(const ReportGenerationState());

  Future<bool> generateReport({
    required String type,
    String? title,
    required String periodFrom,
    required String periodTo,
    List<String>? outletIds,
  }) async {
    state = const ReportGenerationState(isLoading: true);
    try {
      final report = await _repo.generateReport(
        type: type,
        title: title,
        periodFrom: periodFrom,
        periodTo: periodTo,
        outletIds: outletIds,
      );

      state = ReportGenerationState(isLoading: false, generatedReport: report);
      _ref.invalidate(reportsListProvider);
      return true;
    } catch (e) {
      state = ReportGenerationState(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final reportGenerationProvider = StateNotifierProvider<ReportGenerationNotifier, ReportGenerationState>((ref) {
  final repo = ref.watch(reportsRepositoryProvider);
  return ReportGenerationNotifier(repo, ref);
});
