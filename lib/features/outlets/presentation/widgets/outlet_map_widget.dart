import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/outlet_models.dart';
import '../outlets_provider.dart';

// =============================================================================
// 1. OUTLET MAP WIDGET (Mode Eksplorasi Peta & LBS Cabang)
// =============================================================================

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
            onTap: (_, point) {
              if (mounted) setState(() => _selectedOutlet = null);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.arus.pos',
            ),
            MarkerLayer(
              markers: [
                // Marker GPS Pengguna (Biru)
                Marker(
                  point: userLatLng,
                  width: 48,
                  height: 48,
                  child: const Tooltip(
                    message: 'Lokasi Anda (Owner/GPS)',
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
                          if (!mounted) return;
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

        // Tombol Aksi Cepat (Pusatkan ke Lokasi Saya & Cabang Terdekat)
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
                  if (mounted) setState(() => _selectedOutlet = null);
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
                    if (mounted) {
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
                  }
                },
              ),
            ],
          ),
        ),

        // Bottom Info Card untuk Cabang Terpilih
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
                          onPressed: () {
                            if (mounted) setState(() => _selectedOutlet = null);
                          },
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
                    const SizedBox(height: 8),
                    // Perhitungan Jarak Garis Lurus vs Estimasi Jalan
                    () {
                      final straightMeters = calculateStraightDistanceMeters(
                        userLatLng.latitude,
                        userLatLng.longitude,
                        _selectedOutlet!.latitude,
                        _selectedOutlet!.longitude,
                      );
                      final roadMeters = estimateRoadDistanceMeters(straightMeters);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                  const Icon(Icons.straighten_rounded, size: 14, color: AppTheme.textMutedDark),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Garis Lurus: ${formatDistance(straightMeters)}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(Icons.directions_car_rounded, size: 14, color: AppTheme.jadeTosca),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Est. Jalan: ${formatDistance(roadMeters)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.jadeTosca,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }(),
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

// =============================================================================
// 2. OUTLET LOCATION PICKER WIDGET (Mode Pemilihan Titik Koordinat Form Cabang)
// =============================================================================

class OutletLocationPickerWidget extends ConsumerStatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<LatLng> onLocationSelected;

  const OutletLocationPickerWidget({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    required this.onLocationSelected,
  });

  @override
  ConsumerState<OutletLocationPickerWidget> createState() => _OutletLocationPickerWidgetState();
}

class _OutletLocationPickerWidgetState extends ConsumerState<OutletLocationPickerWidget> {
  late final MapController _mapController;
  LatLng? _selectedLocation;
  bool _isLocatingGps = false;
  String? _gpsStatusMessage;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.initialLatitude != null &&
        widget.initialLongitude != null &&
        widget.initialLatitude != 0.0 &&
        widget.initialLongitude != 0.0) {
      _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  @override
  void didUpdateWidget(covariant OutletLocationPickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLatitude != oldWidget.initialLatitude ||
        widget.initialLongitude != oldWidget.initialLongitude) {
      if (widget.initialLatitude != null &&
          widget.initialLongitude != null &&
          widget.initialLatitude != 0.0 &&
          widget.initialLongitude != 0.0) {
        final newPoint = LatLng(widget.initialLatitude!, widget.initialLongitude!);
        _selectedLocation = newPoint;
        _mapController.move(newPoint, _mapController.camera.zoom);
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _pickCurrentGpsLocation() async {
    if (!mounted) return;
    setState(() {
      _isLocatingGps = true;
      _gpsStatusMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isLocatingGps = false;
          _gpsStatusMessage = 'Layanan GPS tidak aktif pada perangkat.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isLocatingGps = false;
            _gpsStatusMessage = 'Izin lokasi GPS ditolak oleh pengguna.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isLocatingGps = false;
          _gpsStatusMessage = 'Izin lokasi GPS ditolak permanen. Buka pengaturan untuk mengaktifkan.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _selectedLocation = target;
        _isLocatingGps = false;
        _gpsStatusMessage = null;
      });

      _mapController.move(target, 16.0);
      widget.onLocationSelected(target);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocatingGps = false;
        _gpsStatusMessage = 'Gagal mendeteksi sinyal GPS perangkat.';
      });
    }
  }

  void _onTapMap(TapPosition _, LatLng point) {
    if (!mounted) return;
    setState(() {
      _selectedLocation = point;
      _gpsStatusMessage = null;
    });
    widget.onLocationSelected(point);
  }

  @override
  Widget build(BuildContext context) {
    final userCoord = ref.watch(userCoordinatesProvider);
    final userLatLng = LatLng(userCoord.$1, userCoord.$2);

    final initialCenter = _selectedLocation ?? userLatLng;

    // Perhitungan jarak dari lokasi GPS pengguna ke titik outlet terpilih
    double? straightDistanceMeters;
    double? roadDistanceMeters;

    if (_selectedLocation != null && userCoord.$1 != 0.0 && userCoord.$2 != 0.0) {
      straightDistanceMeters = calculateStraightDistanceMeters(
        userLatLng.latitude,
        userLatLng.longitude,
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
      roadDistanceMeters = estimateRoadDistanceMeters(straightDistanceMeters);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wadah Peta Interaktif
        Container(
          height: 260,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.darkCardBorder, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: _selectedLocation != null ? 15.0 : 13.0,
                  onTap: _onTapMap,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.arus.pos',
                  ),
                  MarkerLayer(
                    markers: [
                      // Marker GPS Pengguna (Titik Acuan Biru)
                      Marker(
                        point: userLatLng,
                        width: 36,
                        height: 36,
                        child: const Tooltip(
                          message: 'Lokasi Anda (GPS Acuan)',
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                      // Marker Cabang Terpilih (Pin Merah Berkepala Besar)
                      if (_selectedLocation != null)
                        Marker(
                          point: _selectedLocation!,
                          width: 50,
                          height: 50,
                          child: const Tooltip(
                            message: 'Titik Lokasi Cabang Terpilih',
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppTheme.dangerRed,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down_rounded, color: AppTheme.dangerRed, size: 14),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Overlay Panduan Ketuk
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 14, color: AppTheme.jadeTosca),
                      SizedBox(width: 6),
                      Text(
                        'Ketuk titik pada peta untuk memilih lokasi',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),

              // Tombol Deteksi GPS & Zoom di kanan peta
              Positioned(
                top: 10,
                right: 10,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'picker_btn_gps',
                      backgroundColor: AppTheme.darkCardSurfaceElevated,
                      foregroundColor: AppTheme.jadeTosca,
                      elevation: 4,
                      tooltip: 'Gunakan Lokasi GPS Saya Saat Ini',
                      onPressed: _isLocatingGps ? null : _pickCurrentGpsLocation,
                      child: _isLocatingGps
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.jadeTosca),
                            )
                          : const Icon(Icons.gps_fixed_rounded, size: 18),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'picker_btn_zoom_in',
                      backgroundColor: AppTheme.darkCardSurfaceElevated,
                      foregroundColor: AppTheme.textPrimaryDark,
                      elevation: 3,
                      tooltip: 'Perbesar Peta',
                      onPressed: () {
                        final currentZoom = _mapController.camera.zoom;
                        _mapController.move(_mapController.camera.center, currentZoom + 1.0);
                      },
                      child: const Icon(Icons.add, size: 18),
                    ),
                    const SizedBox(height: 4),
                    FloatingActionButton.small(
                      heroTag: 'picker_btn_zoom_out',
                      backgroundColor: AppTheme.darkCardSurfaceElevated,
                      foregroundColor: AppTheme.textPrimaryDark,
                      elevation: 3,
                      tooltip: 'Perkecil Peta',
                      onPressed: () {
                        final currentZoom = _mapController.camera.zoom;
                        _mapController.move(_mapController.camera.center, currentZoom - 1.0);
                      },
                      child: const Icon(Icons.remove, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Error message jika deteksi GPS gagal
        if (_gpsStatusMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.dangerRed.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.dangerRed.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.dangerRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _gpsStatusMessage!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.dangerRed),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Panel Ringkasan Koordinat dan Perhitungan Jarak (LBS)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.darkCardSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.darkCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pin_drop_rounded, size: 16, color: AppTheme.jadeTosca),
                  const SizedBox(width: 6),
                  const Text(
                    'Koordinat Cabang:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _selectedLocation != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.jadeTosca.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.jadeTosca, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : const Text(
                              'Belum dipilih',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMutedDark, fontStyle: FontStyle.italic),
                            ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16, thickness: 0.8, color: AppTheme.darkCardBorder),
              if (_selectedLocation != null && straightDistanceMeters != null && roadDistanceMeters != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.straighten_rounded, size: 13, color: AppTheme.textMutedDark),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Garis Lurus',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textMutedDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatDistance(straightDistanceMeters),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 26, color: AppTheme.darkCardBorder),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.directions_car_rounded, size: 13, color: AppTheme.jadeTosca),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Est. Jalan',
                                  style: TextStyle(fontSize: 11, color: AppTheme.jadeTosca),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatDistance(roadDistanceMeters),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.jadeTosca,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textMutedDark),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pilih titik di peta untuk melihat jarak dari lokasi GPS Anda.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMutedDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
