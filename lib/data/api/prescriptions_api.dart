import 'api_client.dart';

/// `/api/v1/prescriptions/*` — doctor-side create/approve flow.
class PrescriptionsApi {
  PrescriptionsApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final result = await _client.post('/prescriptions', body: body);
    return result.asMap;
  }

  /// Response only ever contains `{pdfUrl}` — not the full prescription doc.
  Future<String?> approve(String prescriptionId) async {
    final result = await _client.post('/prescriptions/$prescriptionId/approve');
    return result.asMap['pdfUrl'] as String?;
  }

  Future<List<Map<String, dynamic>>> getByConsultation(String consultationId) async {
    final result = await _client.get('/prescriptions/by-consultation/$consultationId');
    return result.asList.cast<Map>().map(Map<String, dynamic>.from).toList();
  }
}
