class CurrencyRateModel {
  final String base;
  final String asOf;
  final Map<String, double> rates;

  const CurrencyRateModel({
    required this.base,
    required this.asOf,
    required this.rates,
  });

  factory CurrencyRateModel.fromJson(Map<String, dynamic> json) {
    final rawRates = json['rates'] as Map<String, dynamic>? ?? {};
    final mappedRates = <String, double>{};
    rawRates.forEach((key, val) {
      mappedRates[key] = (val as num).toDouble();
    });

    return CurrencyRateModel(
      base: json['base'] as String? ?? 'IDR',
      asOf: json['as_of'] as String? ?? '',
      rates: mappedRates,
    );
  }
}
