import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/outlets_repository.dart';
import '../domain/outlet_models.dart';

final outletsListProvider = FutureProvider.autoDispose<List<OutletModel>>((ref) async {
  final repo = ref.watch(outletsRepositoryProvider);
  return repo.getOutlets();
});

final outletDetailProvider = FutureProvider.autoDispose.family<OutletModel, String>((ref, id) async {
  final repo = ref.watch(outletsRepositoryProvider);
  return repo.getOutletById(id);
});

final outletsPerformanceProvider = FutureProvider.autoDispose<List<OutletPerformanceModel>>((ref) async {
  final repo = ref.watch(outletsRepositoryProvider);
  return repo.getPerformance();
});

// Default lokasi user untuk simulasi / geolokasi: Malioboro Yogyakarta (-7.7828, 110.3670)
final userCoordinatesProvider = StateProvider<(double, double)>((ref) => (-7.7828, 110.3670));

/// Mengambil koordinat GPS riil perangkat dengan penanganan error komprehensif & timeout
Future<(double, double)> fetchCurrentGpsLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Layanan GPS / Lokasi perangkat tidak aktif. Mohon aktifkan GPS.');
  }
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Izin lokasi GPS ditolak oleh pengguna.');
    }
  }
  if (permission == LocationPermission.deniedForever) {
    throw Exception('Izin lokasi GPS ditolak permanen. Ubah di Pengaturan Perangkat.');
  }
  try {
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      ),
    );
    return (position.latitude, position.longitude);
  } catch (e) {
    // Fallback jika GPS timeout / signal buruk
    throw Exception('Gagal mendapatkan koordinat GPS terkini. Pastikan berada di ruang terbuka.');
  }
}

/// Menghitung jarak garis lurus (geodesik / Haversine) dalam meter
double calculateStraightDistanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  if (lat1 == 0.0 && lon1 == 0.0) return 0.0;
  if (lat2 == 0.0 && lon2 == 0.0) return 0.0;
  return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
}

/// Menghitung estimasi jarak tempuh melalui jaringan jalan darat
/// (menggunakan circuity factor standar transportasi darat 1.35x dari garis lurus)
double estimateRoadDistanceMeters(double straightDistanceMeters) {
  if (straightDistanceMeters <= 0.0) return 0.0;
  return straightDistanceMeters * 1.35;
}

/// Format jarak ke teks meter atau kilometer yang mudah dibaca
String formatDistance(double meters) {
  if (meters <= 0.0) return '0 m';
  if (meters < 1000.0) {
    return '${meters.round()} m';
  }
  final km = meters / 1000.0;
  return '${km.toStringAsFixed(1)} km';
}

final nearestOutletProvider = FutureProvider.autoDispose<NearestOutletResult>((ref) async {
  final repo = ref.watch(outletsRepositoryProvider);
  final (lat, lng) = ref.watch(userCoordinatesProvider);
  return repo.getNearestOutlet(lat, lng);
});

/// Outlet ID yang sedang dipilih pada peta LBS untuk menampilkan rute dari posisi owner
final selectedLbsOutletIdProvider = StateProvider<String?>((ref) => null);

class OutletMutationState {
  final bool isLoading;
  final String? error;

  const OutletMutationState({this.isLoading = false, this.error});
}

class OutletMutationNotifier extends StateNotifier<OutletMutationState> {
  final OutletsRepository _repo;
  final Ref _ref;

  OutletMutationNotifier(this._repo, this._ref) : super(const OutletMutationState());

  Future<bool> createOutlet({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async {
    state = const OutletMutationState(isLoading: true);
    try {
      await _repo.createOutlet(
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        timezone: timezone,
      );
      state = const OutletMutationState(isLoading: false);
      _ref.invalidate(outletsListProvider);
      _ref.invalidate(outletsPerformanceProvider);
      _ref.invalidate(nearestOutletProvider);
      return true;
    } catch (e) {
      state = OutletMutationState(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateOutlet(
    String id, {
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? timezone,
    bool? isActive,
  }) async {
    state = const OutletMutationState(isLoading: true);
    try {
      await _repo.updateOutlet(
        id,
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        timezone: timezone,
        isActive: isActive,
      );
      state = const OutletMutationState(isLoading: false);
      _ref.invalidate(outletsListProvider);
      _ref.invalidate(outletDetailProvider(id));
      _ref.invalidate(outletsPerformanceProvider);
      _ref.invalidate(nearestOutletProvider);
      return true;
    } catch (e) {
      state = OutletMutationState(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Soft delete outlet: memperbarui status is_active = false
  Future<bool> deactivateOutlet(String id) async {
    state = const OutletMutationState(isLoading: true);
    try {
      await _repo.deactivateOutlet(id);
      state = const OutletMutationState(isLoading: false);
      _ref.invalidate(outletsListProvider);
      _ref.invalidate(outletDetailProvider(id));
      _ref.invalidate(outletsPerformanceProvider);
      _ref.invalidate(nearestOutletProvider);
      return true;
    } catch (e) {
      state = OutletMutationState(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final outletMutationProvider =
    StateNotifierProvider<OutletMutationNotifier, OutletMutationState>((ref) {
  final repo = ref.watch(outletsRepositoryProvider);
  return OutletMutationNotifier(repo, ref);
});
