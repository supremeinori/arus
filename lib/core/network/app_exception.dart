/// Representasi Exception terstandar di ARUS sesuai SRS Section 18
class AppException implements Exception {
  final String code;
  final String message;
  final dynamic details;
  final String? requestId;

  const AppException({
    required this.code,
    required this.message,
    this.details,
    this.requestId,
  });

  @override
  String toString() => 'AppException(code: $code, message: $message, requestId: $requestId)';

  // Factory convenience methods
  factory AppException.network(String message) {
    return AppException(
      code: 'NETWORK_UNREACHABLE',
      message: message,
    );
  }

  factory AppException.timeout() {
    return const AppException(
      code: 'NETWORK_TIMEOUT',
      message: 'Server lambat merespons. Silakan coba lagi.',
    );
  }

  factory AppException.serverWarmingUp() {
    return const AppException(
      code: 'SERVER_WARMING_UP',
      message: 'Menghubungkan ke server...',
    );
  }

  factory AppException.fromServer(Map<String, dynamic> errorJson) {
    return AppException(
      code: errorJson['code'] as String? ?? 'INTERNAL',
      message: errorJson['message'] as String? ?? 'Terjadi kesalahan pada sistem.',
      details: errorJson['details'],
      requestId: errorJson['request_id'] as String?,
    );
  }

  factory AppException.unknown([String? detail]) {
    return AppException(
      code: 'INTERNAL',
      message: 'Terjadi kesalahan yang tidak terduga.',
      details: detail,
    );
  }
}
