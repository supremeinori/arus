import 'package:intl/intl.dart';

class MoneyFormatter {
  static const double fallbackUsdRate = 0.000062;
  static const double fallbackEurRate = 0.000058;

  static final NumberFormat _idrFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _usdFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 2,
  );

  static final NumberFormat _eurFormat = NumberFormat.currency(
    locale: 'de_DE',
    symbol: '€ ',
    decimalDigits: 2,
  );

  static String format(
    num amountIdr, {
    String currency = 'IDR',
    Map<String, double>? rates,
  }) {
    switch (currency.toUpperCase()) {
      case 'USD':
        final rate = rates?['USD'] ?? fallbackUsdRate;
        final converted = amountIdr * rate;
        return _usdFormat.format(converted);
      case 'EUR':
        final rate = rates?['EUR'] ?? fallbackEurRate;
        final converted = amountIdr * rate;
        return _eurFormat.format(converted);
      case 'IDR':
      default:
        return _idrFormat.format(amountIdr);
    }
  }
}
