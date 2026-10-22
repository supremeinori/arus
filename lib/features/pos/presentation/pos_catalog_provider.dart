import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../data/pos_catalog_repository.dart';
import '../data/pos_repository.dart';
import '../domain/pos_models.dart';

/// Resolve outlet aktif kasir satu pintu: staff/manager terkunci ke outlet
/// pertama; owner mengikuti filter dashboard (fallback outlet pertama).
final posOutletIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null || user.outlets.isEmpty) return null;
  final forced = ref.watch(activePosOutletProvider);
  if (forced != null && forced.isNotEmpty) return forced;
  final selected = ref.watch(selectedOutletFilterProvider);
  if (selected != null && selected.isNotEmpty) return selected;
  return user.outlets.first.id;
});

/// Katalog kasir dari GET /api/pos/catalog — produk + is_available/max_portions.
final posCatalogProvider =
    FutureProvider.autoDispose<List<PosCatalogItem>>((ref) async {
  final outletId = ref.watch(posOutletIdProvider);
  if (outletId == null || outletId.isEmpty) return [];
  final repo = ref.watch(posCatalogRepositoryProvider);
  return repo.getCatalog(outletId);
});

/// Riwayat transaksi untuk layar POS: scoped ke outlet kasir yang aktif.
/// Dipakai tab riwayat di dalam mesin kasir (tidak ikut filter dashboard).
final posHistoryProvider =
    FutureProvider.autoDispose<List<PosTransactionModel>>((ref) async {
  final outletId = ref.watch(posOutletIdProvider);
  final repo = ref.watch(posRepositoryProvider);
  return repo.getTransactions(outletId: outletId);
});

/// Riwayat transaksi untuk halaman Riwayat Transaksi yang dibuka dari
/// Dashboard: mengikuti filter dashboard (cabang & periode).
/// Owner: boleh "Semua Cabang" atau cabang tertentu.
/// Manager/Staff: backend mengunci ke cabang yang di-assign.
final dashboardHistoryProvider =
    FutureProvider.autoDispose<List<PosTransactionModel>>((ref) async {
  final outletId = getEffectiveOutletId(ref);
  final range = resolveDashboardDateRange(
    ref.watch(selectedDateFilterProvider),
    ref.watch(selectedCustomDateProvider),
  );
  final repo = ref.watch(posRepositoryProvider);
  return repo.getTransactions(
    outletId: outletId,
    from: range.from,
    to: range.to,
  );
});
