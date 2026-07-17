import 'api_client.dart';

/// `/api/v1/consultations/:id/messages` — async in-consultation chat,
/// doctor and patient accessible.
class MessagesApi {
  MessagesApi(this._client);
  final ApiClient _client;

  Future<List<Map<String, dynamic>>> list(String consultationId) async {
    final result = await _client.get('/consultations/$consultationId/messages');
    return result.asList.cast<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<void> send(String consultationId, String message) async {
    await _client.post('/consultations/$consultationId/messages', body: {'message': message});
  }
}
