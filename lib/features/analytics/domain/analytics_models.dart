import 'package:intl/intl.dart';

class AnalyticsOverviewModel {
  final int revenueIdr;
  final int subtotalIdr;
  final int discountIdr;
  final int transactionCount;
  final int avgBasketSizeIdr;
  final int? totalCostIdr;
  final int? grossProfitIdr;
  final int? grossMarginPct;

  const AnalyticsOverviewModel({
    required this.revenueIdr,
    required this.subtotalIdr,
    required this.discountIdr,
    required this.transactionCount,
    required this.avgBasketSizeIdr,
    this.totalCostIdr,
    this.grossProfitIdr,
    this.grossMarginPct,
  });

  factory AnalyticsOverviewModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverviewModel(
      revenueIdr: json['revenue_idr'] as int? ?? 0,
      subtotalIdr: json['subtotal_idr'] as int? ?? 0,
      discountIdr: json['discount_idr'] as int? ?? 0,
      transactionCount: json['transaction_count'] as int? ?? 0,
      avgBasketSizeIdr: json['avg_basket_size_idr'] as int? ?? 0,
      totalCostIdr: json['total_cost_idr'] as int?,
      grossProfitIdr: json['gross_profit_idr'] as int?,
      grossMarginPct: json['gross_margin_pct'] as int?,
    );
  }

  String get formattedRevenue {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(revenueIdr);
  }

  String get formattedGrossProfit {
    if (grossProfitIdr == null) return '-';
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(grossProfitIdr);
  }

  String get formattedAvgBasket {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(avgBasketSizeIdr);
  }
}

class SalesTrendPoint {
  final String date;
  final int revenueIdr;
  final int count;

  const SalesTrendPoint({
    required this.date,
    required this.revenueIdr,
    required this.count,
  });

  factory SalesTrendPoint.fromJson(Map<String, dynamic> json) {
    return SalesTrendPoint(
      date: json['date'] as String? ?? '',
      revenueIdr: json['revenue_idr'] as int? ?? 0,
      count: json['count'] as int? ?? 0,
    );
  }

  String get displayDay {
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('E', 'id_ID').format(parsed); // Sen, Sel, Rab, dll
    } catch (_) {
      return date;
    }
  }
}

class PeakHourPoint {
  final int hour;
  final String label;
  final int transactionCount;
  final int totalRevenueIdr;

  const PeakHourPoint({
    required this.hour,
    required this.label,
    required this.transactionCount,
    required this.totalRevenueIdr,
  });

  factory PeakHourPoint.fromJson(Map<String, dynamic> json) {
    return PeakHourPoint(
      hour: json['hour'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      transactionCount: json['transaction_count'] as int? ?? 0,
      totalRevenueIdr: json['total_revenue_idr'] as int? ?? 0,
    );
  }
}

class ShiftSummaryModel {
  final int todayRevenueIdr;
  final int cashRevenueIdr;
  final int qrisRevenueIdr;
  final int transactionCount;

  const ShiftSummaryModel({
    required this.todayRevenueIdr,
    required this.cashRevenueIdr,
    required this.qrisRevenueIdr,
    required this.transactionCount,
  });

  factory ShiftSummaryModel.fromJson(Map<String, dynamic> json) {
    return ShiftSummaryModel(
      todayRevenueIdr: json['today_revenue_idr'] as int? ?? 0,
      cashRevenueIdr: json['cash_revenue_idr'] as int? ?? 0,
      qrisRevenueIdr: json['qris_revenue_idr'] as int? ?? 0,
      transactionCount: json['transaction_count'] as int? ?? 0,
    );
  }

  String get formattedTodayRevenue {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(todayRevenueIdr);
  }

  String get formattedCashRevenue {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(cashRevenueIdr);
  }

  String get formattedQrisRevenue {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(qrisRevenueIdr);
  }
}
