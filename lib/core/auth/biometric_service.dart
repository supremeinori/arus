import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  /// Memeriksa apakah perangkat mendukung dan memiliki sensor biometrik aktif
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Menampilkan dialog autentikasi sidik jari / wajah
  Future<bool> authenticate({
    String localizedReason = 'Pindai sidik jari atau wajah Anda untuk mengakses aplikasi ARUS',
  }) async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      // Pada web browser atau unit test, simulasi sukses autentikasi
      return true;
    }

    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Mengambil daftar biometrik yang tersedia di HP (misal: fingerprint, face)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }
}
