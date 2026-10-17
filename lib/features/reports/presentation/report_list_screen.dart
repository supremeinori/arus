import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/report_models.dart';
import 'reports_provider.dart';

/// Formatter tanggal daftar laporan — top-level final (aturan E21:
/// tidak dibuat di dalam build).
final reportListDateFormatter = DateFormat('dd MMM yyyy');

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
        title: const Text('Laporan & Audit Snapshot', maxLines: 1, overflow: TextOverflow.ellipsis),
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
              label: const Text('Buat Laporan', style: TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
              onPressed: () => _showGenerateDialog(context, ref),
            )
          : null,
      body: Column(
        children: [
          _FilterChips(activeFilter: activeFilter),
          Expanded(
            child: AsyncStateView<List<ReportSummaryItem>>(
              value: reportsAsync,
              onRetry: () => ref.invalidate(reportsListProvider),
              dataBuilder: (reports) {
                if (reports.isEmpty) {
                  return _ReportsEmptyState(
                    isPrivileged: isPrivileged,
                    onCreate: () => _showGenerateDialog(context, ref),
                  );
                }
                return _ReportsList(reports: reports);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chips tipe laporan — widget class top-level ConsumerWidget (aturan E23).
class _FilterChips extends ConsumerWidget {
  final String? activeFilter;

  const _FilterChips({required this.activeFilter});

  static const List<Map<String, String?>> _filters = [
    {'label': 'Semua', 'val': null},
    {'label': 'Penjualan', 'val': 'sales_summary'},
    {'label': 'Inventaris', 'val': 'inventory_status'},
    {'label': 'Perbandingan', 'val': 'outlet_comparison'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _filters.map((f) {
          final isSelected = activeFilter == f['val'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label']!, maxLines: 1, overflow: TextOverflow.ellipsis),
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
}

/// Empty state daftar laporan — via EmptyStateView (aturan E24).
class _ReportsEmptyState extends StatelessWidget {
  final bool isPrivileged;
  final VoidCallback onCreate;

  const _ReportsEmptyState({required this.isPrivileged, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      message: 'Belum Ada Laporan Snapshot. Buat laporan berkala berkekuatan audit ledger yang di-hash dengan SHA-256 untuk mendokumentasikan performa bisnis.',
      icon: Icons.assessment_outlined,
      ctaText: isPrivileged ? 'Buat Laporan Sekarang' : null,
      onCtaPressed: isPrivileged ? onCreate : null,
    );
  }
}

/// Daftar laporan — widget class top-level (aturan E23).
class _ReportsList extends StatelessWidget {
  final List<ReportSummaryItem> reports;

  const _ReportsList({required this.reports});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        return _ReportCard(report: reports[index]);
      },
    );
  }
}

/// Kartu satu laporan — widget class top-level (aturan E23).
class _ReportCard extends StatelessWidget {
  final ReportSummaryItem report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      reportListDateFormatter.format(report.createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                report.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                'Periode: ${reportListDateFormatter.format(report.periodFrom)} - ${reportListDateFormatter.format(report.periodTo)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
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
                          Expanded(
                            child: Text(
                              'SHA-256: $hashPrefix',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Colors.teal,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

  void _showGenerateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const GenerateReportDialog(),
    );
  }

class GenerateReportDialog extends ConsumerStatefulWidget {
  const GenerateReportDialog({super.key});

  @override
  ConsumerState<GenerateReportDialog> createState() => _GenerateReportDialogState();
}

/// Default rentang dialog generate — top-level final (aturan E21:
/// DateTime.now tidak dibuat di dalam field/build).
final _defaultReportFrom = DateTime.now().subtract(const Duration(days: 7));
final _defaultReportTo = DateTime.now();

class _GenerateReportDialogState extends ConsumerState<GenerateReportDialog> {
  String _selectedType = 'sales_summary';
  final TextEditingController _titleController = TextEditingController();
  late DateTime _fromDate = _defaultReportFrom;
  late DateTime _toDate = _defaultReportTo;

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
          content: Text('Laporan snapshot berhasil dibuat dan diamankan dengan SHA-256.', maxLines: 3, overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final err = ref.read(reportGenerationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $err', maxLines: 3, overflow: TextOverflow.ellipsis), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportGenerationProvider);

    // Dialog dibatasi + scroll (aturan C15): aman keyboard & layar kecil.
    return AlertDialog(
      title: const Text('Buat Laporan Snapshot Baru', maxLines: 2, overflow: TextOverflow.ellipsis),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tipe Laporan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              AppDropdown<String>(
                value: _selectedType,
                items: const [
                  DropdownMenuItem(value: 'sales_summary', child: Text('Ringkasan Penjualan', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'inventory_status', child: Text('Status Inventaris & Aset', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'outlet_comparison', child: Text('Perbandingan Kinerja Cabang', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 16),
              const Text('Judul Laporan (Opsional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              AppTextField(
                controller: _titleController,
                hintText: 'Misal: Laporan Omzet Mingguan Cabang',
              ),
              const SizedBox(height: 16),
              const Text('Rentang Periode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                        if (!context.mounted) return;
                        if (picked != null) setState(() => _fromDate = picked);
                      },
                      child: Text(reportListDateFormatter.format(_fromDate), style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                        if (!context.mounted) return;
                        if (picked != null) setState(() => _toDate = picked);
                      },
                      child: Text(reportListDateFormatter.format(_toDate), style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
              : const Text('Generate Snapshot', maxLines: 1, overflow: TextOverflow.ellipsis),
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
