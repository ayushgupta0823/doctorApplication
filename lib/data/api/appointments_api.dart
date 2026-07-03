import 'api_client.dart';

/// `/api/v1/appointments/*` — doctor-side appointment lifecycle.
class AppointmentsApi {
  AppointmentsApi(this._client);
  final ApiClient _client;

  /// `GET /appointments/doctor` — populates `patientId` with
  /// `{firstName,lastName,dateOfBirth,gender,profilePhoto}`. This is the
  /// queue's data source; distinct from `GET /doctors/me/appointments`,
  /// which does NOT populate the patient (raw ObjectId only) but does
  /// support filtering by `?date=`.
  Future<List<Map<String, dynamic>>> listForDoctor({String? status, int page = 1, int limit = 100}) async {
    final result = await _client.get('/appointments/doctor', query: {
      if (status != null) 'status': status,
      'page': page,
      'limit': limit,
    });
    return result.asList.cast<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<Map<String, dynamic>> confirm(String appointmentId) async {
    final result = await _client.put('/appointments/$appointmentId/confirm');
    return result.asMap;
  }

  /// Returns `{appointment, consultation}`. Read `consultation._id` for the
  /// new consultation id — `appointment.consultationId` in this response is
  /// stale (stamped after the appointment doc was already fetched
  /// server-side), per `healthcare-api`'s `startConsultation` controller.
  Future<Map<String, dynamic>> start(String appointmentId) async {
    final result = await _client.put('/appointments/$appointmentId/start');
    return result.asMap;
  }

  Future<Map<String, dynamic>> complete(String appointmentId) async {
    final result = await _client.put('/appointments/$appointmentId/complete');
    return result.asMap;
  }

  /// No `data` key in the response — a 200 with an empty envelope means
  /// success.
  Future<void> markNoShow(String appointmentId) async {
    await _client.put('/appointments/$appointmentId/no-show');
  }
}
