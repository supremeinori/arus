import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/fx_repository.dart';
import '../domain/currency_models.dart';

final fxRatesProvider = FutureProvider.autoDispose<CurrencyRateModel>((ref) async {
  final repo = ref.watch(fxRepositoryProvider);
  return repo.getRates();
});

final displayCurrencyProvider = StateProvider<String>((ref) => 'IDR');
final displayTimezoneProvider = StateProvider<String>((ref) => 'Asia/Jakarta');
