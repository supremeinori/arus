import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/report_models.dart';
import 'reports_provider.dart';

class ReportListScreen extends ConsumerWidget {
  const ReportListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsListProvider);
    final activeFilter = ref.watch(selectedReportTypeFilterProvider);
    final authState = ref.watch(authProvider);
    final isPrivileged = authState.user?.role == UserRole.owner ||
        authState.user?.role == UserRole.manager;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan & Audit Snapshot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Laporan',
            onPressed: () => ref.invalidate(reportsListProvider),
          ),
        ],
      ),
      floatingActionButton: isPrivileged
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryBlue,
              icon: const Icon(Icons.addchart_rounded, color: Colors.white),
              label: const Text('Buat Laporan', style: TextStyle(color: Colors.white)),
              onPressed: () => _showGenerateDialog(context, ref),
            )
          : null,
      body: Column(
        children: [
          _buildFilterChips(context, ref, activeFilter),
          Expanded(
            child: reportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Gagal memuat daftar laporan: $err', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(reportsListProvider),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (reports) {
                if (reports.isEmpty) {
                  return _buildEmptyState(context, isPrivileged, ref);
                }
                return _buildReportsList(context, reports);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, WidgetRef ref, String? activeFilter) {
    final List<Map<String, String?>> filters = [
      {'label': 'Semua', 'val': null},
      {'label': 'Penjualan', 'val': 'sales_summary'},
      {'label': 'Inventaris', 'val': 'inventory_status'},
      {'label': 'Perbandingan', 'val': 'outlet_comparison'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = activeFilter == f['val'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (_) {
                ref.read(selectedReportTypeFilterProvider.notifier).state = f['val'];
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isPrivileged, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assessment_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Laporan Snapshot',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat laporan berkala berkekuatan audit ledger yang di-hash dengan SHA-256 untuk mendokumentasikan performa bisnis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            if (isPrivileged) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.addchart_rounded),
                label: const Text('Buat Laporan Sekarang'),
                onPressed: () => _showGenerateDialog(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList(BuildContext context, List<ReportSummaryItem> reports) {
    final dateFormatter = DateFormat('dd MMM yyyy');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        final hashPrefix = report.payloadHash.length >= 10
            ? '${report.payloadHash.substring(0, 8)}...'
            : report.payloadHash;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/reports/${report.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          report.typeDisplay,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      Text(
                        dateFormatter.format(report.createdAt),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    report.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Periode: ${dateFormatter.format(report.periodFrom)} - ${dateFormatter.format(report.periodTo)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 12, color: Colors.teal),
                            const SizedBox(width: 4),
                            Text(
                              'SHA-256: $hashPrefix',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Colors.teal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGenerateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const GenerateReportDialog(),
    );
  }
}

class GenerateReportDialog extends ConsumerStatefulWidget {
  const GenerateReportDialog({super.key});

  @override
  ConsumerState<GenerateReportDialog> createState() => _GenerateReportDialogState();
}

class _GenerateReportDialogState extends ConsumerState<GenerateReportDialog> {
  String _selectedType = 'sales_summary';
  final TextEditingController _titleController = TextEditingController();
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final fromStr = _fromDate.toIso8601String().slice(0, 10);
    final toStr = _toDate.toIso8601String().slice(0, 10);

    final success = await ref.read(reportGenerationProvider.notifier).generateReport(
      type: _selectedType,
      title: title.isNotEmpty ? title : null,
      periodFrom: fromStr,
      periodTo: toStr,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan snapshot berhasil dibuat dan diamankan dengan SHA-256.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final err = ref.read(reportGenerationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $err'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportGenerationProvider);
    final dateFormatter = DateFormat('dd MMM yyyy');

    return AlertDialog(
      title: const Text('Buat Laporan Snapshot Baru'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipe Laporan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              items: const [
                DropdownMenuItem(value: 'sales_summary', child: Text('Ringkasan Penjualan')),
                DropdownMenuItem(value: 'inventory_status', child: Text('Status Inventaris & Aset')),
                DropdownMenuItem(value: 'outlet_comparison', child: Text('Perbandingan Kinerja Cabang')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Judul Laporan (Opsional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Misal: Laporan Omzet Mingguan Cabang',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Rentang Periode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _fromDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _fromDate = picked);
                    },
                    child: Text(dateFormatter.format(_fromDate), style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('s/d'),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _toDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _toDate = picked);
                    },
                    child: Text(dateFormatter.format(_toDate), style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: state.isLoading ? null : _handleSubmit,
          child: state.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Generate Snapshot'),
        ),
      ],
    );
  }
}

extension StringSliceExtension on String {
  String slice(int start, [int? end]) {
    final e = end ?? length;
    return substring(start, e > length ? length : e);
  }
}
