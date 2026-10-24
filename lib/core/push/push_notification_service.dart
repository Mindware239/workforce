import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/services/auth_service.dart';
import 'package:workforce/core/services/navigation_service.dart';
import 'package:workforce/core/services/secure_storage.dart';

/// Runs in its own isolate when a push arrives with the app in the background
/// or closed. Every push the backend sends carries a `notification` block, so
/// Android and iOS draw it themselves; there is nothing to do here but start
/// Firebase, which the plugin requires.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Push notifications from the backend through Firebase Cloud Messaging.
///
/// - Foreground: FCM hands the message to the app, which shows it as a local
///   notification — except a chat already open on screen, or a call that is
///   ringing (the call screen is already up over the app).
/// - Background / closed: the system shows it from the `notification` block.
/// - A tap, in any of the three states, opens the screen the push is about
///   (see [routeFor]). A tap that lands before sign-in, or while the splash
///   is still restoring the session, waits until the dashboard is up.
///
/// The device token is registered with the backend once someone is signed in
/// and again whenever Firebase rotates it, and removed on logout so the next
/// person on this phone does not get the previous one's notifications.
///
/// Firebase not being configured yet (no google-services.json /
/// GoogleService-Info.plist) is not an error: the app runs without push.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const _channels = [
    AndroidNotificationChannel(
      'general',
      'Notifications',
      description: 'Tasks, leave, attendance and other updates',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'chat',
      'Chat messages',
      description: 'New messages while you are away from the chat',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'calls',
      'Calls',
      description: 'Incoming and missed calls',
      importance: Importance.max,
    ),
  ];

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final ApiClient _api = ApiClient(secureStorage: SecureStorage());
  final StreamController<RemoteMessage> _foreground =
      StreamController<RemoteMessage>.broadcast();

  bool _ready = false;
  String? _registeredToken;
  bool _registering = false;
  StreamSubscription<String>? _tokenRefresh;

  /// A tapped notification's route, held until the app can show it.
  String? _pendingRoute;

  /// Messages that arrived with the app open, for screens to refresh on.
  Stream<RemoteMessage> get foregroundMessages => _foreground.stream;

  bool get isAvailable => _ready;

  /// Call once from main(), before runApp.
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Push notifications are off (Firebase not configured): $e');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _initLocalNotifications();

      // The app draws foreground notifications itself, on both platforms, so
      // it can leave out the chat that is already open.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));

      // Closed app opened from a notification Firebase drew...
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _open(initial.data);

      // ...or from one this app drew while it was last open.
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _openPayload(launch!.notificationResponse?.payload);
      }

      NavigationService.router.routerDelegate.addListener(_onRouteChanged);
      _ready = true;
    } catch (e) {
      debugPrint('Push notifications could not start: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_notification'),
        // Permission is asked through Firebase in registerDevice, after sign-in.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _openPayload(response.payload),
    );

    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final channel in _channels) {
      await android?.createNotificationChannel(channel);
    }
  }

  // ----------------------------------------------------------
  // Device token
  // ----------------------------------------------------------

  /// Asks for permission and registers this phone. Safe to call repeatedly.
  Future<void> registerDevice() async {
    if (!_ready || _registering || !AuthService.isAuthenticated) return;
    _registering = true;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push notifications were not allowed on this device.');
        return;
      }

      // iOS hands out an FCM token only once APNs has given it one.
      if (Platform.isIOS) {
        String? apns;
        for (var i = 0; i < 5 && apns == null; i++) {
          apns = await messaging.getAPNSToken();
          if (apns == null) await Future.delayed(const Duration(seconds: 2));
        }
        if (apns == null) {
          debugPrint('No APNs token yet; push will register on next start.');
          return;
        }
      }

      final token = await messaging.getToken();
      if (token != null) await _sendToken(token);

      _tokenRefresh ??= messaging.onTokenRefresh.listen(_sendToken);
    } catch (e) {
      debugPrint('Push registration failed: $e');
    } finally {
      _registering = false;
    }
  }

  Future<void> _sendToken(String token) async {
    if (!AuthService.isAuthenticated) return;
    try {
      await _api.post(
        '/notifications/push/fcm-tokens',
        data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
      );
      _registeredToken = token;
    } catch (e) {
      debugPrint('Could not register the push token: $e');
    }
  }

  /// Call on logout while the auth token is still stored: the backend forgets
  /// this phone, and Firebase issues a fresh token for whoever signs in next.
  Future<void> unregisterDevice() async {
    if (!_ready) return;
    final token = _registeredToken;
    _registeredToken = null;
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    if (token != null) {
      try {
        await _api.delete(
          '/notifications/push/fcm-tokens',
          data: {'token': token},
        );
      } catch (e) {
        debugPrint('Could not unregister the push token: $e');
      }
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
      await _local.cancelAll();
    } catch (e) {
      debugPrint('Could not clear push state: $e');
    }
  }

  // ----------------------------------------------------------
  // Foreground
  // ----------------------------------------------------------

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    _foreground.add(message);

    final data = message.data;
    final type = data['type'];

    // The call screen is already ringing over the app.
    if (type == 'call' && data['callStatus'] == 'ringing') return;

    // Reading that conversation right now: the message is already on screen.
    if (type == 'chat' &&
        _currentPath == '${AppRoutes.chat}/${data['conversationId']}') {
      return;
    }

    final title = message.notification?.title ?? data['title'];
    final body = message.notification?.body ?? data['body'];
    if (title == null && body == null) return;

    final channel = switch (type) {
      'call' => _channels[2],
      'chat' => _channels[1],
      _ => _channels[0],
    };

    await _local.show(
      // Same tag, same notification: a chat burst or a ring-then-missed
      // replaces the earlier one instead of stacking.
      id: (data['tag'] ?? message.messageId ?? '').hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: channel.importance == Importance.max
              ? Priority.max
              : Priority.high,
          icon: '@drawable/ic_stat_notification',
          styleInformation: BigTextStyleInformation(body ?? ''),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
          threadIdentifier: type == 'chat'
              ? 'chat-${data['conversationId']}'
              : null,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  // ----------------------------------------------------------
  // Taps
  // ----------------------------------------------------------

  /// Where a tap on this push should land.
  static String routeFor(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'chat':
        final id = int.tryParse('${data['conversationId']}');
        if (id == null) return AppRoutes.chat;
        final title = data['conversationTitle']?.toString();
        return Uri(
          path: '${AppRoutes.chat}/$id',
          queryParameters: title == null || title.isEmpty
              ? null
              : {'title': title},
        ).toString();
      case 'call':
        // A call still ringing is picked up by the call screen once the
        // socket reconnects; a missed one is in the chat list.
        return AppRoutes.chat;
    }

    return switch (data['category']) {
      'task' => AppRoutes.task,
      'leave' || 'comp_off' => AppRoutes.leaveRequest,
      'attendance' => AppRoutes.attendance,
      'payroll' => AppRoutes.myPay,
      'schedule' => AppRoutes.schedule,
      'assets' => AppRoutes.myAssets,
      _ => AppRoutes.notification,
    };
  }

  void _openPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      _open(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (e) {
      debugPrint('Unreadable notification payload: $e');
    }
  }

  void _open(Map<String, dynamic> data) {
    _markRead(data['notificationId']);
    _pendingRoute = routeFor(data);
    _flushPending();
  }

  /// Opening it is reading it: the bell's unread count should agree.
  void _markRead(Object? id) {
    final notificationId = int.tryParse('${id ?? ''}');
    if (notificationId == null || !AuthService.isAuthenticated) return;
    unawaited(
      _api
          .put('/notifications/$notificationId/read')
          .then((_) {}, onError: (_) {}),
    );
  }

  String get _currentPath {
    try {
      return NavigationService.router.routerDelegate.currentConfiguration.uri
          .path;
    } catch (_) {
      return '';
    }
  }

  void _onRouteChanged() {
    // Signed in and past the splash (after login, or a restored session).
    if (AuthService.isAuthenticated &&
        _currentPath.startsWith(AppRoutes.dashboard)) {
      if (_registeredToken == null) unawaited(registerDevice());
      _flushPending();
    }
  }

  void _flushPending() {
    final route = _pendingRoute;
    if (route == null) return;
    // Wait for the splash to restore the session and land on the dashboard;
    // the router listener calls back here when it does.
    if (!AuthService.isAuthenticated ||
        !_currentPath.startsWith(AppRoutes.dashboard)) {
      return;
    }
    _pendingRoute = null;
    // Outside the router's own notification of the change that got us here.
    scheduleMicrotask(() => NavigationService.router.push(route));
  }
}
