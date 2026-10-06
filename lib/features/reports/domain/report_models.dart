class ReportSummaryItem {
  final String id;
  final String type; // sales_summary, inventory_status, outlet_comparison
  final String title;
  final DateTime periodFrom;
  final DateTime periodTo;
  final List<String> outletScope;
  final String payloadHash;
  final String? createdByName;
  final DateTime createdAt;

  const ReportSummaryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.periodFrom,
    required this.periodTo,
    required this.outletScope,
    required this.payloadHash,
    this.createdByName,
    required this.createdAt,
  });

  factory ReportSummaryItem.fromJson(Map<String, dynamic> json) {
    final creator = json['created_by'] as Map<String, dynamic>?;
    final rawScope = json['outlet_scope'] as List<dynamic>? ?? [];

    return ReportSummaryItem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'sales_summary',
      title: json['title'] as String? ?? 'Laporan',
      periodFrom: DateTime.tryParse(json['period_from'] as String? ?? '') ?? DateTime.now(),
      periodTo: DateTime.tryParse(json['period_to'] as String? ?? '') ?? DateTime.now(),
      outletScope: rawScope.map((e) => e.toString()).toList(),
      payloadHash: json['payload_hash'] as String? ?? '',
      createdByName: creator?['name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get typeDisplay {
    switch (type) {
      case 'sales_summary':
        return 'Ringkasan Penjualan';
      case 'inventory_status':
        return 'Status Inventaris';
      case 'outlet_comparison':
        return 'Perbandingan Outlet';
      default:
        return type;
    }
  }
}

class ReportVerification {
  final bool isValid;
  final String storedHash;
  final String computedHash;
  final String? verifiedAt;
  final bool blockchainAnchored;
  final int? blockIndex;
  final String? blockHash;

  const ReportVerification({
    required this.isValid,
    required this.storedHash,
    required this.computedHash,
    this.verifiedAt,
    this.blockchainAnchored = false,
    this.blockIndex,
    this.blockHash,
  });

  factory ReportVerification.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ReportVerification(
        isValid: false,
        storedHash: '',
        computedHash: '',
      );
    }

    return ReportVerification(
      isValid: json['is_valid'] as bool? ?? false,
      storedHash: json['stored_hash'] as String? ?? '',
      computedHash: json['computed_hash'] as String? ?? '',
      verifiedAt: json['verified_at'] as String?,
      blockchainAnchored: json['blockchain_anchored'] as bool? ?? false,
      blockIndex: json['block_index'] as int?,
      blockHash: json['block_hash'] as String?,
    );
  }
}

class ReportDetailModel {
  final String id;
  final String type;
  final String title;
  final DateTime periodFrom;
  final DateTime periodTo;
  final List<String> outletScope;
  final Map<String, dynamic> payload;
  final String payloadHash;
  final String? createdByName;
  final DateTime createdAt;
  final ReportVerification verification;

  const ReportDetailModel({
    required this.id,
    required this.type,
    required this.title,
    required this.periodFrom,
    required this.periodTo,
    required this.outletScope,
    required this.payload,
    required this.payloadHash,
    this.createdByName,
    required this.createdAt,
    required this.verification,
  });

  factory ReportDetailModel.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    final rawScope = json['outlet_scope'] as List<dynamic>? ?? [];

    return ReportDetailModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'sales_summary',
      title: json['title'] as String? ?? 'Laporan',
      periodFrom: DateTime.tryParse(json['period_from'] as String? ?? '') ?? DateTime.now(),
      periodTo: DateTime.tryParse(json['period_to'] as String? ?? '') ?? DateTime.now(),
      outletScope: rawScope.map((e) => e.toString()).toList(),
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      payloadHash: json['payload_hash'] as String? ?? '',
      createdByName: creator?['name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      verification: ReportVerification.fromJson(json['verification'] as Map<String, dynamic>?),
    );
  }

  String get typeDisplay {
    switch (type) {
      case 'sales_summary':
        return 'Ringkasan Penjualan';
      case 'inventory_status':
        return 'Status Inventaris';
      case 'outlet_comparison':
        return 'Perbandingan Outlet';
      default:
        return type;
    }
  }
}
