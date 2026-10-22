import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';

/// Workspace announcements — backend/modules/announcements.
///
/// GET /api/announcements/mine?limit=N -> { pinned: [...], recent: [...] }
/// Each announcement: id, title, body, priority (normal|high|action_required),
/// pinned, createdAt, authorName. The backend has no read/acknowledge state and
/// no attachments, so the feed is read-only.
class AnnouncementRepository {
  final ApiClient apiClient;

  AnnouncementRepository({required this.apiClient});

  Future<({List<Map<String, dynamic>> pinned, List<Map<String, dynamic>> recent})>
      getMine({int limit = 20}) async {
    try {
      final response = await apiClient.get(
        '/announcements/mine',
        queryParameters: {'limit': limit},
      );

      final data = asMap(unwrapData(response.data));

      return (
        pinned: asMapList(data['pinned']),
        recent: asMapList(data['recent']),
      );
    } catch (e) {
      throw apiException(e, 'Unable to load announcements.');
    }
  }
}
