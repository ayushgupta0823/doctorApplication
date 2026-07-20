import 'package:dio/dio.dart';

import '../../config/api_config.dart';
import 'api_exception.dart';

/// Unwrapped result of a backend call: `data` is whatever sat under the
/// envelope's `data` key (often `null` — see class doc below), `meta` is the
/// pagination block (`{page, limit, total, totalPages}`) when present.
class ApiResult {
  const ApiResult({this.data, this.meta});

  final dynamic data;
  final Map<String, dynamic>? meta;

  Map<String, dynamic> get asMap => data is Map ? Map<String, dynamic>.from(data as Map) : const {};

  List get asList => data is List ? data as List : const [];
}

/// Thin wrapper around a Dio instance pointed at the healthcare-api backend.
/// Unwraps the `{success, message, data, meta}` envelope every controller
/// returns (see `healthcare-api/src/utils/response.js`) and converts
/// failures into [ApiException].
///
/// `data` is always optional — many mutation endpoints (confirm, no-show,
/// notes, soap, mark-read, etc.) return no `data` key at all on success, so
/// callers must treat a missing/null `data` as a valid outcome, not an error.
///
/// Auth: [getAccessToken]/[onUnauthorized] are wired once from `AppState`
/// after real login (`POST /auth/mobile/verify-otp`) — this client itself
/// holds no session state, just the hooks to read/refresh it.
class ApiClient {
  ApiClient._internal()
      : dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.backendBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = getAccessToken?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Single retry-after-refresh on 401 — guarded by an `extra` flag so
          // a refresh that itself 401s (refresh token expired too) can't loop.
          final alreadyRetried = error.requestOptions.extra['retriedAfterRefresh'] == true;
          if (error.response?.statusCode == 401 && !alreadyRetried && onUnauthorized != null) {
            final refreshed = await onUnauthorized!();
            if (refreshed) {
              final retryOptions = error.requestOptions..extra['retriedAfterRefresh'] = true;
              final token = getAccessToken?.call();
              if (token != null) retryOptions.headers['Authorization'] = 'Bearer $token';
              try {
                return handler.resolve(await dio.fetch(retryOptions));
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  final Dio dio;

  /// Returns the current mobile-JWT access token, or null when logged out.
  /// Set once from `AppState`.
  String? Function()? getAccessToken;

  /// Attempts a token refresh on a 401; returns whether it succeeded so the
  /// triggering request can be retried once. Set once from `AppState`.
  Future<bool> Function()? onUnauthorized;

  ApiResult _unwrap(Response response) {
    final body = response.data;
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      return ApiResult(
        data: map['data'],
        meta: map['meta'] is Map ? Map<String, dynamic>.from(map['meta'] as Map) : null,
      );
    }
    return ApiResult(data: body);
  }

  Future<ApiResult> get(String path, {Map<String, dynamic>? query}) async {
    try {
      return _unwrap(await dio.get(path, queryParameters: query));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ApiResult> post(String path, {dynamic body, Map<String, dynamic>? query}) async {
    try {
      return _unwrap(await dio.post(path, data: body, queryParameters: query));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ApiResult> put(String path, {dynamic body}) async {
    try {
      return _unwrap(await dio.put(path, data: body));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ApiResult> delete(String path, {dynamic body}) async {
    try {
      return _unwrap(await dio.delete(path, data: body));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Multipart upload — used for document uploads (application/invite flows).
  Future<ApiResult> postMultipart(String path, FormData formData) async {
    try {
      return _unwrap(await dio.post(path, data: formData));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
