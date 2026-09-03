import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:workforce/core/styles/app_colors.dart';

import '../providers/notification_provider.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool _markingAllAsRead = false;
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);

    debugPrint('========== NOTIFICATION STATE ==========');
    debugPrint('Status: ${notificationState.status}');
    debugPrint('Unread Count: ${notificationState.unreadCount}');
    debugPrint('Message: ${notificationState.message}');
    debugPrint(
      'Notifications Count: ${notificationState.notifications.length}',
    );

    for (final notification in notificationState.notifications) {
      debugPrint('----------------------------------------');
      debugPrint('ID: ${notification['id']}');
      debugPrint('Category: ${notification['category']}');
      debugPrint('Title: ${notification['title']}');
      debugPrint('Body: ${notification['body']}');
      debugPrint('Image Path: ${notification['imagePath']}');
      debugPrint('Audio Path: ${notification['audioPath']}');
      debugPrint('Sender ID: ${notification['senderId']}');
      debugPrint('Sender Name: ${notification['senderName']}');
      debugPrint('Reply To ID: ${notification['replyToId']}');
      debugPrint('Read At: ${notification['readAt']}');
      debugPrint('Created At: ${notification['createdAt']}');
    }

    debugPrint('========== END NOTIFICATION STATE ==========');

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,

      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
        title: Text(
          'Notification',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryFillColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: notificationState.unreadCount == 0 || _markingAllAsRead
                ? null
                : () async {
                    debugPrint('🔔 Mark All As Read button tapped');
                    debugPrint(
                      '🔢 Unread count before: ${notificationState.unreadCount}',
                    );

                    setState(() {
                      _markingAllAsRead = true;
                    });

                    debugPrint('⏳ Calling markAllAsRead API...');

                    final success = await ref
                        .read(notificationProvider.notifier)
                        .markAllAsRead();

                    debugPrint('✅ markAllAsRead result: $success');

                    final updatedState = ref.read(notificationProvider);

                    debugPrint(
                      '🔢 Unread count after: ${updatedState.unreadCount}',
                    );
                    debugPrint(
                      '📋 Notification status: ${updatedState.status}',
                    );
                    debugPrint('💬 Message: ${updatedState.message}');

                    if (mounted) {
                      setState(() {
                        _markingAllAsRead = false;
                      });
                    }

                    debugPrint('🏁 Mark All As Read process completed');
                  },
            style: TextButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _markingAllAsRead
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Mark all\nas read',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryFillColor,
                    ),
                  ),
          ),
        ],
      ),

      body: SafeArea(child: _buildBody(notificationState)),
    );
  }

  Widget _buildBody(NotificationState state) {
    if (state.status == NotificationStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == NotificationStatus.error) {
      return _buildError(state.message);
    }

    if (state.notifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () {
        return ref.read(notificationProvider.notifier).fetchNotifications();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._buildNotificationGroups(state.notifications),

          const SizedBox(height: 20),

          Center(
            child: Text(
              "You're all caught up",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.borderColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNotificationGroups(
    List<Map<String, dynamic>> notifications,
  ) {
    final now = DateTime.now();

    final today = <Map<String, dynamic>>[];
    final earlier = <Map<String, dynamic>>[];

    for (final notification in notifications) {
      final createdAt = DateTime.tryParse(
        notification['createdAt']?.toString() ?? '',
      );

      if (createdAt == null) {
        earlier.add(notification);
        continue;
      }

      final localDate = createdAt.toLocal();

      final isToday =
          localDate.year == now.year &&
          localDate.month == now.month &&
          localDate.day == now.day;

      if (isToday) {
        today.add(notification);
      } else {
        earlier.add(notification);
      }
    }

    final widgets = <Widget>[];

    if (today.isNotEmpty) {
      widgets.add(_buildSectionTitle('TODAY'));

      widgets.add(const SizedBox(height: 8));

      for (final notification in today) {
        final notificationId = int.tryParse(
          notification['id']?.toString() ?? '',
        );

        widgets.add(
          _NotificationItem(
            notificationId: notificationId ?? 0,
            icon: _getNotificationIcon(notification['category']),
            title: notification['title']?.toString() ?? 'Notification',
            body: notification['body']?.toString(),
            time: _formatTime(notification['createdAt']),
            unread: notification['readAt'] == null,

            // Mark individual notification as read
            onTap: () async {
              if (notificationId != null && notification['readAt'] == null) {
                debugPrint('Notification tapped: ID = $notificationId');
                debugPrint('ReadAt before = ${notification['readAt']}');
                await ref
                    .read(notificationProvider.notifier)
                    .markAsRead(notificationId);
              }
            },
          ),
        );
      }
    }

    if (earlier.isNotEmpty) {
      widgets.add(const SizedBox(height: 20));

      widgets.add(_buildSectionTitle('EARLIER'));

      widgets.add(const SizedBox(height: 5));

      for (final notification in earlier) {
        final notificationId = int.tryParse(
          notification['id']?.toString() ?? '',
        );

        widgets.add(
          _NotificationItem(
            notificationId: notificationId ?? 0,
            icon: _getNotificationIcon(notification['category']),
            title: notification['title']?.toString() ?? 'Notification',
            body: notification['body']?.toString(),
            time: _formatDateTime(notification['createdAt']),
            unread: notification['readAt'] == null,

            // Mark individual notification as read
            onTap: () async {
              if (notificationId != null && notification['readAt'] == null) {
                debugPrint('Notification tapped: ID = $notificationId');
                debugPrint('ReadAt before = ${notification['readAt']}');
                await ref
                    .read(notificationProvider.notifier)
                    .markAsRead(notificationId);
              }
            },
          ),
        );
      }
    }

    return widgets;
  }

  IconData _getNotificationIcon(dynamic category) {
    switch (category?.toString()) {
      case 'attendance':
        return Icons.fingerprint_rounded;

      case 'leave':
        return Icons.fact_check_outlined;

      case 'task':
        return Icons.assignment_outlined;

      case 'message':
        return Icons.chat_bubble_outline;

      case 'salary':
        return Icons.receipt_long_outlined;

      case 'schedule':
        return Icons.calendar_month_outlined;

      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _formatTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return '';

    return DateFormat('hh:mm a').format(date.toLocal());
  }

  String _formatDateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return '';

    return DateFormat('MMM dd, hh:mm a').format(date.toLocal());
  }

  Widget _buildError(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              message ?? 'Unable to load notifications.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.mutedColor,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                ref.read(notificationProvider.notifier).fetchNotifications();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No notifications yet',
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedColor),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: .5,
          color: AppColors.mutedColor,
        ),
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String time;
  final bool unread;
  final int notificationId;
  final VoidCallback? onTap;

  const _NotificationItem({
    required this.notificationId,
    required this.icon,
    required this.title,
    required this.time,
    this.body,
    this.unread = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderColor, width: .7),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 12,
              child: unread
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryFillColor,
                      ),
                    )
                  : null,
            ),

            Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: AppColors.primaryFillColor),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.textColor,
                    ),
                  ),

                  if (body != null && body!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.3,
                        color: AppColors.mutedColor,
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),

                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
