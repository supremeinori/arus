import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/outlet_models.dart';
import '../../domain/route_model.dart';
import '../../data/routing_repository.dart';
import '../outlets_provider.dart';

// Provider untuk mengambil rute jalan aktual (OSRM) secara asinkron dengan auto cancel
final selectedRouteProvider = FutureProvider.autoDispose.family<RoadRouteModel, (LatLng, LatLng)>((ref, coords) async {
  final routingRepo = ref.watch(routingRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('Route request disposed'));
  return routingRepo.getRoute(origin: coords.$1, destination: coords.$2, cancelToken: cancelToken);
});

// =============================================================================
// 1. OUTLET MAP WIDGET (Mode Eksplorasi Peta & LBS Cabang dengan Rute Jalan)
// =============================================================================

class OutletMapWidget extends ConsumerStatefulWidget {
  final AsyncValue<NearestOutletResult> nearestAsync;
  final AsyncValue<List<OutletPerformanceModel>> performanceAsync;
  final TileProvider? tileProvider;

  const OutletMapWidget({
    super.key,
    required this.nearestAsync,
    required this.performanceAsync,
    this.tileProvider,
  });

  @override
  ConsumerState<OutletMapWidget> createState() => _OutletMapWidgetState();
}

class _OutletMapWidgetState extends ConsumerState<OutletMapWidget> {
  late final MapController _mapController;
  OutletPerformanceModel? _selectedOutlet;
  bool _isLocatingOrRouting = false;
  bool _hasAutoSelected = false;

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

  void _fitCameraToBounds(LatLng origin, LatLng destination, List<LatLng> routePoints) {
    if (!mounted) {
      return;
    }
    if (origin.latitude.isNaN || origin.longitude.isNaN || 
        destination.latitude.isNaN || destination.longitude.isNaN) {
      return;
    }
    if (origin.latitude == 0.0 && origin.longitude == 0.0) {
      return;
    }
    if (destination.latitude == 0.0 && destination.longitude == 0.0) {
      return;
    }

    try {
      final validPoints = <LatLng>[
        origin,
        destination,
        ...routePoints.where((p) => !p.latitude.isNaN && !p.longitude.isNaN && p.latitude != 0.0 && p.longitude != 0.0),
      ];

      // Jika jarak sangat dekat / koordinat sama persis, pusatkan kamera
      if ((origin.latitude - destination.latitude).abs() < 0.0001 &&
          (origin.longitude - destination.longitude).abs() < 0.0001) {
        _mapController.move(destination, 15.0);
        return;
      }

      final bounds = LatLngBounds.fromPoints(validPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 56.0),
          maxZoom: 16.5,
          minZoom: 4.0,
        ),
      );
    } catch (_) {
      try {
        _mapController.move(destination, 14.0);
      } catch (_) {}
    }
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

  void _selectOutlet(
    String outletId,
    List<NearbyOutletItem> allOutlets,
    Map<String, OutletPerformanceModel> perfMap,
    LatLng userLatLng,
  ) {
    final matches = allOutlets.where((o) => o.id == outletId);
    if (matches.isEmpty) {
      return;
    }
    final foundItem = matches.first;

    final perf = perfMap[outletId];
    final perfModel = perf ??
        OutletPerformanceModel(
          outletId: foundItem.id,
          name: foundItem.name,
          address: foundItem.address,
          latitude: foundItem.latitude,
          longitude: foundItem.longitude,
          timezone: foundItem.timezone,
          revenue30dIdr: 0,
          transactionCount30d: 0,
          lowStockCount: 0,
          performanceStatus: 'optimal',
        );

    setState(() {
      _selectedOutlet = perfModel;
    });
    ref.read(selectedLbsOutletIdProvider.notifier).state = outletId;

    final targetLatLng = LatLng(foundItem.latitude, foundItem.longitude);
    _fitCameraToBounds(userLatLng, targetLatLng, []);
  }

  @override
  Widget build(BuildContext context) {
    final userCoord = ref.watch(userCoordinatesProvider);
    final userLatLng = LatLng(userCoord.$1, userCoord.$2);

    final perfList = widget.performanceAsync.value ?? [];
    final perfMap = {for (var p in perfList) p.outletId: p};

    final nearestResult = widget.nearestAsync.value;
    final allOutlets = nearestResult?.allOutletsSorted ?? [];
    final selectedOutletIdFromProvider = ref.watch(selectedLbsOutletIdProvider);

    // Sinkronisasi outlet jika berubah dari luar (misal: tombol rute di daftar cabang)
    if (selectedOutletIdFromProvider != null && _selectedOutlet?.outletId != selectedOutletIdFromProvider) {
      final matches = allOutlets.where((o) => o.id == selectedOutletIdFromProvider);
      if (matches.isNotEmpty) {
        final found = matches.first;
        final perf = perfMap[selectedOutletIdFromProvider];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedOutlet = perf ??
                  OutletPerformanceModel(
                    outletId: found.id,
                    name: found.name,
                    address: found.address,
                    latitude: found.latitude,
                    longitude: found.longitude,
                    timezone: found.timezone,
                    revenue30dIdr: 0,
                    transactionCount30d: 0,
                    lowStockCount: 0,
                    performanceStatus: 'optimal',
                  );
            });
            _fitCameraToBounds(userLatLng, LatLng(found.latitude, found.longitude), []);
          }
        });
      }
    } else if (!_hasAutoSelected && _selectedOutlet == null && nearestResult != null && allOutlets.isNotEmpty) {
      _hasAutoSelected = true;
      // Auto-select cabang terdekat saat pertama kali dimuat agar rute langsung muncul
      final nearest = nearestResult.nearestOutlet ?? allOutlets.firstOrNull;
      if (nearest != null) {
        final perf = perfMap[nearest.id];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedOutlet == null) {
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
            ref.read(selectedLbsOutletIdProvider.notifier).state = nearest.id;
            _fitCameraToBounds(userLatLng, LatLng(nearest.latitude, nearest.longitude), []);
          }
        });
      }
    }

    // Watch route provider untuk outlet terpilih & auto-fit kamera saat rute selesai dimuat
    AsyncValue<RoadRouteModel>? routeAsync;
    if (_selectedOutlet != null) {
      final targetLatLng = LatLng(_selectedOutlet!.latitude, _selectedOutlet!.longitude);
      ref.listen<AsyncValue<RoadRouteModel>>(
        selectedRouteProvider((userLatLng, targetLatLng)),
        (previous, next) {
          next.whenData((route) {
            if (mounted && route.points.isNotEmpty) {
              _fitCameraToBounds(userLatLng, targetLatLng, route.points);
            }
          });
        },
      );
      routeAsync = ref.watch(selectedRouteProvider((userLatLng, targetLatLng)));
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: userLatLng,
            initialZoom: 13.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, point) {
              if (mounted && !_isLocatingOrRouting) {
                setState(() => _selectedOutlet = null);
                ref.read(selectedLbsOutletIdProvider.notifier).state = null;
              }
            },
          ),
          children: [
            // OpenStreetMap (OSM) Standard Tile Layer dengan Custom User-Agent & Error Silencer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.arus.pos',
              maxZoom: 19,
              tileProvider: widget.tileProvider ??
                  NetworkTileProvider(
                    silenceExceptions: true,
                    headers: {
                      'User-Agent': 'ARUS-POS-App/1.0 (com.arus.pos; contact@arus.id)',
                    },
                  ),
              errorTileCallback: (tile, error, stackTrace) {
                // Tangani kegagalan load tile OSM saat offline tanpa melempar unhandled exception
              },
            ),
            // Layer Rute Jalan Aktual (Polyline)
            if (routeAsync != null && routeAsync.hasValue)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routeAsync.value!.points,
                    color: routeAsync.value!.isFallback
                        ? const Color(0xFFF59E0B) // Amber untuk estimasi garis lurus
                        : AppTheme.jadeTosca,      // Tosca untuk rute jalan darat OSRM
                    strokeWidth: 4.5,
                    borderStrokeWidth: 1.5,
                    borderColor: Colors.white,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                // Marker GPS Pengguna / Owner (Biru)
                Marker(
                  point: userLatLng,
                  width: 48,
                  height: 48,
                  child: const Tooltip(
                    message: 'Lokasi Anda (Owner / GPS)',
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
                // Marker Seluruh Cabang Outlet
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
                          if (!mounted || _isLocatingOrRouting) {
                            return;
                          }
                          _selectOutlet(item.id, allOutlets, perfMap, userLatLng);
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

        // Horizontal Branch Selector Chips (Pilih Cabang untuk Rute Jalan)
        if (allOutlets.isNotEmpty)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.darkCardSurface.withAlpha(240),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.darkCardBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.alt_route_rounded, size: 15, color: AppTheme.jadeTosca),
                          SizedBox(width: 4),
                          Text(
                            'Rute ke:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    for (final item in allOutlets) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          avatar: Icon(
                            Icons.storefront_rounded,
                            size: 13,
                            color: (_selectedOutlet?.outletId == item.id) ? Colors.white : AppTheme.jadeTosca,
                          ),
                          label: Text(
                            '${item.name} (${item.distanceKm.toStringAsFixed(1)} km)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: (_selectedOutlet?.outletId == item.id) ? FontWeight.bold : FontWeight.normal,
                              color: (_selectedOutlet?.outletId == item.id) ? Colors.white : AppTheme.textSecondaryDark,
                            ),
                          ),
                          selected: _selectedOutlet?.outletId == item.id,
                          selectedColor: AppTheme.jadeTosca,
                          backgroundColor: AppTheme.darkCardSurfaceElevated,
                          side: BorderSide(
                            color: (_selectedOutlet?.outletId == item.id) ? AppTheme.jadeTosca : AppTheme.darkCardBorder,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          showCheckmark: false,
                          onSelected: (selected) {
                            if (selected) {
                              _selectOutlet(item.id, allOutlets, perfMap, userLatLng);
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

        // Tombol Aksi Cepat (Pusatkan ke Lokasi Saya & Cabang Terdekat)
        Positioned(
          top: allOutlets.isNotEmpty ? 62 : 14,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'btn_center_user',
                backgroundColor: AppTheme.darkCardSurface,
                foregroundColor: AppTheme.jadeTosca,
                elevation: 3,
                tooltip: 'Pusatkan ke Lokasi Saya',
                onPressed: _isLocatingOrRouting
                    ? null
                    : () {
                        _mapController.move(userLatLng, 14.0);
                      },
                child: const Icon(Icons.my_location_rounded, size: 18),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'btn_nearest_branch',
                backgroundColor: AppTheme.jadeTosca,
                foregroundColor: Colors.white,
                elevation: 3,
                tooltip: 'Cabang Terdekat',
                onPressed: _isLocatingOrRouting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _isLocatingOrRouting = true);
                        try {
                          final gpsCoord = await fetchCurrentGpsLocation();
                          if (mounted) {
                            ref.read(userCoordinatesProvider.notifier).state = gpsCoord;
                            ref.invalidate(nearestOutletProvider);
                            await ref.read(nearestOutletProvider.future);
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('GPS: ${e.toString().replaceAll("Exception: ", "")}'),
                                backgroundColor: AppTheme.dangerRed,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLocatingOrRouting = false);
                          }
                        }

                        final freshResult = ref.read(nearestOutletProvider).value;
                        final nearest = freshResult?.nearestOutlet ?? freshResult?.allOutletsSorted.firstOrNull;

                        if (nearest != null) {
                          _selectOutlet(nearest.id, allOutlets, perfMap, userLatLng);
                        } else {
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Tidak ada data cabang outlet yang tersedia.'),
                                backgroundColor: AppTheme.dangerRed,
                              ),
                            );
                          }
                        }
                      },
                child: _isLocatingOrRouting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.near_me_rounded, size: 18),
              ),
            ],
          ),
        ),

        // Bottom Info Card untuk Cabang Terpilih & Detail Rute Jalan
        if (_selectedOutlet != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              color: AppTheme.darkCardSurface,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppTheme.textMutedDark),
                          tooltip: 'Tutup Rute',
                          onPressed: () {
                            if (mounted) {
                              setState(() => _selectedOutlet = null);
                              ref.read(selectedLbsOutletIdProvider.notifier).state = null;
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedOutlet!.address,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Informasi Rute Jalan Aktual (OSRM)
                    if (routeAsync != null)
                      routeAsync.when(
                        data: (route) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCardSurfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.darkCardBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.directions_car_rounded,
                                      size: 16,
                                      color: route.isFallback ? const Color(0xFFF59E0B) : AppTheme.jadeTosca,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Jalur: ${formatDistance(route.distanceMeters)}${route.isFallback ? " (Lurus)" : ""}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: route.isFallback ? const Color(0xFFF59E0B) : AppTheme.jadeTosca,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  const Icon(Icons.timer_rounded, size: 15, color: AppTheme.textMutedDark),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Est. ${route.formattedDuration}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        loading: () => Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.jadeTosca),
                              ),
                              SizedBox(width: 8),
                              Text('Menghitung rute jalan...', style: TextStyle(fontSize: 11, color: AppTheme.textMutedDark)),
                            ],
                          ),
                        ),
                        error: (err, stack) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerRed.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Gagal memuat rute jalan aktual. Menampilkan estimasi garis lurus.',
                            style: TextStyle(fontSize: 11, color: AppTheme.dangerRed),
                          ),
                        ),
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
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.jadeTosca,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: const Size(0, 32),
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                          onPressed: () => context.push('/outlets/${_selectedOutlet!.outletId}'),
                          label: const Text('Detail Cabang', style: TextStyle(fontSize: 11.5)),
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

// =============================================================================
// 2. OUTLET LOCATION PICKER WIDGET
// =============================================================================

class OutletLocationPickerWidget extends ConsumerStatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final ValueChanged<LatLng> onLocationSelected;

  const OutletLocationPickerWidget({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onLocationSelected,
  });

  @override
  ConsumerState<OutletLocationPickerWidget> createState() => _OutletLocationPickerWidgetState();
}

class _OutletLocationPickerWidgetState extends ConsumerState<OutletLocationPickerWidget> {
  late final MapController _mapController;
  late LatLng _currentLatLng;
  bool _isGettingGps = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentLatLng = LatLng(widget.initialLatitude, widget.initialLongitude);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Lokasi Cabang pada Peta *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppTheme.jadeTosca, padding: EdgeInsets.zero),
              onPressed: _isGettingGps
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _isGettingGps = true);
                      try {
                        final gps = await fetchCurrentGpsLocation();
                        final newLatLng = LatLng(gps.$1, gps.$2);
                        setState(() => _currentLatLng = newLatLng);
                        _mapController.move(newLatLng, 15.0);
                        if (mounted) {
                          widget.onLocationSelected(newLatLng);
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll("Exception: ", "")),
                              backgroundColor: AppTheme.dangerRed,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isGettingGps = false);
                        }
                      }
                    },
              icon: _isGettingGps
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.jadeTosca),
                    )
                  : const Icon(Icons.my_location_rounded, size: 14),
              label: const Text('Gunakan GPS Saya', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 220,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkCardBorder),
          ),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLatLng,
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, point) {
                    setState(() {
                      _currentLatLng = point;
                    });
                    widget.onLocationSelected(point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.arus.pos',
                    maxZoom: 19,
                    tileProvider: NetworkTileProvider(
                      silenceExceptions: true,
                      headers: {
                        'User-Agent': 'ARUS-POS-App/1.0 (com.arus.pos; contact@arus.id)',
                      },
                    ),
                    errorTileCallback: (tile, error, stackTrace) {},
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLatLng,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.location_pin,
                          color: AppTheme.dangerRed,
                          size: 42,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardSurface.withAlpha(230),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkCardBorder),
                  ),
                  child: Text(
                    'Koordinat Cabang: ${_currentLatLng.latitude.toStringAsFixed(5)}, ${_currentLatLng.longitude.toStringAsFixed(5)} (Tap peta untuk ubah)',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
