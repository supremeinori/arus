import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../data/reports_repository.dart';
import '../domain/report_models.dart';
import 'reports_provider.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  bool _isVerifying = false;

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final dateFormatter = DateFormat('dd MMM yyyy');

  Future<void> _handleReverify() async {
    setState(() => _isVerifying = true);
    try {
      final repo = ref.read(reportsRepositoryProvider);
      final result = await repo.verifyReport(widget.reportId);

      if (!mounted) return;
      final isValid = result['is_valid'] == true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isValid
                ? 'Hash SHA-256 Valid! Integritas snapshot data 100% otentik.'
                : 'PERINGATAN: Integritas data snapshot gagal diverifikasi!',
          ),
          backgroundColor: isValid ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
      ref.invalidate(reportDetailProvider(widget.reportId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memverifikasi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportDetailProvider(widget.reportId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail & Verifikasi Laporan'),
        actions: [
          IconButton(
            icon: _isVerifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.verified_outlined),
            tooltip: 'Verifikasi Integritas Data',
            onPressed: _isVerifying ? null : _handleReverify,
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Gagal memuat laporan: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(reportDetailProvider(widget.reportId)),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (report) => _buildContent(context, report),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ReportDetailModel report) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Title & metadata card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        report.typeDisplay,
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      dateFormatter.format(report.createdAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  report.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Periode: ${dateFormatter.format(report.periodFrom)} - ${dateFormatter.format(report.periodTo)}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                if (report.createdByName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Dibuat oleh: ${report.createdByName}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Tamper-evident Audit Ledger Card
        _buildVerificationCard(report),

        const SizedBox(height: 20),

        // Data Breakdown
        const Text(
          'Ringkasan Data Snapshot',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        if (report.type == 'sales_summary')
          _buildSalesSummaryPayload(report.payload)
        else if (report.type == 'inventory_status')
          _buildInventoryPayload(report.payload)
        else
          _buildGenericPayload(report.payload),
      ],
    );
  }

  Widget _buildVerificationCard(ReportDetailModel report) {
    final v = report.verification;
    final isValid = v.isValid;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isValid ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.green.shade300 : Colors.red.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                color: isValid ? Colors.green.shade800 : Colors.red.shade800,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isValid
                    ? 'Integritas Snapshot: TERVERIFIKASI ASLI'
                    : 'PERINGATAN: DATA TELAH DI-TAMPER!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isValid ? Colors.green.shade900 : Colors.red.shade900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isValid
                ? 'Kalkulasi payload hash SHA-256 cocok 100% dengan snapshot ledger database.'
                : 'Hash payload yang dihitung tidak sesuai dengan hash yang tersimpan!',
            style: TextStyle(
              fontSize: 12,
              color: isValid ? Colors.green.shade900 : Colors.red.shade900,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SHA-256 Payload Hash:',
                        style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        report.payloadHash,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Salin Hash',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: report.payloadHash));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hash SHA-256 disalin ke clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
          if (v.blockchainAnchored && v.blockIndex != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.link_rounded, size: 16, color: Colors.indigo),
                const SizedBox(width: 6),
                Text(
                  'Tercatat di Blok #${v.blockIndex} Tamper-evident Ledger',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.indigo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSalesSummaryPayload(Map<String, dynamic> payload) {
    final summary = payload['summary'] as Map<String, dynamic>? ?? {};
    final topItems = payload['top_items'] as List<dynamic>? ?? [];

    final rev = summary['total_revenue_idr'] as num? ?? 0;
    final margin = summary['net_margin_idr'] as num? ?? 0;
    final marginPct = summary['margin_percentage'] as num? ?? 0;
    final txCount = summary['transaction_count'] as num? ?? 0;
    final basket = summary['average_basket_size_idr'] as num? ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Omzet',
                currencyFormatter.format(rev),
                Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Estimasi Margin',
                '${currencyFormatter.format(margin)} ($marginPct%)',
                Colors.green.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Transaksi',
                '$txCount struk',
                Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Rata-rata Keranjang',
                currencyFormatter.format(basket),
                Colors.purple.shade700,
              ),
            ),
          ],
        ),
        if (topItems.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Top 5 Produk Terlaris',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: topItems.map((item) {
                final map = item as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  title: Text(map['name'] as String? ?? 'Produk', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${map['quantity']} terjual'),
                  trailing: Text(
                    currencyFormatter.format(map['revenue'] as num? ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInventoryPayload(Map<String, dynamic> payload) {
    final summary = payload['summary'] as Map<String, dynamic>? ?? {};
    final lowStock = payload['low_stock_items'] as List<dynamic>? ?? [];

    final skus = summary['total_skus'] as num? ?? 0;
    final totalQty = summary['total_quantity'] as num? ?? 0;
    final assetVal = summary['total_stock_value_idr'] as num? ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total SKU',
                '$skus produk',
                Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Total Stok Fisik',
                '$totalQty unit',
                Colors.teal.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          'Total Nilai Aset Stok (HPP)',
          currencyFormatter.format(assetVal),
          Colors.indigo.shade700,
        ),
        if (lowStock.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Daftar Stok Menipis',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.red.shade100),
            ),
            child: Column(
              children: lowStock.map((item) {
                final map = item as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  title: Text(map['product_name'] as String? ?? 'Produk', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Outlet: ${map['outlet_name']}'),
                  trailing: Text(
                    'Sisa: ${map['quantity']} (Min: ${map['reorder_level']})',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGenericPayload(Map<String, dynamic> payload) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(payload.toString()),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
