import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/outlet_models.dart';
import '../outlets_provider.dart';

class OutletMapWidget extends ConsumerStatefulWidget {
  final AsyncValue<NearestOutletResult> nearestAsync;
  final AsyncValue<List<OutletPerformanceModel>> performanceAsync;

  const OutletMapWidget({
    super.key,
    required this.nearestAsync,
    required this.performanceAsync,
  });

  @override
  ConsumerState<OutletMapWidget> createState() => _OutletMapWidgetState();
}

class _OutletMapWidgetState extends ConsumerState<OutletMapWidget> {
  late final MapController _mapController;
  OutletPerformanceModel? _selectedOutlet;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'critical':
        return AppTheme.dangerRed;
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'optimal':
      default:
        return AppTheme.jadeTosca;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'critical':
        return 'Kritis';
      case 'warning':
        return 'Perhatian';
      case 'optimal':
      default:
        return 'Optimal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userCoord = ref.watch(userCoordinatesProvider);
    final userLatLng = LatLng(userCoord.$1, userCoord.$2);

    final perfList = widget.performanceAsync.value ?? [];
    final perfMap = {for (var p in perfList) p.outletId: p};

    final nearestResult = widget.nearestAsync.value;
    final allOutlets = nearestResult?.allOutletsSorted ?? [];

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: userLatLng,
            initialZoom: 13.0,
            onTap: (_, point) => setState(() => _selectedOutlet = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.arus.pos',
            ),
            MarkerLayer(
              markers: [
                // Owner / User GPS Marker (Blue)
                Marker(
                  point: userLatLng,
                  width: 48,
                  height: 48,
                  child: const Tooltip(
                    message: 'Lokasi Anda (Owner)',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.my_location_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
                // Branch Markers
                for (final item in allOutlets)
                  () {
                    final perf = perfMap[item.id];
                    final statusColor = _getStatusColor(perf?.performanceStatus);
                    final isSelected = _selectedOutlet?.outletId == item.id;

                    return Marker(
                      point: LatLng(item.latitude, item.longitude),
                      width: isSelected ? 56 : 44,
                      height: isSelected ? 56 : 44,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedOutlet = perf ??
                                OutletPerformanceModel(
                                  outletId: item.id,
                                  name: item.name,
                                  address: item.address,
                                  latitude: item.latitude,
                                  longitude: item.longitude,
                                  timezone: item.timezone,
                                  revenue30dIdr: 0,
                                  transactionCount30d: 0,
                                  lowStockCount: 0,
                                  performanceStatus: 'optimal',
                                );
                          });
                        },
                        child: Tooltip(
                          message: '${item.name} (${item.distanceKm.toStringAsFixed(1)} km)',
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.black45,
                                width: isSelected ? 3 : 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ],
        ),

        // Floating Action Buttons (Pusatkan ke Lokasi Saya & Pilih Cabang Terdekat)
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'btn_center_user',
                backgroundColor: AppTheme.darkCardSurface,
                foregroundColor: AppTheme.jadeTosca,
                elevation: 3,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Lokasi Saya', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  _mapController.move(userLatLng, 14.0);
                  setState(() => _selectedOutlet = null);
                },
              ),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: 'btn_nearest_branch',
                backgroundColor: AppTheme.jadeTosca,
                foregroundColor: Colors.white,
                elevation: 3,
                icon: const Icon(Icons.near_me_rounded, size: 18),
                label: const Text('Cabang Terdekat', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  final nearest = nearestResult?.nearestOutlet;
                  if (nearest != null) {
                    final targetLatLng = LatLng(nearest.latitude, nearest.longitude);
                    _mapController.move(targetLatLng, 15.0);
                    final perf = perfMap[nearest.id];
                    setState(() {
                      _selectedOutlet = perf ??
                          OutletPerformanceModel(
                            outletId: nearest.id,
                            name: nearest.name,
                            address: nearest.address,
                            latitude: nearest.latitude,
                            longitude: nearest.longitude,
                            timezone: nearest.timezone,
                            revenue30dIdr: 0,
                            transactionCount30d: 0,
                            lowStockCount: 0,
                            performanceStatus: 'optimal',
                          );
                    });
                  }
                },
              ),
            ],
          ),
        ),

        // Bottom Selected Outlet Info Card
        if (_selectedOutlet != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              color: AppTheme.darkCardSurface,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedOutlet!.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppTheme.textMutedDark),
                          onPressed: () => setState(() => _selectedOutlet = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedOutlet!.address,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getStatusColor(_selectedOutlet!.performanceStatus).withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _getStatusColor(_selectedOutlet!.performanceStatus).withAlpha(60),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 4,
                                backgroundColor: _getStatusColor(_selectedOutlet!.performanceStatus),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getStatusText(_selectedOutlet!.performanceStatus),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(_selectedOutlet!.performanceStatus),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.jadeTosca,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => context.push('/outlets/${_selectedOutlet!.outletId}'),
                          child: const Text('Detail', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
