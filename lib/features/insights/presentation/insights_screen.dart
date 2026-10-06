import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            content: Text(status == 'acknowledged' ? 'Rekomendasi diterima.' : 'Rekomendasi diabaikan.'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status: $e'), backgroundColor: Colors.red),
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
          const SnackBar(
            content: Text('Rule engine selesai mengevaluasi inventaris & transaksi!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menjalankan rule engine: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsListProvider);
    final selectedSeverity = ref.watch(selectedSeverityFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekomendasi Keputusan (AI/DSS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded),
            tooltip: 'Evaluasi Rule Engine Sekarang',
            onPressed: () => _triggerGeneration(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: () => ref.invalidate(insightsListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: selectedSeverity == null,
                  onSelected: (selected) {
                    if (selected) ref.read(selectedSeverityFilterProvider.notifier).state = null;
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Kritis'),
                  selected: selectedSeverity == 'critical',
                  selectedColor: Colors.red.shade100,
                  onSelected: (selected) {
                    ref.read(selectedSeverityFilterProvider.notifier).state = selected ? 'critical' : null;
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Peringatan'),
                  selected: selectedSeverity == 'warning',
                  selectedColor: Colors.amber.shade100,
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Gagal memuat rekomendasi: $err')),
              data: (insights) {
                if (insights.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_rounded, size: 64, color: Colors.green),
                        SizedBox(height: 16),
                        Text(
                          'Kondisi Bisnis Prima!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tidak ada peringatan kritis atau anomali stok yang terdeteksi.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
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
    Color cardColor;
    Color borderColor;
    IconData icon;

    if (item.isCritical) {
      cardColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
      icon = Icons.warning_rounded;
    } else if (item.isWarning) {
      cardColor = Colors.amber.shade50;
      borderColor = Colors.amber.shade300;
      icon = Icons.info_rounded;
    } else {
      cardColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      icon = Icons.lightbulb_rounded;
    }

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: item.isCritical ? Colors.red.shade700 : Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    item.ruleCode,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.message, style: const TextStyle(fontSize: 13, height: 1.3)),
            const SizedBox(height: 10),

            // Saran / Rekomendasi
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_outlined, size: 16, color: Colors.teal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rekomendasi: ${item.recommendation}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.teal),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _updateStatus(context, ref, item.id, 'dismissed'),
                  child: const Text('Abaikan', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _updateStatus(context, ref, item.id, 'acknowledged'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Tindak Lanjuti', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
