import 'package:dio/dio.dart';

import '../../config/api_config.dart';
import 'api_exception.dart';

/// Separate Dio instance pointed directly at the AI microservice
/// (`https://ai.shikhartesting.dev`), bypassing the backend's `/api/v1/ai/*`
/// proxy entirely — mirroring how `AI-Clinic-project/src/pages/
/// PatientDashboard.jsx` and `VoiceAssistant.jsx` call it. No auth header:
/// the deployed instance does not enforce the `X-API-Key` that
/// `BackendAiapi.md` documents as required in general.
///
/// Unlike [ApiClient], responses here are plain JSON matching each
/// endpoint's documented shape directly (e.g. `{main_concerns, doctor_notes,
/// medications, follow_up}` for `/ai/summarize`) — there is no
/// `{success,data}` envelope to unwrap.
class AiClient {
  AiClient._internal()
      : dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.aiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 45),
            headers: const {'Content-Type': 'application/json'},
          ),
        );

  static final AiClient instance = AiClient._internal();

  final Dio dio;

  Map<String, dynamic> _asMap(Response response) {
    final body = response.data;
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> post(String path, {dynamic body}) async {
    try {
      return _asMap(await dio.post(path, data: body));
    } on DioException catch (e) {
      throw ApiException.fromAiDio(e);
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    try {
      return _asMap(await dio.get(path, queryParameters: query));
    } on DioException catch (e) {
      throw ApiException.fromAiDio(e);
    }
  }
}
