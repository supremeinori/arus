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
  final bool isOffline;
  final int pendingCount;

  const AnalyticsOverviewModel({
    required this.revenueIdr,
    required this.subtotalIdr,
    required this.discountIdr,
    required this.transactionCount,
    required this.avgBasketSizeIdr,
    this.totalCostIdr,
    this.grossProfitIdr,
    this.grossMarginPct,
    this.isOffline = false,
    this.pendingCount = 0,
  });

  factory AnalyticsOverviewModel.fromJson(
    Map<String, dynamic> json, {
    bool isOffline = false,
    int pendingCount = 0,
  }) {
    return AnalyticsOverviewModel(
      revenueIdr: json['revenue_idr'] as int? ?? 0,
      subtotalIdr: json['subtotal_idr'] as int? ?? 0,
      discountIdr: json['discount_idr'] as int? ?? 0,
      transactionCount: json['transaction_count'] as int? ?? 0,
      avgBasketSizeIdr: json['avg_basket_size_idr'] as int? ?? 0,
      totalCostIdr: json['total_cost_idr'] as int?,
      grossProfitIdr: json['gross_profit_idr'] as int?,
      grossMarginPct: json['gross_margin_pct'] as int?,
      isOffline: isOffline,
      pendingCount: pendingCount,
    );
  }

  AnalyticsOverviewModel copyWith({
    int? revenueIdr,
    int? subtotalIdr,
    int? discountIdr,
    int? transactionCount,
    int? avgBasketSizeIdr,
    int? totalCostIdr,
    int? grossProfitIdr,
    int? grossMarginPct,
    bool? isOffline,
    int? pendingCount,
  }) {
    return AnalyticsOverviewModel(
      revenueIdr: revenueIdr ?? this.revenueIdr,
      subtotalIdr: subtotalIdr ?? this.subtotalIdr,
      discountIdr: discountIdr ?? this.discountIdr,
      transactionCount: transactionCount ?? this.transactionCount,
      avgBasketSizeIdr: avgBasketSizeIdr ?? this.avgBasketSizeIdr,
      totalCostIdr: totalCostIdr ?? this.totalCostIdr,
      grossProfitIdr: grossProfitIdr ?? this.grossProfitIdr,
      grossMarginPct: grossMarginPct ?? this.grossMarginPct,
      isOffline: isOffline ?? this.isOffline,
      pendingCount: pendingCount ?? this.pendingCount,
    );
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
  final bool isOffline;
  final int pendingCount;
  final bool isDataAvailable;

  const ShiftSummaryModel({
    required this.todayRevenueIdr,
    required this.cashRevenueIdr,
    required this.qrisRevenueIdr,
    required this.transactionCount,
    this.isOffline = false,
    this.pendingCount = 0,
    this.isDataAvailable = true,
  });

  factory ShiftSummaryModel.fromJson(Map<String, dynamic> json) {
    return ShiftSummaryModel(
      todayRevenueIdr: json['today_revenue_idr'] as int? ?? 0,
      cashRevenueIdr: json['cash_revenue_idr'] as int? ?? 0,
      qrisRevenueIdr: json['qris_revenue_idr'] as int? ?? 0,
      transactionCount: json['transaction_count'] as int? ?? 0,
      isOffline: json['is_offline'] as bool? ?? false,
      pendingCount: json['pending_count'] as int? ?? 0,
      isDataAvailable: json['is_data_available'] as bool? ?? true,
    );
  }
}

// =========================================================================
// AI PREDICTIVE MODELS
// =========================================================================

class ForecastPoint {
  final String date;
  final String dayName;
  final int revenueIdr;
  final int lowerBoundIdr;
  final int upperBoundIdr;
  final bool isProjected;

  const ForecastPoint({
    required this.date,
    required this.dayName,
    required this.revenueIdr,
    required this.lowerBoundIdr,
    required this.upperBoundIdr,
    required this.isProjected,
  });

  factory ForecastPoint.fromJson(Map<String, dynamic> json) {
    return ForecastPoint(
      date: json['date'] as String? ?? '',
      dayName: json['day_name'] as String? ?? '',
      revenueIdr: (json['revenue_idr'] as num?)?.toInt() ?? 0,
      lowerBoundIdr: (json['lower_bound_idr'] as num?)?.toInt() ?? 0,
      upperBoundIdr: (json['upper_bound_idr'] as num?)?.toInt() ?? 0,
      isProjected: json['is_projected'] as bool? ?? false,
    );
  }

}

class PeakProjectedDay {
  final String date;
  final String dayName;
  final int revenueIdr;

  const PeakProjectedDay({
    required this.date,
    required this.dayName,
    required this.revenueIdr,
  });

  factory PeakProjectedDay.fromJson(Map<String, dynamic> json) {
    return PeakProjectedDay(
      date: json['date'] as String? ?? '',
      dayName: json['day_name'] as String? ?? '',
      revenueIdr: (json['revenue_idr'] as num?)?.toInt() ?? 0,
    );
  }

}

class SalesForecastSummary {
  final int projectedTotalRevenueIdr;
  final int previousPeriodRevenueIdr;
  final double growthPct;
  final int avgDailyProjectedIdr;
  final PeakProjectedDay peakProjectedDay;
  final String aiInsight;

  const SalesForecastSummary({
    required this.projectedTotalRevenueIdr,
    required this.previousPeriodRevenueIdr,
    required this.growthPct,
    required this.avgDailyProjectedIdr,
    required this.peakProjectedDay,
    required this.aiInsight,
  });

  factory SalesForecastSummary.fromJson(Map<String, dynamic> json) {
    return SalesForecastSummary(
      projectedTotalRevenueIdr: (json['projected_total_revenue_idr'] as num?)?.toInt() ?? 0,
      previousPeriodRevenueIdr: (json['previous_period_revenue_idr'] as num?)?.toInt() ?? 0,
      growthPct: (json['growth_pct'] as num?)?.toDouble() ?? 0.0,
      avgDailyProjectedIdr: (json['avg_daily_projected_idr'] as num?)?.toInt() ?? 0,
      peakProjectedDay: PeakProjectedDay.fromJson(
        json['peak_projected_day'] as Map<String, dynamic>? ?? {},
      ),
      aiInsight: json['ai_insight'] as String? ?? '',
    );
  }


}

class SalesForecastModel {
  final int horizonDays;
  final List<ForecastPoint> historical;
  final List<ForecastPoint> forecast;
  final SalesForecastSummary summary;

  const SalesForecastModel({
    required this.horizonDays,
    required this.historical,
    required this.forecast,
    required this.summary,
  });

  factory SalesForecastModel.fromJson(Map<String, dynamic> json) {
    final histList = json['historical'] as List<dynamic>? ?? [];
    final fcstList = json['forecast'] as List<dynamic>? ?? [];

    return SalesForecastModel(
      horizonDays: json['horizon_days'] as int? ?? 7,
      historical: histList.map((e) => ForecastPoint.fromJson(e as Map<String, dynamic>)).toList(),
      forecast: fcstList.map((e) => ForecastPoint.fromJson(e as Map<String, dynamic>)).toList(),
      summary: SalesForecastSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class StockoutItem {
  final String ingredientId;
  final String ingredientName;
  final String unit;
  final String outletName;
  final int currentStock;
  final int reorderLevel;
  final double dailyVelocity;
  final int daysUntilStockout;
  final String projectedStockoutDate;
  final String status; // 'critical' | 'warning' | 'safe'
  final int stockCapacityPct;
  final int recommendedReorderQty;
  final int costPerUnitIdr;
  final int estimatedRestockCostIdr;

  const StockoutItem({
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.outletName,
    required this.currentStock,
    required this.reorderLevel,
    required this.dailyVelocity,
    required this.daysUntilStockout,
    required this.projectedStockoutDate,
    required this.status,
    required this.stockCapacityPct,
    required this.recommendedReorderQty,
    required this.costPerUnitIdr,
    required this.estimatedRestockCostIdr,
  });

  factory StockoutItem.fromJson(Map<String, dynamic> json) {
    return StockoutItem(
      ingredientId: json['ingredient_id'] as String? ?? '',
      ingredientName: json['ingredient_name'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      outletName: json['outlet_name'] as String? ?? '',
      currentStock: (json['current_stock'] as num?)?.toInt() ?? 0,
      reorderLevel: (json['reorder_level'] as num?)?.toInt() ?? 0,
      dailyVelocity: (json['daily_velocity'] as num?)?.toDouble() ?? 0.0,
      daysUntilStockout: (json['days_until_stockout'] as num?)?.toInt() ?? 0,
      projectedStockoutDate: json['projected_stockout_date'] as String? ?? '',
      status: json['status'] as String? ?? 'safe',
      stockCapacityPct: (json['stock_capacity_pct'] as num?)?.toInt() ?? 0,
      recommendedReorderQty: (json['recommended_reorder_qty'] as num?)?.toInt() ?? 0,
      costPerUnitIdr: (json['cost_per_unit_idr'] as num?)?.toInt() ?? 0,
      estimatedRestockCostIdr: (json['estimated_restock_cost_idr'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isCritical => status == 'critical';
  bool get isWarning => status == 'warning';
  bool get isSafe => status == 'safe';

}

class StockoutSummary {
  final int criticalCount;
  final int warningCount;
  final int safeCount;
  final int totalItems;
  final String aiRecommendation;

  const StockoutSummary({
    required this.criticalCount,
    required this.warningCount,
    required this.safeCount,
    required this.totalItems,
    required this.aiRecommendation,
  });

  factory StockoutSummary.fromJson(Map<String, dynamic> json) {
    return StockoutSummary(
      criticalCount: (json['critical_count'] as num?)?.toInt() ?? 0,
      warningCount: (json['warning_count'] as num?)?.toInt() ?? 0,
      safeCount: (json['safe_count'] as num?)?.toInt() ?? 0,
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      aiRecommendation: json['ai_recommendation'] as String? ?? '',
    );
  }
}

class StockoutForecastModel {
  final StockoutSummary summary;
  final List<StockoutItem> items;

  const StockoutForecastModel({
    required this.summary,
    required this.items,
  });

  factory StockoutForecastModel.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return StockoutForecastModel(
      summary: StockoutSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
      items: list.map((e) => StockoutItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class TopSellingProductModel {
  final int rank;
  final String productId;
  final String productName;
  final String categoryName;
  final int quantitySold;
  final int totalRevenueIdr;
  final int unitPriceIdr;
  final String? imageUrl;

  const TopSellingProductModel({
    required this.rank,
    required this.productId,
    required this.productName,
    required this.categoryName,
    required this.quantitySold,
    required this.totalRevenueIdr,
    required this.unitPriceIdr,
    this.imageUrl,
  });

  factory TopSellingProductModel.fromJson(Map<String, dynamic> json) {
    return TopSellingProductModel(
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      categoryName: json['category_name'] as String? ?? 'Menu Utama',
      quantitySold: (json['quantity_sold'] as num?)?.toInt() ?? 0,
      totalRevenueIdr: (json['total_revenue_idr'] as num?)?.toInt() ?? 0,
      unitPriceIdr: (json['unit_price_idr'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String?,
    );
  }
}
