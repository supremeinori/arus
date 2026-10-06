class OutletModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String timezone;
  final bool isActive;
  final int inventoryCount;
  final int assignedUsersCount;
  final DateTime createdAt;

  const OutletModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    this.isActive = true,
    this.inventoryCount = 0,
    this.assignedUsersCount = 0,
    required this.createdAt,
  });

  factory OutletModel.fromJson(Map<String, dynamic> json) {
    return OutletModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      timezone: json['timezone'] as String? ?? 'Asia/Jakarta',
      isActive: json['is_active'] as bool? ?? true,
      inventoryCount: json['inventory_count'] as int? ?? 0,
      assignedUsersCount: json['assigned_users_count'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class OutletPerformanceModel {
  final String outletId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String timezone;
  final int revenue30dIdr;
  final int transactionCount30d;
  final int lowStockCount;
  final String performanceStatus; // 'optimal' | 'warning' | 'critical'

  const OutletPerformanceModel({
    required this.outletId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.revenue30dIdr,
    required this.transactionCount30d,
    required this.lowStockCount,
    required this.performanceStatus,
  });

  factory OutletPerformanceModel.fromJson(Map<String, dynamic> json) {
    return OutletPerformanceModel(
      outletId: json['outlet_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      timezone: json['timezone'] as String? ?? 'Asia/Jakarta',
      revenue30dIdr: (json['revenue_30d_idr'] as num?)?.toInt() ?? 0,
      transactionCount30d: (json['transaction_count_30d'] as num?)?.toInt() ?? 0,
      lowStockCount: (json['low_stock_count'] as num?)?.toInt() ?? 0,
      performanceStatus: json['performance_status'] as String? ?? 'optimal',
    );
  }
}

class NearbyOutletItem {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String timezone;
  final double distanceKm;

  const NearbyOutletItem({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.distanceKm,
  });

  factory NearbyOutletItem.fromJson(Map<String, dynamic> json) {
    return NearbyOutletItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      timezone: json['timezone'] as String? ?? 'Asia/Jakarta',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NearestOutletResult {
  final NearbyOutletItem? nearestOutlet;
  final List<NearbyOutletItem> allOutletsSorted;

  const NearestOutletResult({
    this.nearestOutlet,
    this.allOutletsSorted = const [],
  });

  factory NearestOutletResult.fromJson(Map<String, dynamic> json) {
    final rawNearest = json['nearest_outlet'] as Map<String, dynamic>?;
    final rawList = json['all_outlets_sorted'] as List<dynamic>? ?? [];

    return NearestOutletResult(
      nearestOutlet: rawNearest != null ? NearbyOutletItem.fromJson(rawNearest) : null,
      allOutletsSorted: rawList
          .map((item) => NearbyOutletItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
