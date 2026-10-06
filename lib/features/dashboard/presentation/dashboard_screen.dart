import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../sensors/presentation/sensor_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<DateTime?>(shakeEventProvider, (prev, next) {
      if (next != null) {
        ref.invalidate(analyticsOverviewProvider);
        ref.invalidate(salesTrendProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📳 Guncangan terdeteksi! Memperbarui data KPI dashboard...'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final user = ref.watch(authProvider).user;
    final isOwnerOrManager = user?.role == UserRole.owner || user?.role == UserRole.manager;
    final overviewAsync = ref.watch(analyticsOverviewProvider);
    final trendAsync = ref.watch(salesTrendProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: () {
              ref.invalidate(analyticsOverviewProvider);
              ref.invalidate(salesTrendProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsOverviewProvider);
          ref.invalidate(salesTrendProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: Text(
                    (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${user?.name ?? ""}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Role: ${user?.role.toDisplayString() ?? ""}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // KPI Overview Cards
            overviewAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Gagal memuat KPI: $err', style: const TextStyle(color: Colors.red)),
              ),
              data: (kpi) => _buildKpiGrid(kpi, isOwnerOrManager),
            ),

            const SizedBox(height: 24),

            // Tren Penjualan 7 Hari
            const Text(
              'Tren Penjualan 7 Hari Terakhir',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            trendAsync.when(
              loading: () => const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text('Gagal memuat tren: $err'),
              data: (trendPoints) => _buildTrendBars(trendPoints),
            ),

            const SizedBox(height: 24),

            // Banner Wawasan Bisnis Cepat
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade800, Colors.teal.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 36),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Decision-Support Ready',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'AI Assistant dan Engine Rekomendasi siap menganalisis potensi keuntungan cabang.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(AnalyticsOverviewModel kpi, bool isOwnerOrManager) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Total Omset',
                value: kpi.formattedRevenue,
                icon: Icons.monetization_on_outlined,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Total Transaksi',
                value: '${kpi.transactionCount}',
                icon: Icons.receipt_long_outlined,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Rata-rata Keranjang',
                value: kpi.formattedAvgBasket,
                icon: Icons.shopping_bag_outlined,
                color: Colors.purple,
              ),
            ),
            if (isOwnerOrManager && kpi.grossProfitIdr != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Estimasi Margin (${kpi.grossMarginPct ?? 0}%)',
                  value: kpi.formattedGrossProfit,
                  icon: Icons.trending_up_rounded,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBars(List<SalesTrendPoint> points) {
    if (points.isEmpty) {
      return const Center(child: Text('Belum ada data tren.', style: TextStyle(color: Colors.grey)));
    }

    final maxRevenue = points.fold<int>(0, (max, p) => p.revenueIdr > max ? p.revenueIdr : max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map<Widget>((p) {
          final ratio = maxRevenue > 0 ? (p.revenueIdr / maxRevenue).clamp(0.05, 1.0).toDouble() : 0.05;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 90.0 * ratio,
                decoration: BoxDecoration(
                  color: Colors.teal.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                p.displayDay,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
