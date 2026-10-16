import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../domain/integrity_models.dart';

final integrityRepositoryProvider = Provider<IntegrityRepository>((ref) {
  return IntegrityRepository(ref.watch(apiClientProvider));
});

class IntegrityRepository {
  final ApiClient _client;

  IntegrityRepository(this._client);

  Future<IntegrityChainSnapshot> getChain(String outletId) async {
    try {
      final responses = await Future.wait([
        _client.get<Map<String, dynamic>>(
          '/integrity/blockchain/chain/$outletId',
        ),
        _client.get<Map<String, dynamic>>(
          '/integrity/blockchain/verify/$outletId',
        ),
      ]);
      final chainEnvelope = responses[0].data;
      final validationEnvelope = responses[1].data;
      final chainData = chainEnvelope?['data'] as Map<String, dynamic>?;
      final validationData =
          validationEnvelope?['data'] as Map<String, dynamic>?;
      if (chainData == null || validationData == null) {
        throw AppException('Respons ledger dari server tidak lengkap.');
      }
      return IntegrityChainSnapshot(
        overview: IntegrityChainOverview.fromJson(chainData),
        validation: IntegrityValidation.fromJson(validationData),
      );
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Tidak dapat memuat ledger integritas outlet.');
    }
  }

  Future<void> closeCurrentDay(String outletId) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/integrity/blockchain/close-day',
        data: {'outletId': outletId},
      );
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Tidak dapat menutup rantai transaksi hari ini.');
    }
  }
}
