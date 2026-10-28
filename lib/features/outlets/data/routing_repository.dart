import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../domain/route_model.dart';

final routingRepositoryProvider = Provider<RoutingRepository>((ref) {
  return RoutingRepository();
});

class RoutingRepository {
  final Dio _dio;

  RoutingRepository({Dio? customDio})
      : _dio = customDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: {
                  'User-Agent': 'ARUS-POS-App/1.0 (com.arus.pos)',
                  'Accept': 'application/json',
                },
              ),
            );

  /// Memanggil OSRM (Open Source Routing Machine) API untuk mendapatkan rute jaringan jalan riil
  Future<RoadRouteModel> getRoute({
    required LatLng origin,
    required LatLng destination,
    CancelToken? cancelToken,
  }) async {
    // Validasi koordinat nol
    if (origin.latitude == 0.0 || origin.longitude == 0.0 ||
        destination.latitude == 0.0 || destination.longitude == 0.0) {
      return RoadRouteModel.fallback(origin, destination, error: 'Koordinat lokasi tidak valid.');
    }

    // Jika asal dan tujuan sama persis
    if (origin.latitude == destination.latitude && origin.longitude == destination.longitude) {
      return RoadRouteModel(
        points: [origin, destination],
        distanceMeters: 0,
        durationSeconds: 0,
      );
    }

    final url =
        'https://router.project-osrm.org/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson';

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        cancelToken: cancelToken,
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes[0] as Map<String, dynamic>;
          final distance = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final duration = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;
          final geometry = firstRoute['geometry'] as Map<String, dynamic>?;

          if (geometry != null && geometry['coordinates'] != null) {
            final rawCoords = geometry['coordinates'] as List<dynamic>;
            final points = rawCoords.map<LatLng>((item) {
              final pair = item as List<dynamic>;
              final lng = (pair[0] as num).toDouble();
              final lat = (pair[1] as num).toDouble();
              return LatLng(lat, lng);
            }).toList();

            if (points.isNotEmpty) {
              return RoadRouteModel(
                points: points,
                distanceMeters: distance,
                durationSeconds: duration,
              );
            }
          }
        }
      }

      return RoadRouteModel.fallback(origin, destination, error: 'Rute tidak ditemukan pada server OSM.');
    } catch (e) {
      // Fallback tanpa crash jika jaringan terputus / OSRM timeout / error HTTP
      return RoadRouteModel.fallback(origin, destination, error: 'Tidak dapat terhubung ke routing service.');
    }
  }
}
