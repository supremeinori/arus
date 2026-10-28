import 'package:latlong2/latlong.dart';

class RoadRouteModel {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final bool isFallback;
  final String? errorMessage;

  const RoadRouteModel({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.isFallback = false,
    this.errorMessage,
  });

  /// Utility untuk format estimasi durasi dalam menit atau jam
  String get formattedDuration {
    if (durationSeconds <= 0) return '0 mnt';
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) {
      return '$minutes mnt';
    }
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    if (remainingMins == 0) {
      return '$hours jam';
    }
    return '$hours j $remainingMins m';
  }

  /// Construct fallback route (garis lurus antara dua titik saat service offline/error)
  factory RoadRouteModel.fallback(LatLng origin, LatLng destination, {String? error}) {
    final straightMeters = const Distance().as(
      LengthUnit.Meter,
      origin,
      destination,
    );
    // Estimasi sederhana 30 km/jam (~8.33 m/s) untuk durasi fallback
    final estDuration = straightMeters / 8.33;

    return RoadRouteModel(
      points: [origin, destination],
      distanceMeters: straightMeters,
      durationSeconds: estDuration,
      isFallback: true,
      errorMessage: error,
    );
  }
}
