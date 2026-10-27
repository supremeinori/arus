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
    final isOwner = authState.user?.role == UserRole.owner;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Detail Cabang',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isOwner)
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
        dataBuilder: (outlet) =>
            _DetailContent(outlet: outlet, isOwner: isOwner),
      ),
    );
  }
}

/// Label jam lokal outlet — fungsi top-level murni
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

/// Isi detail outlet — widget class top-level
class _DetailContent extends ConsumerWidget {
  final OutletModel outlet;
  final bool isOwner;

  const _DetailContent({required this.outlet, required this.isOwner});

  void _confirmDeactivation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkCardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.darkCardBorder),
        ),
        title: const Text(
          'Konfirmasi Penonaktifan Cabang',
          style: TextStyle(
            color: AppTheme.textPrimaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menonaktifkan cabang “${outlet.name}”\n\nCabang nonaktif tidak akan dapat menerima pesanan kasir, namun seluruh data historis dan inventaris tetap tersimpan dengan aman (soft delete).',
          style: const TextStyle(
            color: AppTheme.textSecondaryDark,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppTheme.textMutedDark),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final success = await ref
                  .read(outletMutationProvider.notifier)
                  .deactivateOutlet(outlet.id);
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cabang “${outlet.name}” berhasil dinonaktifkan.',
                    ),
                    backgroundColor: AppTheme.jadeTosca,
                  ),
                );
              } else {
                final err = ref.read(outletMutationProvider).error;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal menonaktifkan cabang: $err'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
              }
            },
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
  }

  void _reactivateOutlet(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(outletMutationProvider.notifier)
        .updateOutlet(outlet.id, isActive: true);
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cabang “${outlet.name}” berhasil diaktifkan kembali.',
          ),
          backgroundColor: AppTheme.jadeTosca,
        ),
      );
    } else {
      final err = ref.read(outletMutationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengaktifkan cabang: $err'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localTimeDisplay = outletLocalTimeDisplay(outlet.timezone);
    final userCoord = ref.watch(userCoordinatesProvider);

    final straightMeters = calculateStraightDistanceMeters(
      userCoord.$1,
      userCoord.$2,
      outlet.latitude,
      outlet.longitude,
    );
    final roadMeters = estimateRoadDistanceMeters(straightMeters);
    final hasValidGps = userCoord.$1 != 0.0 && userCoord.$2 != 0.0;

    final VoidCallback toggleAction = outlet.isActive
        ? () => _confirmDeactivation(context, ref)
        : () => _reactivateOutlet(context, ref);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              Card(
                color: AppTheme.darkCardSurface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: AppTheme.darkCardBorder,
                    width: AppTheme.hairline,
                  ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: outlet.isActive
                                  ? AppTheme.successTint
                                  : AppTheme.dangerTint,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: outlet.isActive
                                    ? AppTheme.successTintStrong
                                    : AppTheme.dangerTintStrong,
                              ),
                            ),
                            child: Text(
                              outlet.isActive
                                  ? 'Operasional Aktif'
                                  : 'Nonaktif',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: outlet.isActive
                                    ? AppTheme.successGreenLight
                                    : AppTheme.dangerRedStrong,
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppTheme.textMutedDark,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              outlet.address,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondaryDark,
                              ),
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
                            const Icon(
                              Icons.gps_fixed_rounded,
                              size: 16,
                              color: AppTheme.jadeTosca,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Koordinat GPS: ${outlet.latitude.toStringAsFixed(4)}, ${outlet.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: AppTheme.textMutedDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasValidGps) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCardSurfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.darkCardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.near_me_rounded,
                                    size: 15,
                                    color: AppTheme.jadeTosca,
                                  ),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Jarak dari Lokasi Anda (GPS):',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimaryDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Garis Lurus: ${formatDistance(straightMeters)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondaryDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Est. Jalan: ${formatDistance(roadMeters)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.jadeTosca,
                                      ),
                                      textAlign: TextAlign.end,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      color: AppTheme.warningAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                tileColor: AppTheme.darkCardSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: AppTheme.darkCardBorder,
                    width: AppTheme.hairline,
                  ),
                ),
                leading: const Icon(
                  Icons.warehouse_outlined,
                  color: AppTheme.jadeTosca,
                ),
                title: const Text(
                  'Lihat Inventaris Cabang Ini',
                  style: TextStyle(color: AppTheme.textPrimaryDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const SizedBox(
                  width: 24,
                  child: Icon(
                    Icons.chevron_right,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                onTap: () => context.push('/inventory?outlet_id=${outlet.id}'),
              ),
            ],
          ),
        ),
        if (isOwner)
          _OutletActionBar(isActive: outlet.isActive, onPressed: toggleAction),
      ],
    );
  }
}

/// Tombol aksi owner yang melekat di bawah layar, sejajar dengan bar form cabang.
class _OutletActionBar extends StatelessWidget {
  final bool isActive;
  final VoidCallback onPressed;

  const _OutletActionBar({required this.isActive, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          border: Border(top: BorderSide(color: AppTheme.darkCardBorder)),
        ),
        child: isActive
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.dangerRedDeep,
                  // Tema sekarang memberi latar tosca pada tombol sekunder.
                  // Tombol ini merah, jadi latarnya diarahkan ke rose supaya
                  // tidak merah di atas latar hijau kebiruan.
                  backgroundColor: AppTheme.dangerSurfacePale,
                  side: const BorderSide(color: AppTheme.dangerRed, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                label: const Text(
                  'Nonaktifkan Cabang Ini',
                  style: TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: onPressed,
              )
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.jadeTosca,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text(
                  'Aktifkan Kembali Cabang Ini',
                  style: TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: onPressed,
              ),
      ),
    );
  }
}

/// Tile metrik outlet — widget class top-level const
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
