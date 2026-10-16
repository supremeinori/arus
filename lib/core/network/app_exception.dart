/// Representasi Exception terstandar di ARUS sesuai SRS Section 18
class AppException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final dynamic details;
  final String? requestId;

  const AppException(
    this.message, {
    this.code = 'NETWORK_ERROR',
    this.statusCode,
    this.details,
    this.requestId,
  });

  const AppException.custom({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
    this.requestId,
  });

  @override
  String toString() => 'AppException(code: $code, message: $message, requestId: $requestId)';

  // Factory convenience methods
  factory AppException.network(String message) {
    return AppException(
      message,
      code: 'NETWORK_UNREACHABLE',
    );
  }

  factory AppException.timeout() {
    return const AppException(
      'Server lambat merespons. Silakan coba lagi.',
      code: 'NETWORK_TIMEOUT',
    );
  }

  factory AppException.serverWarmingUp() {
    return const AppException(
      'Menghubungkan ke server...',
      code: 'SERVER_WARMING_UP',
    );
  }

  factory AppException.fromServer(Map<String, dynamic> errorJson, [int? httpStatusCode]) {
    return AppException(
      errorJson['message'] as String? ?? 'Terjadi kesalahan pada sistem.',
      code: errorJson['code'] as String? ?? 'INTERNAL',
      statusCode: httpStatusCode ?? (errorJson['status_code'] ?? errorJson['statusCode']) as int?,
      details: errorJson['details'],
      requestId: errorJson['request_id'] as String?,
    );
  }

  factory AppException.unknown([String? detail]) {
    return AppException(
      'Terjadi kesalahan yang tidak terduga.',
      code: 'INTERNAL',
      details: detail,
    );
  }
}
