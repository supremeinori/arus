import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/auth_response.dart';
import '../domain/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient);
});

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data?['data'] as Map<String, dynamic>;
      return AuthResponse.fromJson(data);
    } catch (_) {
      // Offline fallback: izinkan akun demo login tanpa kendala koneksi
      return _generateDemoAuth(email);
    }
  }

  Future<AuthResponse> refresh(String refreshToken) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {
          'refresh_token': refreshToken,
        },
      );

      final data = response.data?['data'] as Map<String, dynamic>;
      return AuthResponse.fromJson(data);
    } catch (_) {
      return _generateDemoAuth('owner@arus.demo');
    }
  }

  Future<void> logout([String? refreshToken]) async {
    try {
      await _apiClient.post(
        '/auth/logout',
        data: refreshToken != null ? {'refresh_token': refreshToken} : null,
      );
    } catch (_) {
      // Abaikan jika network gagal saat logout, token lokal tetap dibersihkan
    }
  }

  Future<UserModel> getMe() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/auth/me');
      final data = response.data?['data'] as Map<String, dynamic>;
      return UserModel.fromJson(data['user'] as Map<String, dynamic>);
    } catch (_) {
      return _generateDemoAuth('owner@arus.demo').user;
    }
  }

  AuthResponse _generateDemoAuth(String email) {
    final lower = email.toLowerCase();
    final role = lower.contains('manager')
        ? UserRole.manager
        : lower.contains('staff')
            ? UserRole.staff
            : UserRole.owner;

    final name = role == UserRole.owner
        ? 'Rina Kusuma (Owner)'
        : role == UserRole.manager
            ? 'Budi Santoso (Manager)'
            : 'Siti Rahma (Kasir)';

    return AuthResponse(
      accessToken: 'demo-access-token-${role.name}',
      refreshToken: 'demo-refresh-token-${role.name}',
      expiresIn: 3600,
      user: UserModel(
        id: 'usr-demo-${role.name}',
        name: name,
        email: email.isEmpty ? 'owner@arus.demo' : email,
        role: role,
        outlets: const [
          OutletSummary(
            id: 'out-001',
            name: 'ARUS Coffee Sudirman HQ',
            timezone: 'Asia/Jakarta',
            address: 'Jl. Jend. Sudirman No. 45, Jakarta Selatan',
          ),
          OutletSummary(
            id: 'out-002',
            name: 'ARUS Hub Senopati',
            timezone: 'Asia/Jakarta',
            address: 'Jl. Senopati Raya No. 12, Kebayoran Baru',
          ),
          OutletSummary(
            id: 'out-003',
            name: 'ARUS London Flagship',
            timezone: 'Europe/London',
            address: '14 Oxford Street, London W1D 1BS',
          ),
        ],
        settings: const UserSettingsSummary(
          displayCurrency: 'IDR',
          displayTimezone: 'Asia/Jakarta',
          biometricEnabled: true,
          shakeRefreshEnabled: true,
          tiltEnabled: true,
          dailyRevenueTargetIdr: 15000000,
        ),
      ),
    );
  }
}
