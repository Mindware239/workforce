import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_repository.dart';

enum NotificationStatus {
  initial,
  loading,
  success,
  error,
}

class NotificationState {
  final NotificationStatus status;
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final String? message;

  const NotificationState({
    this.status = NotificationStatus.initial,
    this.notifications = const [],
    this.unreadCount = 0,
    this.message,
  });

  NotificationState copyWith({
    NotificationStatus? status,
    List<Map<String, dynamic>>? notifications,
    int? unreadCount,
    String? message,
  }) {
    return NotificationState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      message: message,
    );
  }
}

class NotificationNotifier
    extends Notifier<NotificationState> {
  late final NotificationRepository repository;

  @override
  NotificationState build() {
    repository = ref.read(notificationRepositoryProvider);

    return const NotificationState();
  }

  /// Fetch notifications
  Future<void> fetchNotifications({
    int limit = 50,
  }) async {
    state = state.copyWith(
      status: NotificationStatus.loading,
      message: null,
    );

    try {
      final response = await repository.getNotifications(
        limit: limit,
      );

      final data = Map<String, dynamic>.from(
        response['data'] ?? {},
      );

      final items = List<Map<String, dynamic>>.from(
        (data['items'] ?? []).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );

      final unreadCount =
          int.tryParse(
                data['unreadCount']?.toString() ?? '0',
              ) ??
              0;

      state = state.copyWith(
        status: NotificationStatus.success,
        notifications: items,
        unreadCount: unreadCount,
        message: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: NotificationStatus.error,
        message: e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  /// Mark a single notification as read
  Future<bool> markAsRead(
    int notificationId,
  ) async {
    try {
      await repository.markAsRead(notificationId);

      final updatedNotifications =
          state.notifications.map((notification) {
        final id = int.tryParse(
          notification['id']?.toString() ?? '',
        );

        if (id == notificationId) {
          return {
            ...notification,
            'readAt': DateTime.now()
                .toUtc()
                .toIso8601String(),
          };
        }

        return notification;
      }).toList();

      final updatedUnreadCount =
          updatedNotifications.where((notification) {
        return notification['readAt'] == null;
      }).length;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: updatedUnreadCount,
        message: null,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        message: e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );

      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      await repository.markAllAsRead();

      final updatedNotifications =
          state.notifications.map((notification) {
        return {
          ...notification,
          'readAt': notification['readAt'] ??
              DateTime.now()
                  .toUtc()
                  .toIso8601String(),
        };
      }).toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
        message: null,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        message: e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );

      return false;
    }
  }

  void reset() {
    state = const NotificationState();
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
  NotificationNotifier.new,
);