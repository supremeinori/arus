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
    },
  );

  Future<CurrencyRateModel> getRates() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/fx/rates');
      final data = response.data?['data'] as Map<String, dynamic>;
      return CurrencyRateModel.fromJson(data);
    } catch (_) {
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
