import 'package:flutter_test/flutter_test.dart';

import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/push/push_notification_service.dart';

/// Where a tapped push lands. The data is what the backend puts in the FCM
/// `data` block (backend/shared/services/fcmPush.service.js).
void main() {
  String route(Map<String, dynamic> data) =>
      PushNotificationService.routeFor(data);

  test('a chat message opens that conversation, titled', () {
    expect(
      route({'type': 'chat', 'conversationId': '12', 'conversationTitle': 'Asha'}),
      '${AppRoutes.chat}/12?title=Asha',
    );
    expect(route({'type': 'chat', 'conversationId': '12'}), '${AppRoutes.chat}/12');
    expect(route({'type': 'chat'}), AppRoutes.chat);
  });

  test('a call opens the chat list', () {
    expect(route({'type': 'call', 'callStatus': 'missed'}), AppRoutes.chat);
  });

  test('feed notifications open their section', () {
    Map<String, dynamic> n(String category) =>
        {'type': 'notification', 'category': category};
    expect(route(n('task')), AppRoutes.task);
    expect(route(n('leave')), AppRoutes.leaveRequest);
    expect(route(n('comp_off')), AppRoutes.leaveRequest);
    expect(route(n('attendance')), AppRoutes.attendance);
    expect(route(n('payroll')), AppRoutes.myPay);
    expect(route(n('schedule')), AppRoutes.schedule);
    expect(route(n('assets')), AppRoutes.myAssets);
  });

  test('anything else opens the notification list', () {
    for (final category in ['general', 'message', 'operations', 'registration', 'nonsense']) {
      expect(
        route({'type': 'notification', 'category': category}),
        AppRoutes.notification,
      );
    }
    expect(route({}), AppRoutes.notification);
  });
}
