import 'package:dio/dio.dart';

/// Thrown by [ApiClient]/[AiClient] for any failed request. Carries enough
/// detail (status, backend error code) for callers to distinguish "expected"
/// failures (401 from a stale dev token, 409 conflicts) from genuine bugs.
class ApiException implements Exception {
  ApiException({required this.message, this.statusCode, this.code, this.details});

  final String message;
  final int? statusCode;
  final String? code;
  final dynamic details;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
  bool get isNetworkError => statusCode == null;

  /// Parses the backend's `{success:false, message, error:{code, details}}`
  /// envelope (see `healthcare-api/src/utils/response.js`). Falls back to a
  /// generic message for network-level failures (timeout, no connection)
  /// where there's no response body to parse.
  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response != null && response.data is Map) {
      final map = Map<String, dynamic>.from(response.data as Map);
      final err = map['error'];
      return ApiException(
        message: (map['message'] as String?) ?? 'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
        code: err is Map ? err['code'] as String? : null,
        details: err is Map ? err['details'] : null,
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(message: 'Network timeout — please check your connection.');
      case DioExceptionType.connectionError:
        return ApiException(message: 'Could not reach the server. Check your connection.');
      case DioExceptionType.cancel:
        return ApiException(message: 'Request cancelled.');
      default:
        return ApiException(message: e.message ?? 'Unexpected network error.');
    }
  }

  /// Parses a FastAPI-style error body (`{"detail": "..."}` or
  /// `{"detail": [{"msg": "..."}]}` for validation errors) from the AI
  /// microservice, which does not use the backend's `{success,error}`
  /// envelope at all.
  factory ApiException.fromAiDio(DioException e) {
    final response = e.response;
    if (response != null && response.data is Map) {
      final map = Map<String, dynamic>.from(response.data as Map);
      final detail = map['detail'];
      String message;
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty && detail.first is Map) {
        message = (detail.first as Map)['msg']?.toString() ?? 'AI service request failed';
      } else {
        message = 'AI service request failed (${response.statusCode})';
      }
      return ApiException(message: message, statusCode: response.statusCode);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(message: 'AI service timed out — please try again.');
      case DioExceptionType.connectionError:
        return ApiException(message: 'Could not reach the AI service.');
      case DioExceptionType.cancel:
        return ApiException(message: 'Request cancelled.');
      default:
        return ApiException(message: e.message ?? 'Unexpected AI service error.');
    }
  }

  @override
  String toString() => 'ApiException($statusCode${code != null ? ' $code' : ''}): $message';
}
