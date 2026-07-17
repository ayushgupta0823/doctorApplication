import 'api_client.dart';

/// `/api/v1/lab/*` — doctor-facing subset (shared reports, patient trends,
/// critical alerts). Report upload/results-entry routes are
/// patient/lab_technician-only and aren't wired here.
class LabApi {
  LabApi(this._client);
  final ApiClient _client;

  /// Lab reports a specific patient has explicitly shared with this doctor.
  Future<List<Map<String, dynamic>>> getReportsForPatient(String patientId) async {
    final result = await _client.get('/lab/reports/patient/$patientId');
    return result.asList.cast<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// Platform-wide critical biomarker alerts visible to this doctor.
  Future<List<Map<String, dynamic>>> getCriticalAlerts() async {
    final result = await _client.get('/lab/critical-alerts');
    return result.asList.cast<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<void> acknowledgeCriticalAlert(String reportId) async {
    await _client.put('/lab/critical-alerts/$reportId/acknowledge');
  }
}
