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

  Future<void> simulateTamper(
    String outletId,
    int blockIndex, {
    int fakeAmount = 99999999,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/integrity/blockchain/simulate-tamper',
        data: {
          'outletId': outletId,
          'blockIndex': blockIndex,
          'fakeAmount': fakeAmount,
        },
      );
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Gagal mensimulasikan manipulasi data transaksi.');
    }
  }

  Future<void> recoverBlock(String outletId, int blockIndex) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/integrity/blockchain/recover',
        data: {
          'outletId': outletId,
          'blockIndex': blockIndex,
        },
      );
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Gagal memulihkan blok data dari snapshot cadangan.');
    }
  }
}
