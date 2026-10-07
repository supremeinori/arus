import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/outlet_models.dart';

final outletsRepositoryProvider = Provider<OutletsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return OutletsRepository(client);
});

class OutletsRepository {
  final ApiClient _client;

  OutletsRepository(this._client);

  static final List<OutletModel> _demoOutlets = [
    OutletModel(
      id: 'out-001',
      name: 'Kopi Arus - Sudirman (HQ)',
      address: 'Jl. Jend. Sudirman No. 45, Jakarta Pusat',
      latitude: -6.2088,
      longitude: 106.8456,
      timezone: 'Asia/Jakarta',
      isActive: true,
      inventoryCount: 32,
      assignedUsersCount: 4,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    OutletModel(
      id: 'out-002',
      name: 'Kopi Arus - Senopati',
      address: 'Jl. Senopati No. 12, Jakarta Selatan',
      latitude: -6.2297,
      longitude: 106.8074,
      timezone: 'Asia/Jakarta',
      isActive: true,
      inventoryCount: 28,
      assignedUsersCount: 3,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    OutletModel(
      id: 'out-003',
      name: 'Kopi Arus - Canggu',
      address: 'Jl. Pantai Batu Bolong, Bali',
      latitude: -8.6500,
      longitude: 115.1333,
      timezone: 'Asia/Makassar',
      isActive: true,
      inventoryCount: 24,
      assignedUsersCount: 2,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
  ];

  static final List<OutletPerformanceModel> _demoPerformance = [
    const OutletPerformanceModel(
      outletId: 'out-001',
      name: 'Kopi Arus - Sudirman (HQ)',
      address: 'Jl. Jend. Sudirman No. 45, Jakarta Pusat',
      latitude: -6.2088,
      longitude: 106.8456,
      timezone: 'Asia/Jakarta',
      revenue30dIdr: 45200000,
      transactionCount30d: 128,
      lowStockCount: 2,
      performanceStatus: 'optimal',
    ),
    const OutletPerformanceModel(
      outletId: 'out-002',
      name: 'Kopi Arus - Senopati',
      address: 'Jl. Senopati No. 12, Jakarta Selatan',
      latitude: -6.2297,
      longitude: 106.8074,
      timezone: 'Asia/Jakarta',
      revenue30dIdr: 31800000,
      transactionCount30d: 94,
      lowStockCount: 3,
      performanceStatus: 'warning',
    ),
    const OutletPerformanceModel(
      outletId: 'out-003',
      name: 'Kopi Arus - Canggu',
      address: 'Jl. Pantai Batu Bolong, Bali',
      latitude: -8.6500,
      longitude: 115.1333,
      timezone: 'Asia/Makassar',
      revenue30dIdr: 22400000,
      transactionCount30d: 76,
      lowStockCount: 1,
      performanceStatus: 'optimal',
    ),
  ];

  Future<List<OutletModel>> getOutlets() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/outlets');
      final raw = response.data?['data'] as List<dynamic>? ?? [];
      return raw.map((item) => OutletModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      // Fallback demo data jika server offline / unreachable
      return _demoOutlets;
    }
  }

  Future<OutletModel> getOutletById(String id) async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/outlets/$id');
      final data = response.data?['data'] as Map<String, dynamic>;
      return OutletModel.fromJson(data);
    } catch (_) {
      return _demoOutlets.firstWhere(
        (o) => o.id == id,
        orElse: () => _demoOutlets.first,
      );
    }
  }

  Future<List<OutletPerformanceModel>> getPerformance() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/outlets/performance');
      final raw = response.data?['data'] as List<dynamic>? ?? [];
      return raw.map((item) => OutletPerformanceModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return _demoPerformance;
    }
  }

  Future<NearestOutletResult> getNearestOutlet(double lat, double lng) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/outlets/nearest',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final data = response.data?['data'] as Map<String, dynamic>;
      return NearestOutletResult.fromJson(data);
    } catch (_) {
      // Haversine calculation client-side fallback
      final items = _demoOutlets.map((o) {
        final dLat = (o.latitude - lat) * (pi / 180.0);
        final dLng = (o.longitude - lng) * (pi / 180.0);
        final a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat * (pi / 180.0)) * cos(o.latitude * (pi / 180.0)) *
            sin(dLng / 2) * sin(dLng / 2);
        final c = 2 * atan2(sqrt(a), sqrt(1 - a));
        final distanceKm = 6371.0 * c;
        return NearbyOutletItem(
          id: o.id,
          name: o.name,
          address: o.address,
          latitude: o.latitude,
          longitude: o.longitude,
          timezone: o.timezone,
          distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
        );
      }).toList();

      items.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return NearestOutletResult(
        nearestOutlet: items.isNotEmpty ? items.first : null,
        allOutletsSorted: items,
      );
    }
  }

  Future<OutletModel> createOutlet({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/outlets',
        data: {
          'name': name,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'timezone': timezone,
        },
      );
      final data = response.data?['data'] as Map<String, dynamic>;
      return OutletModel.fromJson(data);
    } catch (_) {
      final newOutlet = OutletModel(
        id: 'out-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        timezone: timezone,
        isActive: true,
        createdAt: DateTime.now(),
      );
      _demoOutlets.add(newOutlet);
      return newOutlet;
    }
  }

  Future<OutletModel> updateOutlet(
    String id, {
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? timezone,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (address != null) body['address'] = address;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (timezone != null) body['timezone'] = timezone;
    if (isActive != null) body['is_active'] = isActive;

    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/outlets/$id',
        data: body,
      );
      final data = response.data?['data'] as Map<String, dynamic>;
      return OutletModel.fromJson(data);
    } catch (_) {
      final index = _demoOutlets.indexWhere((o) => o.id == id);
      if (index >= 0) {
        final existing = _demoOutlets[index];
        final updated = OutletModel(
          id: existing.id,
          name: name ?? existing.name,
          address: address ?? existing.address,
          latitude: latitude ?? existing.latitude,
          longitude: longitude ?? existing.longitude,
          timezone: timezone ?? existing.timezone,
          isActive: isActive ?? existing.isActive,
          createdAt: existing.createdAt,
        );
        _demoOutlets[index] = updated;
        return updated;
      }
      return _demoOutlets.first;
    }
  }
}
