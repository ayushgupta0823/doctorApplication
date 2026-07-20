import 'api_client.dart';

/// `/api/v1/consultations/*`.
class ConsultationsApi {
  ConsultationsApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> getById(String consultationId) async {
    final result = await _client.get('/consultations/$consultationId');
    return result.asMap;
  }

  /// `POST /consultations/:id/video/token` — a real LiveKit JWT (not the
  /// simulated call this used to back). Returns `{token, livekitUrl,
  /// roomName, consultationId, recordingEnabled}`.
  Future<Map<String, dynamic>> getVideoToken(String consultationId) async {
    final result = await _client.post('/consultations/$consultationId/video/token');
    return result.asMap;
  }

  /// Also flips `soapNote.doctorApproved = true` server-side on success —
  /// there's no response body to reflect that, so callers update local
  /// state optimistically.
  Future<void> updateSoap(
    String consultationId, {
    required String subjective,
    required String objective,
    required String assessment,
    required String plan,
  }) async {
    await _client.put('/consultations/$consultationId/soap', body: {
      'subjective': subjective,
      'objective': objective,
      'assessment': assessment,
      'plan': plan,
    });
  }

  /// Appends a single diagnosis entry (the endpoint takes one object, not an
  /// array) and returns the full updated diagnosis array.
  Future<List<Map<String, dynamic>>> addDiagnosis(
    String consultationId, {
    required String icdCode,
    required String description,
    String type = 'primary',
  }) async {
    final result = await _client.put('/consultations/$consultationId/diagnosis', body: {
      'icdCode': icdCode,
      'description': description,
      'type': type,
    });
    return result.asList.cast<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<void> complete(String consultationId) async {
    await _client.post('/consultations/$consultationId/complete');
  }

  /// `GET /consultations/doctor` — the doctor's own consultation history,
  /// NOT populated with patient info (raw `patientId` string only). Join
  /// against `DoctorsApi.getMyPatients()` for display names.
  Future<List<Map<String, dynamic>>> listMine({int page = 1, int limit = 20}) async {
    final result = await _client.get('/consultations/doctor', query: {'page': page, 'limit': limit});
    return result.asList.cast<Map>().map(Map<String, dynamic>.from).toList();
  }
}
