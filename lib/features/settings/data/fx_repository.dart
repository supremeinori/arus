import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/currency_models.dart';

final fxRepositoryProvider = Provider<FxRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return FxRepository(client);
});

class FxRepository {
  final ApiClient _client;

  FxRepository(this._client);

  static const CurrencyRateModel _fallbackRates = CurrencyRateModel(
    base: 'IDR',
    asOf: '2026-10-07T12:00:00Z',
    rates: {
      'IDR': 1.0,
      'USD': 0.0000625,
      'EUR': 0.0000588,
      'SGD': 0.0000833,
      'JPY': 0.00943,
      'MYR': 0.00028,
      'GBP': 0.000049,
    },
  );

  Future<CurrencyRateModel> getRates() async {
    // 1. Coba ambil dari public live open rate API (gratis tanpa key)
    try {
      final publicDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final resp = await publicDio.get('https://open.er-api.com/v6/latest/IDR');
      if (resp.statusCode == 200 && resp.data is Map<String, dynamic>) {
        final data = resp.data as Map<String, dynamic>;
        final rawRates = data['rates'] as Map<String, dynamic>? ?? {};
        final mappedRates = <String, double>{};
        rawRates.forEach((key, val) {
          if (val is num) mappedRates[key] = val.toDouble();
        });
        if (mappedRates.containsKey('USD') && mappedRates.containsKey('EUR')) {
          return CurrencyRateModel(
            base: data['base_code'] as String? ?? 'IDR',
            asOf: data['time_last_update_utc'] as String? ?? DateTime.now().toIso8601String(),
            rates: mappedRates,
          );
        }
      }
    } catch (_) {}

    // 2. Coba ambil dari backend ARUS
    try {
      final response = await _client.get<Map<String, dynamic>>('/fx/rates');
      final data = response.data?['data'] as Map<String, dynamic>;
      return CurrencyRateModel.fromJson(data);
    } catch (_) {
      // 3. Fallback offline statis
      return _fallbackRates;
    }
  }

  Future<Map<String, dynamic>> convert({
    required num amount,
    String from = 'IDR',
    String to = 'USD',
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/fx/convert',
        queryParameters: {
          'amount': amount,
          'from': from,
          'to': to,
        },
      );
      return response.data?['data'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      final rate = _fallbackRates.rates[to] ?? 1.0;
      final converted = amount * rate;
      return {
        'from': from,
        'to': to,
        'amount': amount,
        'converted': converted,
        'rate': rate,
      };
    }
  }
}
