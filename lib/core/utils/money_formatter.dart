import 'package:intl/intl.dart';

/// Pemformat uang terpusat ARUS.
///
/// Semua data internal (database, API, perhitungan) tetap disimpan dalam IDR.
/// Konversi ke mata uang lain HANYA untuk tampilan.
class MoneyFormatter {
  /// Mata uang default bisnis. Semua nominal internal tetap IDR.
  static const String defaultCurrency = 'IDR';

  /// Mata uang yang didukung untuk tampilan. Harus sinkron dengan
  /// `SUPPORTED_CURRENCIES` di `api/src/modules/users/users.schema.ts`.
  static const List<String> supportedCurrencies = [
    'IDR',
    'USD',
    'EUR',
    'SGD',
    'JPY',
    'MYR',
    'GBP',
  ];

  // Fallback rates (IDR-based) jika kurs live belum tersedia.
  static const double fallbackUsdRate = 0.0000559; // 1 USD ≈ Rp 17.885
  static const double fallbackEurRate = 0.0000499; // 1 EUR ≈ Rp 20.037
  static const double fallbackSgdRate = 0.0001786; // 1 SGD ≈ Rp 5.599
  static const double fallbackJpyRate = 0.0088492; // 1 JPY ≈ Rp 112,99
  static const double fallbackMyrRate = 0.0002284; // 1 MYR ≈ Rp 4.378
  static const double fallbackGbpRate = 0.0000423; // 1 GBP ≈ Rp 23.636

  /// Kurs fallback (basis IDR) bila API kurs tidak tersedia.
  static const Map<String, double> fallbackRates = {
    'IDR': 1,
    'USD': fallbackUsdRate,
    'EUR': fallbackEurRate,
    'SGD': fallbackSgdRate,
    'JPY': fallbackJpyRate,
    'MYR': fallbackMyrRate,
    'GBP': fallbackGbpRate,
  };

  /// Label lengkap tiap mata uang untuk ditampilkan di UI.
  static const Map<String, String> currencyLabels = {
    'IDR': 'Rupiah Indonesia (IDR)',
    'USD': 'Dolar Amerika Serikat (USD)',
    'EUR': 'Euro Uni Eropa (EUR)',
    'SGD': 'Dolar Singapura (SGD)',
    'JPY': 'Yen Jepang (JPY)',
    'MYR': 'Ringgit Malaysia (MYR)',
    'GBP': 'Pound Sterling (GBP)',
  };

  /// Contoh nominal per mata uang untuk pratinjau format.
  static const Map<String, num> currencySamples = {
    'IDR': 2500000,
    'USD': 155,
    'EUR': 145,
    'SGD': 210,
    'JPY': 24000,
    'MYR': 700,
    'GBP': 125,
  };

  static final Map<String, NumberFormat> _formats = {
    'IDR': NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0),
    'USD': NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2),
    'EUR': NumberFormat.currency(locale: 'de_DE', symbol: 'EUR ', decimalDigits: 2),
    'SGD': NumberFormat.currency(locale: 'en_SG', symbol: 'S\$ ', decimalDigits: 2),
    'JPY': NumberFormat.currency(locale: 'ja_JP', symbol: 'JPY ', decimalDigits: 0),
    'MYR': NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ', decimalDigits: 2),
    'GBP': NumberFormat.currency(locale: 'en_GB', symbol: 'GBP ', decimalDigits: 2),
  };

  static final Map<String, String> _symbols = {
    'IDR': 'Rp ',
    'USD': '\$',
    'EUR': 'EUR ',
    'SGD': 'S\$ ',
    'JPY': 'JPY ',
    'MYR': 'RM ',
    'GBP': 'GBP ',
  };

  /// Format [amountIdr] (nilai dalam IDR) ke string tampilan sesuai [currency].
  ///
  /// [rates] adalah peta kurs dari IDR ke mata uang lain (misal `{'USD': 0.0000559}`).
  /// Jika null atau kurs tidak ditemukan, digunakan nilai fallback statis.
  static String format(
    num amountIdr, {
    String currency = defaultCurrency,
    Map<String, double>? rates,
  }) {
    final code = currency.toUpperCase();
    if (code == 'IDR') return _formatFor('IDR').format(amountIdr);

    final value = amountIdr * _rateFor(code, rates);
    return _formatFor(code).format(value);
  }

  /// Format nominal yang SUDAH berada dalam [currency] (tanpa konversi).
  ///
  /// Dipakai untuk nominal yang sudah dikonversi (mis. hasil kalkulator kurs).
  static String formatInCurrency(
    num amount, {
    required String currency,
  }) {
    return _formatFor(currency.toUpperCase()).format(amount);
  }

  /// Gaya "kartu omzet": simbol rupiah tanpa spasi ("Rp.17.000.000").
  ///
  /// Untuk mata uang selain IDR string tidak berubah.
  static String dottedIdrSymbol(String formatted) {
    return formatted.replaceFirst('Rp ', 'Rp.');
  }

  /// Format ringkas untuk sumbu grafik (mis. '1,2jt', 'Rp 2,5jt', '12K').
  ///
  /// [amountIdr] adalah nilai dalam IDR, lalu dikonversi ke [currency] bila perlu.
  static String formatCompact(
    num amountIdr, {
    String currency = defaultCurrency,
    Map<String, double>? rates,
  }) {
    final code = currency.toUpperCase();
    final value = code == 'IDR' ? amountIdr : amountIdr * _rateFor(code, rates);
    if (value <= 0) return '0';
    if (value >= 1000000000) {
      final v = value / 1000000000;
      final t = v.toStringAsFixed(v >= 10 ? 0 : 1).replaceAll('.0', '');
      return '$t${code == 'IDR' ? 'M' : 'B'}';
    } else if (value >= 1000000) {
      final v = value / 1000000;
      final t = v.toStringAsFixed(v >= 10 ? 0 : 1).replaceAll('.0', '');
      return '$t${code == 'IDR' ? 'jt' : 'M'}';
    } else if (value >= 1000) {
      final v = value / 1000;
      return '${v.toStringAsFixed(0)}${code == 'IDR' ? 'rb' : 'K'}';
    }
    return value.round().toString();
  }

  /// Simbol mata uang untuk [currency] (mis. 'Rp ', '\$', 'EUR ').
  static String symbolOf(String currency) {
    return _symbols[currency.toUpperCase()] ?? '${currency.toUpperCase()} ';
  }

  /// Kurs IDR -> [code] dari peta [rates], dengan fallback statis.
  static double _rateFor(String code, Map<String, double>? rates) {
    final live = rates?[code];
    if (live != null && live > 0) return live;
    return fallbackRates[code] ?? 1;
  }

  static NumberFormat _formatFor(String code) {
    return _formats[code] ?? _formats[defaultCurrency]!;
  }
}
