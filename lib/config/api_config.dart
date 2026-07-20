/// Backend + AI service endpoints.
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

  /// Socket.IO connects to the bare server origin, not the REST `/api/v1`
  /// prefix — matches the website's own `notificationSocket.js` derivation.
  static String get socketBaseUrl => backendBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');

  /// The AI microservice, called directly (no backend proxy), mirroring
  /// `AI-Clinic-project/src/pages/PatientDashboard.jsx` and
  /// `VoiceAssistant.jsx`. The deployed instance does not enforce
  /// `X-API-Key` on this base URL.
  static const String aiBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: 'https://ai.shikhartesting.dev',
  );
}
