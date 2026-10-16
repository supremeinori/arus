import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
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
          'email': email.trim(),
          'password': password,
        },
      );

      final data = response.data?['data'] as Map<String, dynamic>;
      return AuthResponse.fromJson(data);
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus. Gagal menghubungi server.');
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
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus. Sesi gagal diperbarui.');
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
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Koneksi ke web service terputus.');
    }
  }
}
