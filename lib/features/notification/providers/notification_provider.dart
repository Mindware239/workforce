import 'dart:async';

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
      notifications:
          notifications ?? this.notifications,
      unreadCount:
          unreadCount ?? this.unreadCount,
      message: message,
    );
  }
}

class NotificationNotifier
    extends Notifier<NotificationState> {
  late final NotificationRepository repository;

  Timer? _pollingTimer;

  // Check server every 30 seconds.
  static const Duration _pollingInterval =
      Duration(seconds: 30);

  @override
  NotificationState build() {
    repository =
        ref.read(notificationRepositoryProvider);

    ref.onDispose(() {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    });

    return const NotificationState();
  }

  // ----------------------------------------------------------
  // Start real-time notification polling
  // ----------------------------------------------------------

  void startRealtimeNotifications({
    int limit = 50,
  }) {
    // Prevent duplicate timers.
    if (_pollingTimer != null) {
      return;
    }

    // Fetch immediately.
    fetchNotifications(
      limit: limit,
      showLoading: state.status == NotificationStatus.initial,
    );

    // Continue checking the server.
    _pollingTimer = Timer.periodic(
      _pollingInterval,
      (_) {
        fetchNotifications(
          limit: limit,
          showLoading: false,
        );
      },
    );
  }

  // ----------------------------------------------------------
  // Stop real-time notification polling
  // ----------------------------------------------------------

  void stopRealtimeNotifications() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // ----------------------------------------------------------
  // Fetch notifications
  // ----------------------------------------------------------

  Future<void> fetchNotifications({
    int limit = 50,
    bool showLoading = true,
  }) async {
    if (showLoading) {
      state = state.copyWith(
        status: NotificationStatus.loading,
        message: null,
      );
    }

    try {
      final response =
          await repository.getNotifications(
        limit: limit,
      );

      final data =
          Map<String, dynamic>.from(
        response['data'] ?? {},
      );

      final items =
          List<Map<String, dynamic>>.from(
        (data['items'] ?? []).map(
          (item) =>
              Map<String, dynamic>.from(item),
        ),
      );

      final unreadCount =
          int.tryParse(
                data['unreadCount']
                        ?.toString() ??
                    '0',
              ) ??
              0;

      state = state.copyWith(
        status: NotificationStatus.success,
        notifications: items,
        unreadCount: unreadCount,
        message: null,
      );
    } catch (e) {
      // During background polling, don't destroy
      // the currently displayed notification state.
      state = state.copyWith(
        status: NotificationStatus.error,
        message: e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    }
  }

  // ----------------------------------------------------------
  // Mark a single notification as read
  // ----------------------------------------------------------

  Future<bool> markAsRead(
    int notificationId,
  ) async {
    try {
      await repository.markAsRead(
        notificationId,
      );

      final updatedNotifications =
          state.notifications.map(
        (notification) {
          final id = int.tryParse(
            notification['id']?.toString() ??
                '',
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
        },
      ).toList();

      final updatedUnreadCount =
          updatedNotifications.where(
        (notification) {
          return notification['readAt'] == null;
        },
      ).length;

      state = state.copyWith(
        notifications:
            updatedNotifications,
        unreadCount:
            updatedUnreadCount,
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

  // ----------------------------------------------------------
  // Mark all notifications as read
  // ----------------------------------------------------------

  Future<bool> markAllAsRead() async {
    try {
      await repository.markAllAsRead();

      final updatedNotifications =
          state.notifications.map(
        (notification) {
          return {
            ...notification,
            'readAt':
                notification['readAt'] ??
                    DateTime.now()
                        .toUtc()
                        .toIso8601String(),
          };
        },
      ).toList();

      state = state.copyWith(
        notifications:
            updatedNotifications,
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

  // ----------------------------------------------------------
  // Reset
  // ----------------------------------------------------------

  void reset() {
    stopRealtimeNotifications();
    state = const NotificationState();
  }
}

final notificationProvider =
    NotifierProvider<
        NotificationNotifier,
        NotificationState>(
  NotificationNotifier.new,
);