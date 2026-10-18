import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/outlet_models.dart';
import 'outlets_provider.dart';

class OutletListScreen extends ConsumerStatefulWidget {
  const OutletListScreen({super.key});

  @override
  ConsumerState<OutletListScreen> createState() => _OutletListScreenState();
}

class _OutletListScreenState extends ConsumerState<OutletListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outletsAsync = ref.watch(outletsListProvider);
    final performanceAsync = ref.watch(outletsPerformanceProvider);
    final nearestAsync = ref.watch(nearestOutletProvider);
    final authState = ref.watch(authProvider);
    final isOwner = authState.user?.role == UserRole.owner;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Cabang & LBS', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data Cabang',
            onPressed: () {
              ref.invalidate(outletsListProvider);
              ref.invalidate(outletsPerformanceProvider);
              ref.invalidate(nearestOutletProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.storefront_rounded), text: 'Daftar Cabang'),
            Tab(icon: Icon(Icons.near_me_rounded), text: 'Peta & LBS Terdekat'),
          ],
        ),
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.jadeTosca,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Tambah Cabang', maxLines: 1, overflow: TextOverflow.ellipsis),
              onPressed: () => context.push('/outlets/new'),
            )
          : null,
      // Tiap tab punya scroll sendiri, bukan scroll induk (aturan A13).
      body: TabBarView(
        controller: _tabController,
        children: [
          _OutletsTab(outletsAsync: outletsAsync, performanceAsync: performanceAsync),
          _LbsTab(nearestAsync: nearestAsync),
        ],
      ),
    );
  }
}

/// Tab daftar cabang — widget class top-level (aturan E23, E24).
class _OutletsTab extends StatelessWidget {
  final AsyncValue<List<OutletModel>> outletsAsync;
  final AsyncValue<List<OutletPerformanceModel>> performanceAsync;

  const _OutletsTab({required this.outletsAsync, required this.performanceAsync});

  @override
  Widget build(BuildContext context) {
    return AsyncStateView<List<OutletModel>>(
      value: outletsAsync,
      onRetry: null,
      dataBuilder: (outlets) {
        if (outlets.isEmpty) {
          return const EmptyStateView(
            message: 'Belum ada cabang terdaftar.',
            icon: Icons.storefront_outlined,
          );
        }

        final perfMap = {
          for (final p in performanceAsync.value ?? <OutletPerformanceModel>[])
            p.outletId: p
        };

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: outlets.length,
          itemBuilder: (context, index) {
            final outlet = outlets[index];
            final perf = perfMap[outlet.id];
            return _OutletCard(outlet: outlet, perf: perf);
          },
        );
      },
    );
  }
}

/// Kartu satu outlet — widget class top-level const (aturan E23).
class _OutletCard extends StatelessWidget {
  final OutletModel outlet;
  final OutletPerformanceModel? perf;

  const _OutletCard({required this.outlet, this.perf});

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppTheme.jadeTosca;
    String statusText = 'Optimal';
    if (perf?.performanceStatus == 'critical') {
      statusColor = AppTheme.dangerRed;
      statusText = 'Kritis';
    } else if (perf?.performanceStatus == 'warning') {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'Perhatian';
    }

    return Card(
      color: AppTheme.darkCardSurface,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/outlets/${outlet.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      outlet.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 4, backgroundColor: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                outlet.address,
                style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textMutedDark),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      outlet.timezone,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMutedDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${outlet.inventoryCount} SKU Produk',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.jadeTosca,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMutedDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Label jam lokal untuk LBS — fungsi top-level murni (aturan E21:
/// DateTime.now tidak lagi di dalam build).
String lbsLocalTimeDisplay(String timezone) {
  final nowUtc = DateTime.now().toUtc();
  if (timezone.contains('London')) {
    return '${DateFormat('HH:mm').format(nowUtc.add(const Duration(hours: 1)))} BST';
  } else if (timezone.contains('Makassar')) {
    return '${DateFormat('HH:mm').format(nowUtc.add(const Duration(hours: 8)))} WITA';
  }
  return '${DateFormat('HH:mm').format(nowUtc.add(const Duration(hours: 7)))} WIB';
}

/// Tab LBS / cabang terdekat — widget class top-level (aturan E23).
/// Scroll milik tab sendiri, bukan scroll induk (aturan A13).
class _LbsTab extends ConsumerWidget {
  final AsyncValue<NearestOutletResult> nearestAsync;

  const _LbsTab({required this.nearestAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCoord = ref.watch(userCoordinatesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Location simulation selector
        Card(
          elevation: 0,
          color: AppTheme.darkCardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.my_location_rounded, size: 18, color: AppTheme.jadeTosca),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Simulasi Posisi Pengguna (LBS GPS)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textPrimaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Koordinat saat ini: ${currentCoord.$1.toStringAsFixed(4)}, ${currentCoord.$2.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMutedDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      backgroundColor: AppTheme.darkCardSurfaceElevated,
                      side: const BorderSide(color: AppTheme.darkCardBorder),
                      label: const Text('Malioboro Jogja', style: TextStyle(color: AppTheme.textPrimaryDark, fontSize: 12)),
                      onPressed: () {
                        ref.read(userCoordinatesProvider.notifier).state = (-7.7828, 110.3670);
                      },
                    ),
                    ActionChip(
                      backgroundColor: AppTheme.darkCardSurfaceElevated,
                      side: const BorderSide(color: AppTheme.darkCardBorder),
                      label: const Text('Surakarta Solo', style: TextStyle(color: AppTheme.textPrimaryDark, fontSize: 12)),
                      onPressed: () {
                        ref.read(userCoordinatesProvider.notifier).state = (-7.5561, 110.8316);
                      },
                    ),
                    ActionChip(
                      backgroundColor: AppTheme.darkCardSurfaceElevated,
                      side: const BorderSide(color: AppTheme.darkCardBorder),
                      label: const Text('Kuta Bali', style: TextStyle(color: AppTheme.textPrimaryDark, fontSize: 12)),
                      onPressed: () {
                        ref.read(userCoordinatesProvider.notifier).state = (-8.6705, 115.2126);
                      },
                    ),
                    ActionChip(
                      backgroundColor: AppTheme.darkCardSurfaceElevated,
                      side: const BorderSide(color: AppTheme.darkCardBorder),
                      label: const Text('London UK', style: TextStyle(color: AppTheme.textPrimaryDark, fontSize: 12)),
                      onPressed: () {
                        ref.read(userCoordinatesProvider.notifier).state = (51.5074, -0.1278);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AsyncStateView<NearestOutletResult>(
          value: nearestAsync,
          onRetry: null,
          dataBuilder: (result) {
            final nearest = result.nearestOutlet;
            if (nearest == null) {
              return const EmptyStateView(
                message: 'Tidak ada data cabang.',
                icon: Icons.location_off_outlined,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Highlight Nearest Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardSurfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.jadeTosca.withAlpha(120), width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.darkCardSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.darkCardBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.stars_rounded, color: AppTheme.jadeTosca, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'CABANG TERDEKAT (LBS)',
                                    style: TextStyle(
                                      color: AppTheme.jadeTosca,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${nearest.distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: AppTheme.jadeTosca,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        nearest.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryDark,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        nearest.address,
                        style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 13),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.jadeTosca,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('Buka Detail Cabang Terdekat', maxLines: 1, overflow: TextOverflow.ellipsis),
                        onPressed: () => context.push('/outlets/${nearest.id}'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Seluruh Cabang Terurut Berdasarkan Jarak:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // List kecil dan tetap — render inline tanpa scroll bersarang (aturan A4).
                ...result.allOutletsSorted.map((item) {
                  final localTime = lbsLocalTimeDisplay(item.timezone);

                  return Card(
                    color: AppTheme.darkCardSurface,
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.darkCardSurfaceElevated,
                        child: const Icon(Icons.location_on, color: AppTheme.jadeTosca, size: 20),
                      ),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${item.distanceKm.toStringAsFixed(1)} km • $localTime', style: const TextStyle(color: AppTheme.textMutedDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const SizedBox(width: 24, child: Icon(Icons.chevron_right, size: 18, color: AppTheme.textMutedDark)),
                      onTap: () => context.push('/outlets/${item.id}'),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}
