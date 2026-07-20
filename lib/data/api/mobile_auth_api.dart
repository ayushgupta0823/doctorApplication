import 'api_client.dart';

/// `/api/v1/auth/mobile/*` — phone+OTP login, shared with the patient app's
/// auth pattern. `verify-otp` accepts both `patient` and (as of the backend's
/// doctor-mobile-auth work) already-onboarded `doctor` accounts; a brand-new
/// phone number is always created as `patient` — OTP itself never mints a
/// doctor account (see `mobileAuth.controller.js`).
class MobileAuthApi {
  MobileAuthApi(this._client);
  final ApiClient _client;

  /// Returns the dev OTP (`devOtp`) when SMS isn't configured server-side, so
  /// the UI can show it directly instead of the doctor needing a real SMS.
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final result = await _client.post('/auth/mobile/send-otp', body: {'phone': phone});
    return result.asMap;
  }

  /// Returns `{accessToken, refreshToken, user, isNewUser, hasProfile}`.
  Future<Map<String, dynamic>> verifyOtp({required String phone, required String otp}) async {
    final result = await _client.post('/auth/mobile/verify-otp', body: {'phone': phone, 'otp': otp});
    return result.asMap;
  }

  /// Returns a fresh access token, or throws [ApiException] if the refresh
  /// token itself is invalid/expired (session is truly dead at that point).
  Future<String> refresh(String refreshToken) async {
    final result = await _client.post('/auth/mobile/refresh', body: {'refreshToken': refreshToken});
    return result.asMap['accessToken'] as String;
  }
}
