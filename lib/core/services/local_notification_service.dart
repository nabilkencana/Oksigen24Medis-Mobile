import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ── Background message handler (must be top-level function) ─────────────────
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // This runs in a separate isolate when app is fully closed.
  // flutter_local_notifications is NOT available here — FCM handles the
  // notification display automatically via the data payload.
  debugPrint('[FCM] Background message received: ${message.messageId}');
}

/// Service for showing system-level notifications.
/// - App FOREGROUND: in-app toast (handled by DashboardScreen)
/// - App BACKGROUND: flutter_local_notifications (system status bar)
/// - App KILLED/CLOSED: Firebase Cloud Messaging (FCM) via push
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  bool _initialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  // ── Notification channel ─────────────────────────────────────────────────
  static const String _channelId = 'oksigen24_transactions';
  static const String _channelName = 'Transaksi';
  static const String _channelDesc =
      'Notifikasi setiap transaksi baru: sewa, penjualan, isi ulang, dll.';
  static const String _defaultIcon = '@mipmap/ic_launcher';

  int _idCounter = 0;
  int get _nextId => ++_idCounter;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Initialize flutter_local_notifications (for background/foreground)
    const androidSettings = AndroidInitializationSettings(_defaultIcon);
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // Request Android 13+ POST_NOTIFICATIONS permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 2. Setup Firebase Messaging (for killed app notifications)
    await _setupFCM();

    _initialized = true;
    debugPrint('[LocalNotificationService] Initialized ✓ (FCM token: $_fcmToken)');
  }

  Future<void> _setupFCM() async {
    // Register background handler (runs when app is killed)
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Request permission (iOS + Android 13+)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    // Get FCM token (used by backend to send targeted push)
    _fcmToken = await _fcm.getToken();
    debugPrint('[FCM] Token: $_fcmToken');

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((token) {
      _fcmToken = token;
      debugPrint('[FCM] Token refreshed: $token');
      // TODO: Send updated token to backend
    });

    // Foreground FCM messages — show as local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message: ${message.notification?.title}');
      final notification = message.notification;
      if (notification != null) {
        show(
          title: notification.title ?? 'Notifikasi Baru',
          body: notification.body ?? '',
          payload: message.data['notifType'],
        );
      }
    });

    // Notification tapped while app was in background (not killed)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Notification opened app: ${message.notification?.title}');
      // Deep-linking can be added here
    });

    // Configure foreground notification presentation (iOS)
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    debugPrint('[LocalNotif] Tapped: ${response.payload}');
    // Deep-linking can be added here in the future
  }

  // ── Show a local notification ─────────────────────────────────────────────

  Future<void> show({
    required String title,
    required String body,
    String? payload,
    NotifPriority priority = NotifPriority.high,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: priority == NotifPriority.high
          ? Importance.high
          : Importance.defaultImportance,
      priority: priority == NotifPriority.high
          ? Priority.high
          : Priority.defaultPriority,
      icon: _defaultIcon,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(_nextId, title, body, details, payload: payload);
  }

  // ── Convenience method ────────────────────────────────────────────────────

  Future<void> showTransactionNotification({
    required String notifType,
    required String title,
    required String message,
  }) async {
    await show(
      title: title,
      body: message,
      payload: notifType,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

enum NotifPriority { high }
