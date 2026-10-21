import 'package:intl/intl.dart';

/// Pemformat uang terpusat ARUS.
///
/// Semua data internal disimpan dalam IDR. Konversi hanya untuk tampilan.
/// Daftar kurs yang didukung: IDR, USD, EUR, SGD, JPY, MYR, GBP.
class MoneyFormatter {
  // Fallback rates (IDR-based) jika kurs live belum tersedia
  static const double fallbackUsdRate = 0.000062; // ~Rp 16.129
  static const double fallbackEurRate = 0.000058; // ~Rp 17.241
  static const double fallbackSgdRate = 0.000083; // ~Rp 12.048
  static const double fallbackJpyRate = 0.0094; // ~Rp 106
  static const double fallbackMyrRate = 0.00028; // ~Rp 3.571
  static const double fallbackGbpRate = 0.000049; // ~Rp 20.408

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
    symbol: 'EUR ',
    decimalDigits: 2,
  );

  static final NumberFormat _sgdFormat = NumberFormat.currency(
    locale: 'en_SG',
    symbol: 'S\$ ',
    decimalDigits: 2,
  );

  static final NumberFormat _jpyFormat = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: 'JPY ',
    decimalDigits: 0,
  );

  static final NumberFormat _myrFormat = NumberFormat.currency(
    locale: 'ms_MY',
    symbol: 'RM ',
    decimalDigits: 2,
  );

  static final NumberFormat _gbpFormat = NumberFormat.currency(
    locale: 'en_GB',
    symbol: 'GBP ',
    decimalDigits: 2,
  );

  /// Format [amountIdr] (nilai dalam IDR) ke string tampilan sesuai [currency].
  ///
  /// [rates] adalah peta kurs dari IDR ke mata uang lain (misal `{'USD': 0.000062}`).
  /// Jika null atau kurs tidak ditemukan, digunakan nilai fallback statis.
  static String format(
    num amountIdr, {
    String currency = 'IDR',
    Map<String, double>? rates,
  }) {
    switch (currency.toUpperCase()) {
      case 'USD':
        final rate = rates?['USD'] ?? fallbackUsdRate;
        return _usdFormat.format(amountIdr * rate);
      case 'EUR':
        final rate = rates?['EUR'] ?? fallbackEurRate;
        return _eurFormat.format(amountIdr * rate);
      case 'SGD':
        final rate = rates?['SGD'] ?? fallbackSgdRate;
        return _sgdFormat.format(amountIdr * rate);
      case 'JPY':
        final rate = rates?['JPY'] ?? fallbackJpyRate;
        return _jpyFormat.format(amountIdr * rate);
      case 'MYR':
        final rate = rates?['MYR'] ?? fallbackMyrRate;
        return _myrFormat.format(amountIdr * rate);
      case 'GBP':
        final rate = rates?['GBP'] ?? fallbackGbpRate;
        return _gbpFormat.format(amountIdr * rate);
      case 'IDR':
      default:
        return _idrFormat.format(amountIdr);
    }
  }
}
