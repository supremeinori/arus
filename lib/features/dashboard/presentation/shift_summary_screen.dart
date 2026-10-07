import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../analytics/presentation/analytics_provider.dart';

class ShiftSummaryScreen extends ConsumerWidget {
  const ShiftSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final shiftAsync = ref.watch(shiftSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan Shift Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(shiftSummaryProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shiftSummaryProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Kasir
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  radius: 24,
                  child: const Icon(Icons.badge_outlined, color: Colors.blue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Kasir',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        'Outlet: ${user?.outlets.isNotEmpty == true ? user!.outlets.first.name : "Utama"}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Shift Card Data
            shiftAsync.when(
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
                child: Text('Gagal memuat ringkasan shift: $err', style: const TextStyle(color: Colors.red)),
              ),
              data: (shift) {
                return Column(
                  children: [
                    _buildShiftMetricTile(
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
                          child: _buildShiftMetricTile(
                            title: 'Uang Tunai (Cash)',
                            value: shift.formattedCashRevenue,
                            icon: Icons.money_rounded,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildShiftMetricTile(
                            title: 'Non-Tunai (QRIS)',
                            value: shift.formattedQrisRevenue,
                            icon: Icons.qr_code_2_rounded,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildShiftMetricTile(
                      title: 'Jumlah Transaksi Berhasil',
                      value: '${shift.transactionCount} Transaksi',
                      icon: Icons.check_circle_outline_rounded,
                      color: Colors.purple,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => context.push('/pos'),
              icon: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Buka Mesin Kasir Sekarang',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pastikan jumlah uang tunai di laci kasir cocok dengan total kas di atas saat serah terima shift.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
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

  Widget _buildShiftMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isPrimary = false,
  }) {
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
          ),
        ],
      ),
    );
  }
}
