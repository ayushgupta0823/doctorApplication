/// Backend + AI service endpoints and the temporary dev-auth override.
///
/// The OTP/login screen is intentionally still mocked (see `AppState.sendOtp`
/// / `verifyOtp`), so it never produces a real token. Meanwhile every
/// doctor-facing backend route requires a Clerk session JWT — the mobile JWT
/// this app *could* mint has no path to the `doctor` role and is rejected by
/// those routes outright (see `healthcare-api/AGENTS.md`'s auth truth table).
/// Fixing that is a backend change that was explicitly ruled out for now.
///
/// So, until real login exists, real API calls authenticate with a
/// hand-supplied Clerk JWT for a verified doctor test account, passed in at
/// build/run time — never hardcoded in source. Grab one from the
/// AI-Clinic-project website's network tab while signed in as a doctor
/// (Clerk session tokens expire in ~60s and are normally auto-refreshed by
/// the Clerk SDK; here you'll need to re-run with a fresh token when calls
/// start 401ing).
///
/// Usage: flutter run --dart-define=DEV_CLERK_TOKEN=eyJ...
class ApiConfig {
  ApiConfig._();

  /// Deployed backend, matching the AI-Clinic-project website's production
  /// default (`VITE_API_BASE_URL`). Override for a local backend, e.g.
  /// --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1 (Android emulator
  /// loopback to the host machine).
  static const String backendBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.shikhartesting.dev/api/v1',
  );

  /// The AI microservice, called directly (no backend proxy), mirroring
  /// `AI-Clinic-project/src/pages/PatientDashboard.jsx` and
  /// `VoiceAssistant.jsx`. The deployed instance does not enforce
  /// `X-API-Key` on this base URL.
  static const String aiBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: 'https://ai.shikhartesting.dev',
  );

  /// TEMPORARY. See file doc comment above. Empty until supplied.
  static const String devClerkToken = String.fromEnvironment('DEV_CLERK_TOKEN');

  static bool get hasDevToken => devClerkToken.isNotEmpty;
}
