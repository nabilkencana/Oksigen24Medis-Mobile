import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for showing system-level background notifications.
/// Works when the app is in the background (minimised).
/// For fully-closed-app notifications, FCM is required (out of scope here).
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Notification channel IDs ────────────────────────────────────────────────
  static const String _channelId = 'oksigen24_transactions';
  static const String _channelName = 'Transaksi';
  static const String _channelDesc =
      'Notifikasi setiap transaksi baru: sewa, penjualan, isi ulang, dll.';

  // ── Notification ID counter (using hashCode to stay unique per notif) ───────
  int _idCounter = 0;
  int get _nextId => ++_idCounter;

  // ── Icon per notification type ──────────────────────────────────────────────
  // Android notification icon must be a white-on-transparent PNG in drawable/.
  // We use @mipmap/ic_launcher as a fallback (works on most devices).
  static const String _defaultIcon = '@mipmap/ic_launcher';

  // ── Initialization ──────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings(_defaultIcon);

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
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request Android 13+ POST_NOTIFICATIONS permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[LocalNotificationService] Initialized ✓');
  }

  void _onNotificationTapped(NotificationResponse response) {
    // When the user taps the notification, the app comes to foreground.
    // Deep-linking can be added here in the future.
    debugPrint(
        '[LocalNotificationService] Notification tapped: ${response.payload}');
  }

  // ── Show a notification ─────────────────────────────────────────────────────

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

    await _plugin.show(
      _nextId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ── Convenience helpers per transaction type ─────────────────────────────────

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

  // ── Cancel all ───────────────────────────────────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

enum NotifPriority { high }
