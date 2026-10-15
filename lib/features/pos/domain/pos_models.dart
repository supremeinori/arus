import 'package:intl/intl.dart';

class PosCartItem {
  final String productId;
  final String productName;
  final String sku;
  final int unitPriceIdr;
  final int quantity;

  const PosCartItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unitPriceIdr,
    required this.quantity,
  });

  int get lineTotalIdr => unitPriceIdr * quantity;

  String get formattedUnitPrice {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(unitPriceIdr);
  }

  String get formattedLineTotal {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(lineTotalIdr);
  }

  PosCartItem copyWith({
    String? productId,
    String? productName,
    String? sku,
    int? unitPriceIdr,
    int? quantity,
  }) {
    return PosCartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      unitPriceIdr: unitPriceIdr ?? this.unitPriceIdr,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name_snapshot': productName,
      'sku': sku,
      'unit_price_idr': unitPriceIdr,
      'quantity': quantity,
      'line_total_idr': lineTotalIdr,
    };
  }
}

class PosTransactionModel {
  final String id;
  final String receiptNo;
  final String outletId;
  final String outletName;
  final String cashierName;
  final int subtotalIdr;
  final int discountIdr;
  final int totalIdr;
  final String paymentMethod;
  final int paidIdr;
  final int changeIdr;
  final String status;
  final String? voidReason;
  final DateTime createdAt;
  final List<PosCartItem> items;
  final bool isOfflinePending;
  final String? clientRequestId;

  const PosTransactionModel({
    required this.id,
    required this.receiptNo,
    required this.outletId,
    required this.outletName,
    required this.cashierName,
    required this.subtotalIdr,
    required this.discountIdr,
    required this.totalIdr,
    required this.paymentMethod,
    required this.paidIdr,
    required this.changeIdr,
    required this.status,
    this.voidReason,
    required this.createdAt,
    this.items = const [],
    this.isOfflinePending = false,
    this.clientRequestId,
  });

  factory PosTransactionModel.fromJson(Map<String, dynamic> json) {
    final outletObj = json['outlet'] as Map<String, dynamic>?;
    final cashierObj = json['cashier'] as Map<String, dynamic>?;
    final rawItems = json['items'] as List<dynamic>? ?? [];

    return PosTransactionModel(
      id: json['id'] as String? ?? '',
      receiptNo: json['receipt_no'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      outletName: outletObj?['name'] as String? ?? json['outlet_name'] as String? ?? 'Outlet',
      cashierName: cashierObj?['name'] as String? ?? json['cashier_name'] as String? ?? 'Kasir',
      subtotalIdr: json['subtotal_idr'] as int? ?? 0,
      discountIdr: json['discount_idr'] as int? ?? 0,
      totalIdr: json['total_idr'] as int? ?? 0,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paidIdr: json['paid_idr'] as int? ?? 0,
      changeIdr: json['change_idr'] as int? ?? 0,
      status: json['status'] as String? ?? 'completed',
      voidReason: json['void_reason'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      isOfflinePending: json['is_offline_pending'] as bool? ?? false,
      clientRequestId: json['client_request_id'] as String?,
      items: rawItems.map((item) {
        final m = item as Map<String, dynamic>;
        return PosCartItem(
          productId: m['product_id'] as String? ?? '',
          productName: m['product_name_snapshot'] as String? ?? m['product_name'] as String? ?? '',
          sku: m['sku'] as String? ?? '',
          unitPriceIdr: m['unit_price_idr'] as int? ?? 0,
          quantity: m['quantity'] as int? ?? 1,
        );
      }).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'receipt_no': receiptNo,
      'outlet_id': outletId,
      'outlet_name': outletName,
      'cashier_name': cashierName,
      'subtotal_idr': subtotalIdr,
      'discount_idr': discountIdr,
      'total_idr': totalIdr,
      'payment_method': paymentMethod,
      'paid_idr': paidIdr,
      'change_idr': changeIdr,
      'status': status,
      'void_reason': voidReason,
      'created_at': createdAt.toIso8601String(),
      'is_offline_pending': isOfflinePending,
      'client_request_id': clientRequestId,
      'items': items.map((i) => i.toJson()).toList(),
      'outlet': {'name': outletName},
      'cashier': {'name': cashierName},
    };
  }

  String get formattedTotal {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(totalIdr);
  }
}
