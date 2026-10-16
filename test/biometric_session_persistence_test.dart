import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/domain/auth_response.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/core/auth/biometric_service.dart';

class MockAuthRepo implements AuthRepository {
  @override
  Future<AuthResponse> login(String email, String password) async {
    return const AuthResponse(
      accessToken: 'acc-123',
      refreshToken: 'ref-123',
      expiresIn: 900,
      user: UserModel(
        id: 'u-1',
        name: 'Ahmad Owner',
        email: 'ahmad@arus.id',
        role: UserRole.owner,
        settings: UserSettingsSummary(biometricEnabled: true),
      ),
    );
  }

  @override
  Future<AuthResponse> refresh(String refreshToken) async {
    return const AuthResponse(
      accessToken: 'acc-new',
      refreshToken: 'ref-new',
      expiresIn: 900,
      user: UserModel(
        id: 'u-1',
        name: 'Ahmad Owner',
        email: 'ahmad@arus.id',
        role: UserRole.owner,
        settings: UserSettingsSummary(biometricEnabled: true),
      ),
    );
  }

  @override
  Future<void> logout([String? refreshToken]) async {}

  @override
  Future<UserModel> getMe() async {
    return const UserModel(
      id: 'u-1',
      name: 'Ahmad Owner',
      email: 'ahmad@arus.id',
      role: UserRole.owner,
    );
  }
}

class FakeBiometricService extends BiometricService {
  bool shouldSucceed = true;

  @override
  Future<bool> isBiometricAvailable() async => true;

  @override
  Future<bool> authenticate({String localizedReason = ''}) async => shouldSucceed;
}

void main() {
  group('Biometric & Cold Start Session Persistence Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('SecureStore menyimpan dan membaca token, userJson, biometric_enabled, dan cek expired 7 hari', () async {
      final store = SecureStore();
      expect(await store.hasValidStoredSession(), isFalse);
      expect(await store.isBiometricEnabled(), isFalse);

      const user = UserModel(
        id: 'usr-1',
        name: 'Test User',
        email: 'test@arus.id',
        role: UserRole.owner,
      );

      await store.saveSession(
        accessToken: 'access-xyz',
        refreshToken: 'refresh-xyz',
        userJson: jsonEncode(user.toJson()),
        biometricEnabled: true,
      );

      expect(await store.hasValidStoredSession(), isTrue);
      expect(await store.getAccessToken(), 'access-xyz');
      expect(await store.getRefreshToken(), 'refresh-xyz');
      expect(await store.isBiometricEnabled(), isTrue);
      expect(await store.isSessionExpired(), isFalse);
    });

    test('Pembatalan biometrik TIDAK menghapus sesi di SecureStore', () async {
      final store = SecureStore();
      const user = UserModel(
        id: 'usr-1',
        name: 'Test User',
        email: 'test@arus.id',
        role: UserRole.owner,
        settings: UserSettingsSummary(biometricEnabled: true),
      );

      await store.saveSession(
        accessToken: 'access-xyz',
        refreshToken: 'refresh-xyz',
        userJson: jsonEncode(user.toJson()),
        biometricEnabled: true,
      );

      final fakeBio = FakeBiometricService()..shouldSucceed = false;
      final authNotifier = AuthNotifier(
        MockAuthRepo(),
        store,
        null,
        fakeBio,
      );

      final success = await authNotifier.authenticateWithBiometric();
      expect(success, isFalse);

      // Sesi tetap ada dan tidak terhapus walau dibatalkan!
      expect(await store.hasValidStoredSession(), isTrue);
      expect(await store.getRefreshToken(), 'refresh-xyz');
      expect(await store.isBiometricEnabled(), isTrue);
    });

    test('Logout secara eksplisit menghapus token dan sesi dari SecureStore', () async {
      final store = SecureStore();
      const user = UserModel(
        id: 'usr-1',
        name: 'Test User',
        email: 'test@arus.id',
        role: UserRole.owner,
      );

      await store.saveSession(
        accessToken: 'access-xyz',
        refreshToken: 'refresh-xyz',
        userJson: jsonEncode(user.toJson()),
        biometricEnabled: true,
      );

      final authNotifier = AuthNotifier(MockAuthRepo(), store);
      await authNotifier.logout();

      expect(await store.hasValidStoredSession(), isFalse);
      expect(await store.getAccessToken(), isNull);
      expect(await store.getRefreshToken(), isNull);
    });
  });
}
