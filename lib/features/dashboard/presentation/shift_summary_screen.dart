import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../analytics/domain/analytics_models.dart';

class ShiftSummaryScreen extends ConsumerWidget {
  const ShiftSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final shiftAsync = ref.watch(shiftSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan Shift Saya', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(shiftSummaryProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shiftSummaryProvider),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
            // Header Kasir
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  radius: 24,
                  child: const Icon(Icons.badge_outlined, color: Colors.teal),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Kasir',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Outlet: ${user?.outlets.isNotEmpty == true ? user!.outlets.first.name : "Utama"}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Shift Card Data
            AsyncStateView<ShiftSummaryModel>(
              value: shiftAsync,
              onRetry: () => ref.invalidate(shiftSummaryProvider),
              dataBuilder: (shift) => _ShiftMetrics(shift: shift),
            ),

            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => context.push('/pos'),
              icon: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Buka Mesin Kasir Sekarang',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryToska,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.teal),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pastikan jumlah uang tunai di laci kasir cocok dengan total kas di atas saat serah terima shift.',
                      style: TextStyle(fontSize: 12, color: Colors.teal),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Metrik shift — widget class top-level (aturan E23).
class _ShiftMetrics extends StatelessWidget {
  final ShiftSummaryModel shift;

  const _ShiftMetrics({required this.shift});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ShiftMetricTile(
          title: 'Total Penjualan Shift Hari Ini',
          value: shift.formattedTodayRevenue,
          icon: Icons.payments_rounded,
          color: Colors.teal,
          isPrimary: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ShiftMetricTile(
                title: 'Uang Tunai (Cash)',
                value: shift.formattedCashRevenue,
                icon: Icons.money_rounded,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ShiftMetricTile(
                title: 'Non-Tunai (QRIS)',
                value: shift.formattedQrisRevenue,
                icon: Icons.qr_code_2_rounded,
                color: Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ShiftMetricTile(
          title: 'Jumlah Transaksi Berhasil',
          value: '${shift.transactionCount} Transaksi',
          icon: Icons.check_circle_outline_rounded,
          color: Colors.purple,
        ),
      ],
    );
  }
}

/// Tile metrik shift — widget class top-level const (aturan E23).
class _ShiftMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isPrimary;

  const _ShiftMetricTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isPrimary ? 18 : 14),
      decoration: BoxDecoration(
        color: isPrimary ? Colors.teal.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPrimary ? Colors.teal.shade300 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isPrimary ? 13 : 11,
                    color: Colors.grey.shade700,
                    fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isPrimary ? 22 : 16,
              fontWeight: FontWeight.bold,
              color: isPrimary ? Colors.teal.shade900 : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
