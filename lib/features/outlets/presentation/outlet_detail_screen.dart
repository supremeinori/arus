import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../domain/outlet_models.dart';
import 'outlets_provider.dart';

class OutletDetailScreen extends ConsumerWidget {
  final String outletId;

  const OutletDetailScreen({super.key, required this.outletId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outletAsync = ref.watch(outletDetailProvider(outletId));
    final authState = ref.watch(authProvider);
    final isPrivileged = authState.user?.role == UserRole.owner ||
        authState.user?.role == UserRole.manager;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Cabang', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (isPrivileged)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Cabang',
              onPressed: () => context.push('/outlets/$outletId/edit'),
            ),
        ],
      ),
      body: AsyncStateView<OutletModel>(
        value: outletAsync,
        onRetry: () => ref.invalidate(outletDetailProvider(outletId)),
        dataBuilder: (outlet) => _DetailContent(outlet: outlet),
      ),
    );
  }

}

/// Label jam lokal outlet — fungsi top-level murni (aturan E21:
/// DateTime.now tidak lagi di dalam build).
String outletLocalTimeDisplay(String timezone) {
  final now = DateTime.now().toUtc();
  if (timezone.contains('Jakarta')) {
    final wib = now.add(const Duration(hours: 7));
    return '${DateFormat('HH:mm').format(wib)} WIB';
  } else if (timezone.contains('Makassar')) {
    final wita = now.add(const Duration(hours: 8));
    return '${DateFormat('HH:mm').format(wita)} WITA';
  } else if (timezone.contains('London')) {
    final bst = now.add(const Duration(hours: 1));
    return '${DateFormat('HH:mm').format(bst)} BST (London)';
  }
  return timezone;
}

/// Isi detail outlet — widget class top-level (aturan E23).
class _DetailContent extends StatelessWidget {
  final OutletModel outlet;

  const _DetailContent({required this.outlet});

  @override
  Widget build(BuildContext context) {
    final localTimeDisplay = outletLocalTimeDisplay(outlet.timezone);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: AppTheme.darkCardSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
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
                        color: outlet.isActive ? const Color(0x2210B981) : const Color(0x22EF4444),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: outlet.isActive ? const Color(0x3310B981) : const Color(0x33EF4444)),
                      ),
                      child: Text(
                        outlet.isActive ? 'Operasional Aktif' : 'Nonaktif',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: outlet.isActive ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        localTimeDisplay,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.jadeTosca,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  outlet.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.textMutedDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        outlet.address,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardSurfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkCardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed_rounded, size: 16, color: AppTheme.jadeTosca),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Koordinat GPS: ${outlet.latitude.toStringAsFixed(4)}, ${outlet.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.textMutedDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Total Stok SKU',
                value: '${outlet.inventoryCount} Produk',
                icon: Icons.inventory_2_outlined,
                color: AppTheme.jadeTosca,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Staf Bertugas',
                value: '${outlet.assignedUsersCount} Orang',
                icon: Icons.badge_outlined,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          tileColor: AppTheme.darkCardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
          ),
          leading: const Icon(Icons.warehouse_outlined, color: AppTheme.jadeTosca),
          title: const Text('Lihat Inventaris Cabang Ini', style: TextStyle(color: AppTheme.textPrimaryDark), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const SizedBox(width: 24, child: Icon(Icons.chevron_right, color: AppTheme.textMutedDark)),
          onTap: () => context.push('/inventory?outlet_id=${outlet.id}'),
        ),
      ],
    );
  }

}

/// Tile metrik outlet — widget class top-level const (aturan E23).
class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMutedDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
