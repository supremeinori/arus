import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../data/reports_repository.dart';
import '../domain/report_models.dart';
import 'report_list_screen.dart' show reportListDateFormatter;
import 'reports_provider.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  bool _isVerifying = false;

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
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: isValid ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
      ref.invalidate(reportDetailProvider(widget.reportId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memverifikasi: $e', maxLines: 3, overflow: TextOverflow.ellipsis),
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
        title: const Text('Detail & Verifikasi Laporan', maxLines: 1, overflow: TextOverflow.ellipsis),
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
      body: AsyncStateView<ReportDetailModel>(
        value: reportAsync,
        onRetry: () => ref.invalidate(reportDetailProvider(widget.reportId)),
        dataBuilder: (report) => _DetailContent(report: report),
      ),
    );
  }
}

/// Isi detail laporan — widget class top-level (aturan E23).
class _DetailContent extends StatelessWidget {
  final ReportDetailModel report;

  const _DetailContent({required this.report});

  @override
  Widget build(BuildContext context) {
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        reportListDateFormatter.format(report.createdAt),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  report.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Periode: ${reportListDateFormatter.format(report.periodFrom)} - ${reportListDateFormatter.format(report.periodTo)}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (report.createdByName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Dibuat oleh: ${report.createdByName}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Tamper-evident Audit Ledger Card
        _VerificationCard(report: report),

        const SizedBox(height: 20),

        // Data Breakdown
        const Text(
          'Ringkasan Data Snapshot',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),

        if (report.type == 'sales_summary')
          _SalesSummaryPayload(payload: report.payload)
        else if (report.type == 'inventory_status')
          _InventoryPayload(payload: report.payload)
        else
          _GenericPayload(payload: report.payload),
      ],
    );
  }
}

/// Kartu verifikasi ledger — widget class top-level (aturan E23).
class _VerificationCard extends StatelessWidget {
  final ReportDetailModel report;

  const _VerificationCard({required this.report});

  @override
  Widget build(BuildContext context) {
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                      const SnackBar(content: Text('Hash SHA-256 disalin ke clipboard', maxLines: 2, overflow: TextOverflow.ellipsis)),
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
                Expanded(
                  child: Text(
                    'Tercatat di Blok #${v.blockIndex} Tamper-evident Ledger',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.indigo,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Payload ringkasan penjualan — widget class top-level (aturan E23,
/// format uang via MoneyFormatter E21).
class _SalesSummaryPayload extends StatelessWidget {
  final Map<String, dynamic> payload;

  const _SalesSummaryPayload({required this.payload});

  @override
  Widget build(BuildContext context) {
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
              child: _PayloadMetricCard(
                title: 'Total Omzet',
                value: MoneyFormatter.format(rev),
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PayloadMetricCard(
                title: 'Estimasi Margin',
                value: '${MoneyFormatter.format(margin)} ($marginPct%)',
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PayloadMetricCard(
                title: 'Total Transaksi',
                value: '$txCount struk',
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PayloadMetricCard(
                title: 'Rata-rata Keranjang',
                value: MoneyFormatter.format(basket),
                color: Colors.purple.shade700,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            // List kecil dan tetap (Top 5) — render inline tanpa scroll bersarang (A4).
            child: Column(
              children: topItems.map((item) {
                final map = item as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  title: Text(map['name'] as String? ?? 'Produk', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${map['quantity']} terjual', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: SizedBox(
                    width: 110,
                    child: Text(
                      MoneyFormatter.format(map['revenue'] as num? ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

/// Payload inventaris — widget class top-level (aturan E23).
class _InventoryPayload extends StatelessWidget {
  final Map<String, dynamic> payload;

  const _InventoryPayload({required this.payload});

  @override
  Widget build(BuildContext context) {
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
              child: _PayloadMetricCard(
                title: 'Total SKU',
                value: '$skus produk',
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PayloadMetricCard(
                title: 'Total Stok Fisik',
                value: '$totalQty unit',
                color: Colors.teal.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PayloadMetricCard(
          title: 'Total Nilai Aset Stok (HPP)',
          value: MoneyFormatter.format(assetVal),
          color: Colors.indigo.shade700,
        ),
        if (lowStock.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Daftar Stok Menipis',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.red.shade100),
            ),
            // List kecil — render inline tanpa scroll bersarang (aturan A4).
            child: Column(
              children: lowStock.map((item) {
                final map = item as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  title: Text(map['product_name'] as String? ?? 'Produk', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Outlet: ${map['outlet_name']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: SizedBox(
                    width: 120,
                    child: Text(
                      'Sisa: ${map['quantity']} (Min: ${map['reorder_level']})',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

/// Payload generik — widget class top-level (aturan E23).
class _GenericPayload extends StatelessWidget {
  final Map<String, dynamic> payload;

  const _GenericPayload({required this.payload});

  @override
  Widget build(BuildContext context) {
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
}

/// Kartu metrik payload — widget class top-level const (aturan E23).
class _PayloadMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _PayloadMetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
