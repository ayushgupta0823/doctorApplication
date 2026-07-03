import 'ai_client.dart';

/// Direct calls to the AI microservice's doctor-facing endpoints
/// (`BackendAiapi.md` Module 2 — AI Doctor Application). No auth header;
/// see `AiClient` doc comment for why.
class AiApi {
  AiApi(this._client);
  final AiClient _client;

  /// `POST /ai/summarize` — AI medical scribe. Takes raw consultation text
  /// (here: the live transcript, joined into one string) and returns
  /// `{main_concerns, doctor_notes, medications, follow_up}`.
  Future<Map<String, dynamic>> summarize(String notes) => _client.post('/ai/summarize', body: {'notes': notes});

  /// `POST /ai/prescription` — AI-assisted prescription drafting. Response
  /// always carries `doctor_approval_required: true`; suggestions are
  /// inserted into the draft marked `aiSuggested`, never auto-signed.
  Future<Map<String, dynamic>> prescription({
    required String diagnosis,
    required Map<String, dynamic> patientProfile,
    String? additionalNotes,
  }) =>
      _client.post('/ai/prescription', body: {
        'diagnosis': diagnosis,
        'patient_profile': patientProfile,
        if (additionalNotes != null) 'additional_notes': additionalNotes,
      });
}
