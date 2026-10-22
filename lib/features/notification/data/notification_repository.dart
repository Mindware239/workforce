import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';

class NotificationRepository {
  final ApiClient apiClient;

  NotificationRepository({required this.apiClient});

  /// Get logged-in user's notifications
  Future<Map<String, dynamic>> getNotifications({int limit = 50}) async {
    final response = await apiClient.get(
      '/notifications',
      queryParameters: {'limit': limit},
    );

    return Map<String, dynamic>.from(response.data);
  }

  /// Mark one notification as read
  Future<Map<String, dynamic>> markAsRead(int notificationId) async {
    final response = await apiClient.put('/notifications/$notificationId/read');

    return Map<String, dynamic>.from(response.data);
  }

  /// Mark all notifications as read
  Future<Map<String, dynamic>> markAllAsRead() async {
    final response = await apiClient.put('/notifications/read-all');

    return Map<String, dynamic>.from(response.data);
  }

  /// Replies to a message from a person (POST /notifications/:id/reply,
  /// multipart: `message` and/or an `audio` voice note). The reply goes back
  /// to the sender as a notification of their own.
  Future<void> reply(
    int notificationId, {
    String? message,
    String? audioFilePath,
  }) async {
    try {
      final form = FormData.fromMap({
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
        if (audioFilePath != null)
          'audio': await MultipartFile.fromFile(
            audioFilePath,
            filename: audioFilePath.split(RegExp(r'[\\/]')).last,
            // The reply uploader only accepts an audio/* part.
            contentType: DioMediaType('audio', 'mp4'),
          ),
      });

      await apiClient.post('/notifications/$notificationId/reply', data: form);
    } catch (e) {
      throw apiException(e, 'Could not send that reply.');
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(apiClient: ref.read(apiClientProvider));
});
