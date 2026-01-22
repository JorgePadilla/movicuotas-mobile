import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM: Background message received: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Use late to avoid accessing FirebaseMessaging before Firebase.initializeApp()
  late final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  Function(String)? _onNotificationTap;
  bool _initialized = false;

  String? get fcmToken => _fcmToken;

  /// Initialize Firebase and notification services
  Future<void> initialize({Function(String)? onNotificationTap}) async {
    if (_initialized) return;

    _onNotificationTap = onNotificationTap;

    // Initialize Firebase FIRST
    await Firebase.initializeApp();

    // Now safe to access FirebaseMessaging
    _messaging = FirebaseMessaging.instance;

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request notification permissions
    await _requestPermissions();

    // Initialize local notifications for foreground
    await _initializeLocalNotifications();

    // Get initial FCM token
    await _getToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM: Token refreshed');
      _fcmToken = newToken;
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _initialized = true;
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('FCM: Permission status: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && _onNotificationTap != null) {
          _onNotificationTap!(response.payload!);
        }
      },
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'movicuotas_channel',
      'MOVICUOTAS Notificaciones',
      description: 'Notificaciones de pagos y recordatorios',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Get FCM token
  Future<String?> _getToken() async {
    _fcmToken = await _messaging.getToken();
    debugPrint('FCM: Token obtained: ${_fcmToken?.substring(0, 20)}...');
    return _fcmToken;
  }

  /// Handle foreground messages - show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    print('############ FCM MESSAGE RECEIVED ############');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');
    print('###############################################');

    final notification = message.notification;
    if (notification == null) {
      print('FCM: No notification payload, skipping');
      return;
    }

    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'movicuotas_channel',
          'MOVICUOTAS Notificaciones',
          channelDescription: 'Notificaciones de pagos y recordatorios',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['type'] ?? 'notification',
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('FCM: Notification tapped: ${message.data}');
    final type = message.data['type'] as String?;
    if (type != null && _onNotificationTap != null) {
      _onNotificationTap!(type);
    }
  }

  /// Get device info for token registration
  Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String platform;
    String deviceName;
    String osVersion;

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      platform = 'android';
      deviceName = '${androidInfo.brand} ${androidInfo.model}';
      osVersion = androidInfo.version.release;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      platform = 'ios';
      deviceName = iosInfo.utsname.machine;
      osVersion = iosInfo.systemVersion;
    } else {
      platform = 'unknown';
      deviceName = 'Unknown';
      osVersion = 'Unknown';
    }

    return {
      'platform': platform,
      'device_name': deviceName,
      'os_version': osVersion,
      'app_version': packageInfo.version,
    };
  }

  /// Refresh token with backend (call on app open)
  Future<String?> refreshToken() async {
    if (!_initialized) return null;
    _fcmToken = await _messaging.getToken();
    return _fcmToken;
  }

  /// Delete FCM token (call on logout)
  Future<void> deleteToken() async {
    if (!_initialized) return;
    await _messaging.deleteToken();
    _fcmToken = null;
  }
}
