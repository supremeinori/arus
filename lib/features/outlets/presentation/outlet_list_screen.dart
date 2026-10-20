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
import 'widgets/outlet_map_widget.dart';

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
          _LbsTab(nearestAsync: nearestAsync, performanceAsync: performanceAsync),
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
  final AsyncValue<List<OutletPerformanceModel>> performanceAsync;

  const _LbsTab({
    required this.nearestAsync,
    required this.performanceAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutletMapWidget(
      nearestAsync: nearestAsync,
      performanceAsync: performanceAsync,
    );
  }
}
