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

  Future<CurrencyRateModel> getRates() async {
    final response = await _client.get<Map<String, dynamic>>('/fx/rates');
    final data = response.data?['data'] as Map<String, dynamic>;
    return CurrencyRateModel.fromJson(data);
  }

  Future<Map<String, dynamic>> convert({
    required num amount,
    String from = 'IDR',
    String to = 'USD',
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/fx/convert',
      queryParameters: {
        'amount': amount,
        'from': from,
        'to': to,
      },
    );
    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }
}
