import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'analytics_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(analyticsOverviewProvider);
    final peakHoursAsync = ref.watch(peakHoursProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analitik Performa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(analyticsOverviewProvider);
              ref.invalidate(peakHoursProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsOverviewProvider);
          ref.invalidate(peakHoursProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Overview Box
            overviewAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (kpi) => Card(
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
                      const Text('Total Pendapatan Terakumulasi', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        kpi.formattedRevenue,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.teal),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat('Transaksi', '${kpi.transactionCount} kali'),
                          _buildMiniStat('Rata-rata Order', kpi.formattedAvgBasket),
                          if (kpi.grossMarginPct != null)
                            _buildMiniStat('Margin Kotor', '${kpi.grossMarginPct}%'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Distribusi Jam Ramai (Peak Hours)
            const Text(
              'Distribusi Jam Ramai Transaksi (Peak Hours)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Gunakan data ini untuk penyesuaian jadwal jaga kasir & persiapan bahan baku.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            peakHoursAsync.when(
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e'),
              data: (hours) {
                // Cari jam tersibuk
                final busiestHours = hours.where((h) => h.transactionCount > 0).toList()
                  ..sort((a, b) => b.transactionCount.compareTo(a.transactionCount));

                if (busiestHours.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Belum ada data transaksi yang tercatat.'),
                    ),
                  );
                }

                return Column(
                  children: busiestHours.take(6).map((h) {
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: Text(
                            h.label.split(':')[0],
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                          ),
                        ),
                        title: Text('Pukul ${h.label}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${h.transactionCount} transaksi selesai'),
                        trailing: Text(
                          currencyFormatter.format(h.totalRevenueIdr),
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.teal),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
