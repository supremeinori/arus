class BusinessInsightModel {
  final String id;
  final String ruleCode;
  final String severity; // 'info' | 'warning' | 'critical'
  final String? outletId;
  final String? outletName;
  final String? productId;
  final String? productName;
  final String title;
  final String message;
  final Map<String, dynamic> evidence;
  final String recommendation;
  final String status; // 'new' | 'acknowledged' | 'dismissed'
  final DateTime createdAt;

  const BusinessInsightModel({
    required this.id,
    required this.ruleCode,
    required this.severity,
    this.outletId,
    this.outletName,
    this.productId,
    this.productName,
    required this.title,
    required this.message,
    this.evidence = const {},
    required this.recommendation,
    required this.status,
    required this.createdAt,
  });

  factory BusinessInsightModel.fromJson(Map<String, dynamic> json) {
    final outletObj = json['outlet'] as Map<String, dynamic>?;
    final prodObj = json['product'] as Map<String, dynamic>?;

    return BusinessInsightModel(
      id: json['id'] as String? ?? '',
      ruleCode: json['rule_code'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
      outletId: json['outlet_id'] as String?,
      outletName: outletObj?['name'] as String?,
      productId: json['product_id'] as String?,
      productName: prodObj?['name'] as String?,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      evidence: json['evidence'] as Map<String, dynamic>? ?? {},
      recommendation: json['recommendation'] as String? ?? '',
      status: json['status'] as String? ?? 'new',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';
}
