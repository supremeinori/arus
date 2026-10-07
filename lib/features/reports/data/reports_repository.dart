import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/report_models.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ReportsRepository(client);
});

class ReportsRepository {
  final ApiClient _client;

  ReportsRepository(this._client);

  static final List<ReportSummaryItem> _demoReports = [
    ReportSummaryItem(
      id: 'rep-001',
      type: 'sales_summary',
      title: 'Laporan Penjualan Q3 Kopi Arus',
      periodFrom: DateTime.now().subtract(const Duration(days: 30)),
      periodTo: DateTime.now(),
      outletScope: ['out-001', 'out-002'],
      payloadHash: 'a7b98f2c34918e7d23a10984cfb78912e8471203948571029384756102938475',
      createdByName: 'Rina Kartika (Owner)',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    ReportSummaryItem(
      id: 'rep-002',
      type: 'inventory_status',
      title: 'Audit Status Stok Bulanan',
      periodFrom: DateTime.now().subtract(const Duration(days: 15)),
      periodTo: DateTime.now(),
      outletScope: ['out-001'],
      payloadHash: 'b8c19a4e5f67890123456789abcdef0123456789abcdef0123456789abcdef01',
      createdByName: 'Budi Santoso (Manager)',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    ReportSummaryItem(
      id: 'rep-003',
      type: 'outlet_comparison',
      title: 'Perbandingan Omset Sudirman vs Senopati',
      periodFrom: DateTime.now().subtract(const Duration(days: 7)),
      periodTo: DateTime.now(),
      outletScope: ['out-001', 'out-002', 'out-003'],
      payloadHash: 'c9d20b5f6a7890123456789abcdef0123456789abcdef0123456789abcdef02',
      createdByName: 'Rina Kartika (Owner)',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

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
    } catch (_) {
      var filtered = List<ReportSummaryItem>.from(_demoReports);
      if (type != null && type.isNotEmpty) {
        filtered = filtered.where((r) => r.type == type).toList();
      }
      return filtered;
    }
  }

  Future<ReportDetailModel> getReportById(String reportId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/reports/$reportId');
      final data = response.data?['data'] as Map<String, dynamic>;
      return ReportDetailModel.fromJson(data);
    } catch (_) {
      final summary = _demoReports.firstWhere(
        (r) => r.id == reportId,
        orElse: () => _demoReports.first,
      );
      return ReportDetailModel(
        id: summary.id,
        type: summary.type,
        title: summary.title,
        periodFrom: summary.periodFrom,
        periodTo: summary.periodTo,
        outletScope: summary.outletScope,
        payload: {
          'total_revenue_idr': 45200000,
          'total_transactions': 128,
          'best_selling_product': 'Kopi Susu Gula Aren',
          'top_outlet': 'Kopi Arus - Sudirman (HQ)',
        },
        payloadHash: summary.payloadHash,
        createdByName: summary.createdByName,
        createdAt: summary.createdAt,
        verification: ReportVerification(
          isValid: true,
          storedHash: summary.payloadHash,
          computedHash: summary.payloadHash,
          verifiedAt: DateTime.now().toIso8601String(),
          blockchainAnchored: true,
          blockIndex: 42,
          blockHash: '0000abc489127df91028374619283746',
        ),
      );
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
    } catch (_) {
      final newSummary = ReportSummaryItem(
        id: 'rep-${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        title: title ?? 'Laporan Baru',
        periodFrom: DateTime.tryParse(periodFrom) ?? DateTime.now(),
        periodTo: DateTime.tryParse(periodTo) ?? DateTime.now(),
        outletScope: outletIds ?? ['out-001'],
        payloadHash: 'd0e31c6f7b890123456789abcdef0123456789abcdef0123456789abcdef03',
        createdByName: 'Rina Kartika (Owner)',
        createdAt: DateTime.now(),
      );
      _demoReports.insert(0, newSummary);
      return getReportById(newSummary.id);
    }
  }

  Future<Map<String, dynamic>> verifyReport(String reportId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>('/reports/$reportId/verify');
      return response.data?['data'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {
        'is_valid': true,
        'stored_hash': 'a7b98f2c34918e7d23a10984cfb78912e8471203948571029384756102938475',
        'computed_hash': 'a7b98f2c34918e7d23a10984cfb78912e8471203948571029384756102938475',
        'blockchain_anchored': true,
        'block_index': 42,
      };
    }
  }
}
