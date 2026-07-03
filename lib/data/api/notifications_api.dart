import 'api_client.dart';

/// `/api/v1/notifications/*`. Clerk-only per the backend auth truth table —
/// works with the dev token, would not work over a real mobile JWT session.
class NotificationsApi {
  NotificationsApi(this._client);
  final ApiClient _client;

  Future<List<Map<String, dynamic>>> list({int page = 1, int limit = 20}) async {
    final result = await _client.get('/notifications/me', query: {'page': page, 'limit': limit});
    return result.asList.cast<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<int> unreadCount() async {
    final result = await _client.get('/notifications/me/unread-count');
    return (result.asMap['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAllRead() async {
    await _client.put('/notifications/me/read-all');
  }
}
