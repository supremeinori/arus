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

  static final List<BusinessInsightModel> _demoInsights = [
    BusinessInsightModel(
      id: 'ins-1',
      ruleCode: 'LOW_STOCK',
      severity: 'critical',
      outletId: 'out-001',
      outletName: 'Kopi Arus - Sudirman (HQ)',
      productId: 'prod-004',
      productName: 'Croissant Butter Original',
      title: 'Stok Kritis: Croissant Butter Original',
      message: 'Sisa stok tinggal 3 pcs di cabang Sudirman, diperkirakan habis sebelum jam 17:00.',
      evidence: {'current_stock': 3, 'reorder_level': 8, 'sales_velocity': 1.8},
      recommendation: 'Lakukan pemindahan stok dari gudang pusat atau order restock darurat.',
      status: 'new',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    BusinessInsightModel(
      id: 'ins-2',
      ruleCode: 'SALES_PEAK',
      severity: 'info',
      outletId: 'out-001',
      outletName: 'Kopi Arus - Sudirman (HQ)',
      productId: 'prod-001',
      productName: 'Kopi Susu Gula Aren',
      title: 'Lonjakan Penjualan Jam Makan Siang',
      message: 'Penjualan Kopi Susu melonjak 45% antara jam 12:00 - 13:30 WIB.',
      evidence: {'hourly_tx_count': 35, 'revenue_window': 770000},
      recommendation: 'Siapkan batch espresso ekstra sebelum jam 11:45 untuk memangkas waktu antrian.',
      status: 'new',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  Future<void> triggerGeneration() async {
    try {
      await _client.post('/insights/generate');
    } catch (_) {}
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
    } catch (_) {
      var filtered = List<BusinessInsightModel>.from(_demoInsights);
      if (severity != null && severity.isNotEmpty) {
        filtered = filtered.where((i) => i.severity == severity).toList();
      }
      if (status != null && status.isNotEmpty) {
        filtered = filtered.where((i) => i.status == status).toList();
      }
      return filtered;
    }
  }

  Future<void> updateStatus(String id, String status) async {
    try {
      await _client.patch(
        '/insights/$id/status',
        data: {'status': status},
      );
    } catch (_) {
      final idx = _demoInsights.indexWhere((i) => i.id == id);
      if (idx >= 0) {
        final cur = _demoInsights[idx];
        _demoInsights[idx] = BusinessInsightModel(
          id: cur.id,
          ruleCode: cur.ruleCode,
          severity: cur.severity,
          outletId: cur.outletId,
          outletName: cur.outletName,
          productId: cur.productId,
          productName: cur.productName,
          title: cur.title,
          message: cur.message,
          evidence: cur.evidence,
          recommendation: cur.recommendation,
          status: status,
          createdAt: cur.createdAt,
        );
      }
    }
  }
}
