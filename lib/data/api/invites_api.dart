import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// `/api/v1/invites/*` — hospital-admin-invite → doctor-application flow
/// (`authAny`-enabled, so it works over the mobile JWT from OTP login).
/// Mirrors `AI-Clinic-project/src/pages/AcceptInvitePage.jsx`'s doctor
/// branch; the lab-technician `accept` endpoint isn't wired here since this
/// app is doctor-only.
class InvitesApi {
  InvitesApi(this._client);
  final ApiClient _client;

  /// `GET /invites/:token` — invite context (`email`, `type`, `hospitalName`,
  /// `customDocRequirements`, and any in-progress draft `application`).
  Future<Map<String, dynamic>> get(String token) async {
    final result = await _client.get('/invites/$token');
    return result.asMap;
  }

  /// `POST /invites/:token/application` — starts or updates the draft. Save
  /// failures are non-fatal (matches the website's autosave-per-step
  /// behavior) — callers should toast on failure, not block navigation.
  Future<Map<String, dynamic>> saveDraft(String token, Map<String, dynamic> body) async {
    final result = await _client.post('/invites/$token/application', body: body);
    return result.asMap;
  }

  /// `POST /invites/:token/application/documents` — multer field `document`;
  /// `type` must be one of `degree_certificate`/`nmc_registration`/
  /// `govt_id`/`passport_photo`/`custom`.
  Future<Map<String, dynamic>> uploadDocument(String token, File file, String type) async {
    final formData = FormData.fromMap({
      'type': type,
      'document': await MultipartFile.fromFile(file.path, filename: file.path.split(Platform.pathSeparator).last),
    });
    final result = await _client.postMultipart('/invites/$token/application/documents', formData);
    return result.asMap;
  }

  Future<void> deleteDocument(String token, String docId) async {
    await _client.delete('/invites/$token/application/documents/$docId');
  }

  /// `POST /invites/:token/application/submit` — validates required fields
  /// and documents server-side; throws [ApiException] with the backend's
  /// message if incomplete.
  Future<Map<String, dynamic>> submit(String token) async {
    final result = await _client.post('/invites/$token/application/submit');
    return result.asMap;
  }
}
