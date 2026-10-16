import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../domain/report_models.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ReportsRepository(client);
});

class ReportsRepository {
  final ApiClient _client;

  ReportsRepository(this._client);

  Future<List<ReportSummaryItem>> getReports({String? outletId, String? type}) async {
    final query = <String, dynamic>{};
    if (outletId != null) query['outlet_id'] = outletId;
    if (type != null) query['type'] = type;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/reports',
        queryParameters: query,
      );

      final rawList = response.data?['data'] as List<dynamic>? ?? [];
      return rawList
          .map((item) => ReportSummaryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Data laporan tidak dapat dimuat.');
    }
  }

  Future<ReportDetailModel> getReportById(String reportId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/reports/$reportId');
      final data = response.data?['data'] as Map<String, dynamic>;
      return ReportDetailModel.fromJson(data);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Detail laporan tidak dapat dimuat.');
    }
  }

  Future<ReportDetailModel> generateReport({
    required String type,
    String? title,
    required String periodFrom,
    required String periodTo,
    List<String>? outletIds,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/reports',
        data: {
          'type': type,
          if (title != null && title.isNotEmpty) 'title': title,
          'period_from': periodFrom,
          'period_to': periodTo,
          if (outletIds != null && outletIds.isNotEmpty) 'outlet_ids': outletIds,
        },
      );

      final data = response.data?['data'] as Map<String, dynamic>;
      return ReportDetailModel.fromJson(data);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Gagal men-generate laporan.');
    }
  }

  Future<Map<String, dynamic>> verifyReport(String reportId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>('/reports/$reportId/verify');
      return response.data?['data'] as Map<String, dynamic>? ?? {};
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Koneksi ke web service terputus. Gagal memverifikasi keaslian laporan.');
    }
  }
}
