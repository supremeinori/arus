import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/integrity_repository.dart';
import '../domain/integrity_models.dart';

final integrityChainProvider = FutureProvider.autoDispose
    .family<IntegrityChainSnapshot, String>((ref, outletId) {
      return ref.watch(integrityRepositoryProvider).getChain(outletId);
    });
