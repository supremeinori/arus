class IntegrityChainSnapshot {
  final IntegrityChainOverview overview;
  final IntegrityValidation validation;

  const IntegrityChainSnapshot({
    required this.overview,
    required this.validation,
  });
}

class IntegrityChainOverview {
  final String outletId;
  final int blockCount;
  final List<IntegrityBlockItem> blocks;

  const IntegrityChainOverview({
    required this.outletId,
    required this.blockCount,
    required this.blocks,
  });

  factory IntegrityChainOverview.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'] as List<dynamic>? ?? const [];
    return IntegrityChainOverview(
      outletId: json['outletId'] as String? ?? '',
      blockCount: (json['blockCount'] as num?)?.toInt() ?? rawBlocks.length,
      blocks: rawBlocks
          .whereType<Map<String, dynamic>>()
          .map(IntegrityBlockItem.fromJson)
          .toList(growable: false),
    );
  }
}

class IntegrityBlockItem {
  final int index;
  final String eventId;
  final String eventType;
  final String? transactionId;
  final String timestamp;
  final String previousHash;
  final String dataHash;
  final String hash;
  final Map<String, dynamic> data;
  final bool recoverable;

  const IntegrityBlockItem({
    required this.index,
    required this.eventId,
    required this.eventType,
    this.transactionId,
    required this.timestamp,
    required this.previousHash,
    required this.dataHash,
    required this.hash,
    required this.data,
    required this.recoverable,
  });

  String get receiptNo {
    final raw = data['receipt_no'] ?? data['receiptNo'] ?? '';
    return raw.toString();
  }

  int get totalAmount {
    final val = data['total_idr'] ?? data['totalAmount'];
    if (val is num) return val.toInt();
    return 0;
  }

  String get cashierId {
    final raw = data['cashier_id'] ?? data['cashierId'] ?? '';
    return raw.toString();
  }

  bool get isGenesis =>
      index == 1 ||
      previousHash ==
          '0000000000000000000000000000000000000000000000000000000000000000';

  factory IntegrityBlockItem.fromJson(Map<String, dynamic> json) {
    return IntegrityBlockItem(
      index: (json['index'] as num?)?.toInt() ?? 0,
      eventId: json['eventId'] as String? ?? '',
      eventType: json['eventType'] as String? ?? 'sale',
      transactionId: json['transactionId'] as String?,
      timestamp: json['timestamp'] as String? ?? '',
      previousHash: json['previousHash'] as String? ?? '',
      dataHash: json['dataHash'] as String? ?? '',
      hash: json['hash'] as String? ?? '',
      data: (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      recoverable: json['recoverable'] as bool? ?? false,
    );
  }
}

class IntegrityValidation {
  final bool isValid;
  final String status;
  final String message;
  final Map<String, dynamic>? details;

  const IntegrityValidation({
    required this.isValid,
    required this.status,
    required this.message,
    this.details,
  });

  int? get tamperedBlockIndex {
    if (details == null) return null;
    final val = details!['blockIndex'];
    if (val is num) return val.toInt();
    return null;
  }

  factory IntegrityValidation.fromJson(Map<String, dynamic> json) {
    return IntegrityValidation(
      isValid: json['isValid'] as bool? ?? false,
      status: json['status'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? '',
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}
