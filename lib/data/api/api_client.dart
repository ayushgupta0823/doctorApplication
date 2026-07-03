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
/// Auth: see `ApiConfig` doc comment — attaches a hand-supplied dev Clerk
/// token as a Bearer header since the app's own login flow is still mocked.
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
          if (ApiConfig.hasDevToken) {
            options.headers['Authorization'] = 'Bearer ${ApiConfig.devClerkToken}';
          }
          handler.next(options);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  final Dio dio;

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
}
