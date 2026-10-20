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

Future<(double, double)> fetchCurrentGpsLocation() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return (-7.7828, 110.3670);
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return (-7.7828, 110.3670);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return (-7.7828, 110.3670);
    }
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    return (position.latitude, position.longitude);
  } catch (_) {
    return (-7.7828, 110.3670);
  }
}

final nearestOutletProvider = FutureProvider.autoDispose<NearestOutletResult>((ref) async {
  final repo = ref.watch(outletsRepositoryProvider);
  final (lat, lng) = ref.watch(userCoordinatesProvider);
  return repo.getNearestOutlet(lat, lng);
});

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
