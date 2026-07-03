import 'api_client.dart';

/// `/api/v1/doctors/me/*` — self-service doctor profile endpoints.
class DoctorsApi {
  DoctorsApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> getMyProfile() async {
    final result = await _client.get('/doctors/me/profile');
    return result.asMap;
  }

  Future<Map<String, dynamic>> updateMyProfile(Map<String, dynamic> body) async {
    final result = await _client.put('/doctors/me/profile', body: body);
    return result.asMap;
  }

  /// Doctors who work solo (no hospital affiliation) get back `[]`.
  Future<List<Map<String, dynamic>>> getMyHospitals() async {
    final result = await _client.get('/doctors/me/hospitals');
    return result.asList.cast<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// Full `Patient` docs for every patient this doctor has ever completed a
  /// consultation with — used to join against `ConsultationsApi.listMine()`,
  /// which returns raw `patientId` strings with no populated name.
  Future<List<Map<String, dynamic>>> getMyPatients({int page = 1, int limit = 50}) async {
    final result = await _client.get('/doctors/me/patients', query: {'page': page, 'limit': limit});
    return result.asList.cast<Map>().map(Map<String, dynamic>.from).toList();
  }
}
