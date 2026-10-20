import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../domain/outlet_models.dart';

final outletsRepositoryProvider = Provider<OutletsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return OutletsRepository(client);
});

class OutletsRepository {
  final ApiClient _client;

  OutletsRepository(this._client);

  Future<List<OutletModel>> getOutlets() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/outlets');
      final raw = response.data?['data'] as List<dynamic>? ?? [];
      return raw.map((item) => OutletModel.fromJson(item as Map<String, dynamic>)).toList();
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus. Tidak dapat mengambil data cabang outlet.');
    }
  }

  Future<OutletModel> getOutletById(String id) async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/outlets/$id');
      final data = response.data?['data'] as Map<String, dynamic>;
      return OutletModel.fromJson(data);
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus. Tidak dapat mengambil detail outlet.');
    }
  }

  Future<List<OutletPerformanceModel>> getPerformance() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/outlets/performance');
      final raw = response.data?['data'] as List<dynamic>? ?? [];
      return raw.map((item) => OutletPerformanceModel.fromJson(item as Map<String, dynamic>)).toList();
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus. Tidak dapat mengambil performa outlet.');
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
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus. Tidak dapat mendeteksi outlet terdekat.');
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
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus. Gagal menambahkan outlet baru.');
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
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus. Gagal memperbarui outlet.');
    }
  }

  /// Menonaktifkan outlet menggunakan soft delete (is_active = false)
  Future<OutletModel> deactivateOutlet(String id) async {
    try {
      final response = await _client.delete<Map<String, dynamic>>('/outlets/$id');
      final data = response.data?['data'] as Map<String, dynamic>;
      return OutletModel.fromJson(data);
    } on AppException {
      rethrow;
    } catch (_) {
      // Fallback ke PATCH /outlets/:id dengan is_active: false
      return updateOutlet(id, isActive: false);
    }
  }
}
