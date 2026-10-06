import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../data/insights_repository.dart';
import '../domain/insight_models.dart';
import 'insights_provider.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  void _updateStatus(BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      await ref.read(insightsRepositoryProvider).updateStatus(id, status);
      ref.invalidate(insightsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'acknowledged' ? 'Rekomendasi diterima.' : 'Rekomendasi diabaikan.',
              style: GoogleFonts.lexend(fontSize: 13),
            ),
            backgroundColor: AppTheme.accentBlack,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status: $e', style: GoogleFonts.lexend(fontSize: 13)),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _triggerGeneration(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(insightsRepositoryProvider).triggerGeneration();
      ref.invalidate(insightsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rule engine selesai mengevaluasi inventaris & transaksi!',
              style: GoogleFonts.lexend(fontSize: 13),
            ),
            backgroundColor: AppTheme.primaryBlue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menjalankan rule engine: $e', style: GoogleFonts.lexend(fontSize: 13)),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsListProvider);
    final selectedSeverity = ref.watch(selectedSeverityFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Rekomendasi Keputusan (AI/DSS)',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded, color: AppTheme.primaryBlue),
            tooltip: 'Evaluasi Rule Engine Sekarang',
            onPressed: () => _triggerGeneration(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentBlack),
            tooltip: 'Segarkan',
            onPressed: () => ref.invalidate(insightsListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(
                    'Semua',
                    style: GoogleFonts.lexend(
                      fontSize: 12.5,
                      fontWeight: selectedSeverity == null ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: selectedSeverity == null,
                  selectedColor: AppTheme.primaryBlue,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  labelStyle: TextStyle(color: selectedSeverity == null ? Colors.white : AppTheme.accentBlack),
                  onSelected: (selected) {
                    if (selected) ref.read(selectedSeverityFilterProvider.notifier).state = null;
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'Kritis',
                    style: GoogleFonts.lexend(
                      fontSize: 12.5,
                      fontWeight: selectedSeverity == 'critical' ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: selectedSeverity == 'critical',
                  selectedColor: AppTheme.dangerRed,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  labelStyle: TextStyle(color: selectedSeverity == 'critical' ? Colors.white : AppTheme.accentBlack),
                  onSelected: (selected) {
                    ref.read(selectedSeverityFilterProvider.notifier).state = selected ? 'critical' : null;
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'Peringatan',
                    style: GoogleFonts.lexend(
                      fontSize: 12.5,
                      fontWeight: selectedSeverity == 'warning' ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: selectedSeverity == 'warning',
                  selectedColor: AppTheme.warningAmber,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  labelStyle: TextStyle(color: selectedSeverity == 'warning' ? Colors.white : AppTheme.accentBlack),
                  onSelected: (selected) {
                    ref.read(selectedSeverityFilterProvider.notifier).state = selected ? 'warning' : null;
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List Insights
          Expanded(
            child: insightsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              ),
              error: (err, _) => Center(
                child: Text('Gagal memuat rekomendasi: $err', style: GoogleFonts.lexend()),
              ),
              data: (insights) {
                if (insights.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_rounded, size: 56, color: AppTheme.primaryBlue),
                        const SizedBox(height: 16),
                        Text(
                          'Kondisi Bisnis Prima!',
                          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.accentBlack),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tidak ada peringatan kritis atau anomali stok yang terdeteksi.',
                          style: GoogleFonts.lexend(color: const Color(0xFF64748B), fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.primaryBlue,
                  onRefresh: () async => ref.invalidate(insightsListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: insights.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = insights[index];
                      return _buildInsightCard(context, ref, item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, WidgetRef ref, BusinessInsightModel item) {
    final isCritical = item.isCritical;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical ? const Color(0xFFFCA5A5) : AppTheme.borderOutline,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCritical ? Icons.warning_rounded : Icons.info_outline_rounded,
                size: 20,
                color: isCritical ? AppTheme.dangerRed : AppTheme.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: GoogleFonts.lexend(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: AppTheme.accentBlack,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isCritical ? const Color(0xFFFEE2E2) : AppTheme.lightBlueBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFBFDBFE),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  item.ruleCode,
                  style: GoogleFonts.lexend(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isCritical ? AppTheme.dangerRed : AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.message,
            style: GoogleFonts.lexend(fontSize: 12.5, color: const Color(0xFF334155), height: 1.35),
          ),
          const SizedBox(height: 10),

          // Saran / Rekomendasi
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.primaryBlue, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_outlined, size: 16, color: AppTheme.primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rekomendasi: ${item.recommendation}',
                    style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _updateStatus(context, ref, item.id, 'dismissed'),
                child: Text(
                  'Abaikan',
                  style: GoogleFonts.lexend(color: const Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _updateStatus(context, ref, item.id, 'acknowledged'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  minimumSize: const Size(110, 36),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: const BorderSide(color: AppTheme.borderOutline, width: 1.2),
                  ),
                ),
                child: Text(
                  'Tindak Lanjuti',
                  style: GoogleFonts.lexend(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
