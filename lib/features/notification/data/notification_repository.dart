import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_client.dart';
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
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(apiClient: ref.read(apiClientProvider));
});
