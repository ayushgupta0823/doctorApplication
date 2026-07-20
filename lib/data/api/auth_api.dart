import 'api_client.dart';

/// `/api/v1/auth/*` (not `/auth/mobile/*` — see [MobileAuthApi] for OTP).
class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  /// `PUT /auth/me/email` — sets/updates the current account's email. A
  /// phone-only OTP signup has none by default; the hospital invite-accept
  /// flow requires one that matches the invite (see `invite.controller.js`).
  Future<Map<String, dynamic>> updateMyEmail(String email) async {
    final result = await _client.put('/auth/me/email', body: {'email': email});
    return result.asMap;
  }

  /// `PUT /auth/fcm-token` — registers this device's FCM token for push
  /// notifications. Already `authAny`-enabled server-side (built alongside
  /// the patient app's push support), so this works over the mobile JWT.
  Future<void> registerFcmToken(String token, String device) async {
    await _client.put('/auth/fcm-token', body: {'token': token, 'device': device});
  }

  /// `DELETE /auth/fcm-token` — called on logout so a stale token doesn't
  /// keep receiving push after the session ends.
  Future<void> removeFcmToken(String token) async {
    await _client.delete('/auth/fcm-token', body: {'token': token});
  }
}
