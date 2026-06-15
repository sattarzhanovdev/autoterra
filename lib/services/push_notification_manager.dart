import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import 'api_client.dart';

/// Top-level FCM background handler — must NOT be a closure or class method.
/// The @pragma annotation keeps it from being tree-shaken in release builds.
@pragma('vm:entry-point')
Future<void> onFirebaseBackgroundMessage(RemoteMessage _) async {
  // The OS shows the notification automatically from the FCM payload.
  // We don't need to do anything here.
}

class PushNotificationManager {
  static final PushNotificationManager _instance = PushNotificationManager._();
  factory PushNotificationManager() => _instance;
  PushNotificationManager._();

  bool _initialized = false;

  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'autoterra_default';
  static const _channelName = 'AutoTerra уведомления';

  /// Call once — right after the authenticated shell is mounted.
  /// Protected by [_initialized] so it's safe to call repeatedly.
  Future<void> init(GoRouter router) async {
    if (_initialized) return;
    _initialized = true;

    await _requestPermissions();
    await _setupLocalNotifications();
    await _registerToken();
    _listenTokenRefresh();
    _listenForeground();
    _listenBackgroundTap(router);
    await _handleInitialMessage(router);
  }

  // ── 1. Permissions ────────────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // On iOS, FCM by default suppresses banners while the app is in foreground.
    // This opts back in so the user sees alerts even when the app is open.
    if (Platform.isIOS) {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  // ── 2. Local notifications (Android foreground display) ───────────────────

  Future<void> _setupLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Android 8+ requires an explicit notification channel.
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.high,
        enableVibration: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // ── 3. Token registration ─────────────────────────────────────────────────

  Future<void> _registerToken() async {
    final token = await _fcm.getToken();
    if (token != null) await _sendTokenToBackend(token);
  }

  void _listenTokenRefresh() {
    // FCM rotates tokens occasionally; keep the backend in sync.
    _fcm.onTokenRefresh.listen(_sendTokenToBackend);
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiClient().registerDeviceToken(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (_) {
      // Non-critical: will be retried on next launch when _initialized resets.
    }
  }

  // ── 4a. Foreground: show a local banner ───────────────────────────────────

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n == null) return;

      _localNotifications.show(
        // Use hashCode as a stable-ish ID so rapid messages don't collide.
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });
  }

  // ── 4b. Background: user tapped a notification while app was in background ─

  void _listenBackgroundTap(GoRouter router) {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateFromMessage(router, message);
    });
  }

  // ── 4c. Terminated: user tapped a notification that cold-started the app ───

  Future<void> _handleInitialMessage(GoRouter router) async {
    final message = await _fcm.getInitialMessage();
    if (message == null) return;

    // Brief delay so the widget tree is fully built before we push a route.
    await Future.delayed(const Duration(milliseconds: 400));
    _navigateFromMessage(router, message);
  }

  // ── Navigation helper ─────────────────────────────────────────────────────

  void _navigateFromMessage(GoRouter router, RemoteMessage message) {
    final relatedLink = message.data['relatedLink'] as String?;
    if (relatedLink != null && relatedLink.isNotEmpty) {
      router.go(relatedLink);
    } else {
      router.go(AppRoutes.notifications);
    }
  }
}
