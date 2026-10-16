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
  final int totalDays;
  final int currentActiveTxCount;
  final List<IntegrityDailyBlock> days;

  const IntegrityChainOverview({
    required this.outletId,
    required this.totalDays,
    required this.currentActiveTxCount,
    required this.days,
  });

  factory IntegrityChainOverview.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? const [];
    return IntegrityChainOverview(
      outletId: json['outletId'] as String? ?? '',
      totalDays: (json['totalDays'] as num?)?.toInt() ?? 0,
      currentActiveTxCount:
          (json['currentActiveTxCount'] as num?)?.toInt() ?? 0,
      days: rawDays
          .whereType<Map<String, dynamic>>()
          .map(IntegrityDailyBlock.fromJson)
          .toList(growable: false),
    );
  }
}

class IntegrityDailyBlock {
  final int dayIndex;
  final String date;
  final String parentHash;
  final String previousParentHash;
  final String merkleRoot;
  final String timestamp;
  final int transactionCount;
  final List<IntegrityTransactionBlock> transactions;

  const IntegrityDailyBlock({
    required this.dayIndex,
    required this.date,
    required this.parentHash,
    required this.previousParentHash,
    required this.merkleRoot,
    required this.timestamp,
    required this.transactionCount,
    required this.transactions,
  });

  factory IntegrityDailyBlock.fromJson(Map<String, dynamic> json) {
    final rawTransactions = json['transactions'] as List<dynamic>? ?? const [];
    return IntegrityDailyBlock(
      dayIndex: (json['dayIndex'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      parentHash: json['parentHash'] as String? ?? '',
      previousParentHash: json['previousParentHash'] as String? ?? '',
      merkleRoot: json['merkleRoot'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      transactionCount:
          (json['transactionCount'] as num?)?.toInt() ?? rawTransactions.length,
      transactions: rawTransactions
          .whereType<Map<String, dynamic>>()
          .map(IntegrityTransactionBlock.fromJson)
          .toList(growable: false),
    );
  }
}

class IntegrityTransactionBlock {
  final int index;
  final String timestamp;
  final String hash;
  final String previousHash;
  final String receiptNo;
  final int totalAmount;
  final String cashierId;
  final String eventType;
  final String sourceId;

  const IntegrityTransactionBlock({
    required this.index,
    required this.timestamp,
    required this.hash,
    required this.previousHash,
    required this.receiptNo,
    required this.totalAmount,
    required this.cashierId,
    required this.eventType,
    required this.sourceId,
  });

  factory IntegrityTransactionBlock.fromJson(Map<String, dynamic> json) {
    return IntegrityTransactionBlock(
      index: (json['index'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] as String? ?? '',
      hash: json['hash'] as String? ?? '',
      previousHash: json['previousHash'] as String? ?? '',
      receiptNo: json['receiptNo'] as String? ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toInt() ?? 0,
      cashierId: json['cashierId'] as String? ?? '',
      eventType: json['eventType'] as String? ?? 'sale',
      sourceId: json['sourceId'] as String? ?? '',
    );
  }
}

class IntegrityValidation {
  final bool isValid;
  final String status;
  final String message;

  const IntegrityValidation({
    required this.isValid,
    required this.status,
    required this.message,
  });

  factory IntegrityValidation.fromJson(Map<String, dynamic> json) {
    return IntegrityValidation(
      isValid: json['isValid'] as bool? ?? false,
      status: json['status'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? '',
    );
  }
}
