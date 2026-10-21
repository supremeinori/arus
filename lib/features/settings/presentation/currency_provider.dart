import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/prefs_store.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/fx_repository.dart';
import '../domain/currency_models.dart';

// ---------------------------------------------------------------------------
// FX Rates Provider
// ---------------------------------------------------------------------------

final fxRatesProvider = FutureProvider.autoDispose<CurrencyRateModel>((ref) async {
  final repo = ref.watch(fxRepositoryProvider);
  return repo.getRates();
});

// ---------------------------------------------------------------------------
// Display Currency — Notifier dengan persistensi ke PrefsStore + backend API
// ---------------------------------------------------------------------------

/// Notifier yang menyimpan preferensi mata uang tampilan per pengguna.
///
/// Urutan prioritas nilai saat build:
///   1. Nilai dari [authProvider] (berasal dari server, paling akurat).
///   2. Nilai dari SharedPreferences (tersedia offline tanpa jaringan).
///   3. Fallback ke 'IDR'.
///
/// Saat pengguna mengubah pilihan:
///   - Langsung update state Riverpod (UI responsif instan).
///   - Simpan ke SharedPreferences (persisten lintas restart offline).
///   - Kirim PATCH /users/me/settings ke backend (persisten di server).
class DisplayCurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    // Prioritas 1: dari user yang sedang login (nilai dari server via AuthNotifier)
    final authState = ref.watch(authProvider);
    final serverCurrency = authState.user?.settings.displayCurrency;
    if (serverCurrency != null && serverCurrency.isNotEmpty) {
      // Sinkronkan ke local prefs agar tersedia offline
      _persistLocal(serverCurrency);
      return serverCurrency;
    }

    // Prioritas 2: dari SharedPreferences
    try {
      final prefs = ref.watch(prefsStoreProvider);
      return prefs.displayCurrency;
    } catch (_) {}

    // Prioritas 3: fallback default
    return 'IDR';
  }

  /// Ganti mata uang tampilan, simpan lokal, lalu sync ke backend.
  Future<void> setCurrency(String currency) async {
    if (state == currency) return;
    state = currency;
    _persistLocal(currency);
    await _syncToBackend(currency);
  }

  void _persistLocal(String currency) {
    try {
      final prefs = ref.read(prefsStoreProvider);
      prefs.setDisplayCurrency(currency);
    } catch (_) {}
  }

  Future<void> _syncToBackend(String currency) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.patch<void>(
        '/users/me/settings',
        data: {'display_currency': currency},
      );
    } catch (_) {
      // Gagal sync ke backend tidak memblokir UI — nilai lokal tetap tersimpan
    }
  }
}

final displayCurrencyProvider =
    NotifierProvider<DisplayCurrencyNotifier, String>(
  DisplayCurrencyNotifier.new,
);

// ---------------------------------------------------------------------------
// Display Timezone — tetap StateProvider sederhana
// ---------------------------------------------------------------------------

final displayTimezoneProvider = StateProvider<String>((ref) => 'Asia/Jakarta');
