import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// `/api/v1/doctors/*` — self-service doctor profile endpoints, plus the
/// guest-friendly solo-apply flow.
class DoctorsApi {
  DoctorsApi(this._client);
  final ApiClient _client;

  /// `POST /doctors/apply` (`optionalAuth`) — submits a solo-doctor
  /// application. Called only while logged in (via mobile JWT), so the
  /// application is linked to `req.user.userId` immediately rather than by
  /// email at verification time.
  Future<Map<String, dynamic>> apply(Map<String, dynamic> body) async {
    final result = await _client.post('/doctors/apply', body: body);
    return result.asMap;
  }

  /// `GET /doctors/me/application-status` — `hasApplication`/`isVerified` for
  /// a solo applicant awaiting super-admin review. 404/empty before any
  /// application exists.
  Future<Map<String, dynamic>> getMyApplicationStatus() async {
    final result = await _client.get('/doctors/me/application-status');
    return result.asMap;
  }

  /// `POST /hospitals/upload-document?type=` — shared upload endpoint used by
  /// both the solo-apply and hospital-invite document steps (multer field
  /// name is `document`; `type` rides the query string, matching
  /// `AI-Clinic-project/src/lib/api.js`'s `hospitalsApi.uploadDocument`).
  /// Returns the S3 URL.
  Future<String> uploadDocument(File file, String docType) async {
    final formData = FormData.fromMap({
      'document': await MultipartFile.fromFile(file.path, filename: file.path.split(Platform.pathSeparator).last),
    });
    final result = await _client.postMultipart('/hospitals/upload-document?type=$docType', formData);
    return result.asMap['url'] as String? ?? '';
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    final result = await _client.get('/doctors/me/profile');
    return result.asMap;
  }

  Future<Map<String, dynamic>> updateMyProfile(Map<String, dynamic> body) async {
    final result = await _client.put('/doctors/me/profile', body: body);
    return result.asMap;
  }

  /// `GET /doctors/me/availability` — the doctor's weekly working-hours
  /// schedule. Returns `{}` (not null) when nothing's been configured yet,
  /// so callers can treat "no schedule" and "empty schedule" the same way.
  Future<Map<String, dynamic>> getMyAvailability() async {
    final result = await _client.get('/doctors/me/availability');
    return result.asMap;
  }

  /// `PUT /doctors/me/availability` — upserts the weekly schedule.
  Future<Map<String, dynamic>> setMyAvailability(Map<String, dynamic> body) async {
    final result = await _client.put('/doctors/me/availability', body: body);
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
