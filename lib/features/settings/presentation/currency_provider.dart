import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/prefs_store.dart';
import '../../../core/utils/money_formatter.dart';
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
// Display Currency — Notifier dengan persistensi per-user ke backend API
// ---------------------------------------------------------------------------

/// Notifier yang menyimpan preferensi mata uang tampilan per pengguna.
///
/// Urutan prioritas nilai saat build:
///   1. Nilai dari [authProvider] (berasal dari server = kolom
///      `User.display_currency`, paling akurat).
///   2. Nilai cache lokal milik akun tersebut (tersedia offline).
///   3. Fallback ke [MoneyFormatter.defaultCurrency].
///
/// Saat pengguna mengubah pilihan:
///   - State Riverpod diperbarui seketika (UI responsif).
///   - Pilihan disimpan ke backend lewat `PATCH /users/me/settings`.
///   - Bila penyimpanan gagal, state dikembalikan ke nilai sebelumnya agar
///     tampilan tidaklasting bohong soal pilihan yang tersimpan.
class DisplayCurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    // Prioritas 1: dari user yang sedang login (nilai dari server via AuthNotifier)
    final authState = ref.watch(authProvider);
    final userId = authState.user?.id ?? '';
    final serverCurrency = authState.user?.settings.displayCurrency;
    if (serverCurrency != null && serverCurrency.isNotEmpty) {
      // Sinkronkan ke cache lokal agar tersedia offline
      _persistLocal(userId, serverCurrency);
      return serverCurrency;
    }

    // Prioritas 2: dari cache lokal milik akun ini saja (bukan akun lain)
    if (userId.isNotEmpty) {
      final local = _readLocal(userId);
      if (local != null && local.isNotEmpty) {
        return local;
      }
    }

    // Prioritas 3: fallback default
    return MoneyFormatter.defaultCurrency;
  }

  /// Ganti mata uang tampilan: simpan ke backend, lalu perbarui state.
  ///
  /// Mengembalikan `true` bila berhasil tersimpan di server.
  Future<bool> setCurrency(String currency) async {
    if (currency == state) return true;

    final previous = state;
    state = currency; // optimistic update supaya UI langsung berubah
    _persistLocal(_currentUserId(), currency);

    try {
      await _syncToBackend(currency);
    } catch (_) {
      // Gagal simpan ke backend: kembalikan nilai sebelumnya.
      state = previous;
      _persistLocal(_currentUserId(), previous);
      return false;
    }

    // Penyimpanan berhasil -> teruskan ke state sesi (auth) supaya semua
    // widget yang membaca authProvider ikut ter-update tanpa reload.
    await ref.read(authProvider.notifier).applyDisplayCurrency(currency);
    return true;
  }

  String _currentUserId() => ref.read(authProvider).user?.id ?? '';

  String? _readLocal(String userId) {
    try {
      final prefs = ref.read(prefsStoreProvider);
      return prefs.displayCurrencyFor(userId);
    } catch (_) {
      return null;
    }
  }

  void _persistLocal(String userId, String currency) {
    try {
      final prefs = ref.read(prefsStoreProvider);
      prefs.setDisplayCurrencyFor(userId, currency);
    } catch (_) {}
  }

  Future<void> _syncToBackend(String currency) async {
    final client = ref.read(apiClientProvider);
    await client.patch<void>(
      '/users/me/settings',
      data: {'display_currency': currency},
    );
  }
}

final displayCurrencyProvider =
    NotifierProvider<DisplayCurrencyNotifier, String>(
  DisplayCurrencyNotifier.new,
);

// ---------------------------------------------------------------------------
// Formatter uang terpusat (currency-aware)
// ---------------------------------------------------------------------------

/// Formatter uang yang mengikuti mata uang + kurs milik pengguna aktif.
///
/// Semua nominal ARUS tetap IDR di dalam data; konversi hanya di tampilan.
final moneyFormatterProvider = Provider<String Function(num)>((ref) {
  final currency = ref.watch(displayCurrencyProvider);
  final rates = ref.watch(fxRatesProvider).valueOrNull?.rates;
  return (amountIdr) =>
      MoneyFormatter.format(amountIdr, currency: currency, rates: rates);
});

/// Format nominal di dalam widget: `Text(ref.money(product.priceIdr))`.
///
/// Otomatis mengikuti perubahan mata uang dan kurs terbaru.
extension CurrencyMoney on WidgetRef {
  String money(num amountIdr) {
    final formatter = watch(moneyFormatterProvider);
    return formatter(amountIdr);
  }
}

// ---------------------------------------------------------------------------
// Display Timezone — tetap StateProvider sederhana
// ---------------------------------------------------------------------------

final displayTimezoneProvider = StateProvider<String>((ref) => 'Asia/Jakarta');
