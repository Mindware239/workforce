import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workforce/core/push/push_notification_service.dart';
import 'package:workforce/features/notification/providers/notification_provider.dart';

/// Folds pushes that arrive with the app open into app state: a new feed
/// notification refreshes the bell and the notification list straight away
/// instead of waiting for the next poll.
class PushBridge extends ConsumerStatefulWidget {
  const PushBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushBridge> createState() => _PushBridgeState();
}

class _PushBridgeState extends ConsumerState<PushBridge> {
  StreamSubscription<RemoteMessage>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = PushNotificationService.instance.foregroundMessages.listen((
      message,
    ) {
      if (message.data['type'] == 'notification') {
        ref
            .read(notificationProvider.notifier)
            .fetchNotifications(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
