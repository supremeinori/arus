import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../storage/secure_store.dart';
import 'app_exception.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final secureStore = ref.watch(secureStoreProvider);
  return ApiClient(secureStore: secureStore);
});

class ApiClient {
  late final Dio _dio;
  final SecureStore secureStore;
  bool _isRefreshing = false;

  ApiClient({required this.secureStore, Dio? customDio}) {
    _dio = customDio ??
        Dio(
          BaseOptions(
            baseUrl: AppEnv.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Bypass-Tunnel-Reminder': 'true',
            },
          ),
        );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Lampirkan access token jika tersedia
          final token = await secureStore.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Tangani silent refresh jika 401 dan bukan endpoint auth dasar
          final path = error.requestOptions.path;
          final isAuthEndpoint = path.contains('/auth/login') || path.contains('/auth/refresh');

          if (error.response?.statusCode == 401 && !isAuthEndpoint && !_isRefreshing) {
            _isRefreshing = true;
            try {
              final refreshToken = await secureStore.getRefreshToken();
              if (refreshToken != null && refreshToken.isNotEmpty) {
                // Panggil refresh endpoint secara terpisah
                final refreshDio = Dio(BaseOptions(baseUrl: AppEnv.apiBaseUrl));
                final refreshResponse = await refreshDio.post(
                  '/auth/refresh',
                  data: {'refresh_token': refreshToken},
                );

                if (refreshResponse.statusCode == 200) {
                  final data = refreshResponse.data['data'] as Map<String, dynamic>;
                  final newAccessToken = data['access_token'] as String;
                  final newRefreshToken = data['refresh_token'] as String;

                  await secureStore.setAccessToken(newAccessToken);
                  await secureStore.setRefreshToken(newRefreshToken);

                  // Ulangi request asli dengan token baru
                  final opts = error.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $newAccessToken';
                  _isRefreshing = false;

                  final clonedResponse = await _dio.fetch(opts);
                  return handler.resolve(clonedResponse);
                }
              }
            } catch (_) {
              // Jika refresh gagal, bersihkan token dan logout
              await secureStore.clearTokens();
            } finally {
              _isRefreshing = false;
            }
          }

          final appException = _mapDioError(error);
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: appException,
              message: appException.message,
              type: error.type,
              response: error.response,
            ),
          );
        },
      ),
    );
  }

  Dio get rawDio => _dio;

  void updateBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error as AppException;
      throw _mapDioError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error as AppException;
      throw _mapDioError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error as AppException;
      throw _mapDioError(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error as AppException;
      throw _mapDioError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error as AppException;
      throw _mapDioError(e);
    }
  }

  AppException _mapDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return AppException.timeout();
    }

    if (error.type == DioExceptionType.connectionError) {
      return AppException.network('Tidak dapat terhubung ke server ARUS (${AppEnv.apiBaseUrl}).');
    }

    final response = error.response;
    if (response != null && response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('error') && data['error'] is Map<String, dynamic>) {
        return AppException.fromServer(data['error'] as Map<String, dynamic>, response.statusCode);
      }
    }

    return AppException(
      response?.statusMessage ?? 'Terjadi kesalahan jaringan.',
      code: 'HTTP_${response?.statusCode ?? 500}',
      statusCode: response?.statusCode,
    );
  }
}
