import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oksigen24medis_mobile2/core/services/api_service.dart';
import 'package:oksigen24medis_mobile2/core/services/websocket_service.dart';
import 'package:oksigen24medis_mobile2/core/services/local_notification_service.dart';

class AppNotification {
  final String id;
  final String notifType;
  final String title;
  final String message;
  final String category; // 'success' | 'info' | 'warning' | 'alert'
  final double? amount;
  final DateTime createdAt;
  final String createdBy;
  bool isRead;

  AppNotification({
    required this.id,
    required this.notifType,
    required this.title,
    required this.message,
    required this.category,
    this.amount,
    required this.createdAt,
    required this.createdBy,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      notifType: json['notifType'] as String? ?? '',
      title: json['title'] as String,
      message: json['message'] as String,
      category: json['category'] as String? ?? 'info',
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      createdBy: json['createdBy'] as String? ?? 'Staff',
    );
  }
}

enum NotificationType { success, info, warning, alert }

class NotificationProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<AppNotification> _notifications = [];
  Set<String> _readIds = {};
  bool _isLoading = false;
  String? _error;

  // Stores the newest notification to show as in-app toast
  AppNotification? _incomingToast;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AppNotification? get incomingToast => _incomingToast;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  static const String _readIdsKey = 'notification_read_ids';

  NotificationProvider() {
    // Initialize local notification service (request permissions, create channel)
    LocalNotificationService.instance.initialize();
    _loadReadIds().then((_) => fetchNotifications());
    WebSocketService().dbChangeEvent.addListener(_onDbChange);
  }

  @override
  void dispose() {
    WebSocketService().dbChangeEvent.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    final path = WebSocketService().dbChangeEvent.value;
    if (path == null) return;

    // Only refresh for transaction-relevant paths
    final isTransactionPath = path.contains('/transactions') ||
        path.contains('/rentals') ||
        path.contains('/sales') ||
        path.contains('/refills') ||
        path.contains('/purchases');

    if (isTransactionPath) {
      debugPrint('[NotificationProvider] WebSocket db_change on: $path — refreshing notifications');
      fetchNotifications(showToast: true);
    }
  }

  Future<void> _loadReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_readIdsKey) ?? [];
      _readIds = stored.toSet();
    } catch (_) {}
  }

  Future<void> _saveReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_readIdsKey, _readIds.toList());
    } catch (_) {}
  }

  Future<void> fetchNotifications({bool showToast = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.get('/dashboard/notifications');
      final List<dynamic> raw = _api.handleResponse(response) as List<dynamic>;

      final previousLatestId = _notifications.isNotEmpty ? _notifications.first.id : null;

      _notifications = raw.map((e) {
        final n = AppNotification.fromJson(e as Map<String, dynamic>);
        n.isRead = _readIds.contains(n.id);
        return n;
      }).toList();

      // Detect new top notification for toast + background notification
      if (showToast && _notifications.isNotEmpty) {
        final latestNotif = _notifications.first;
        if (previousLatestId != null &&
            latestNotif.id != previousLatestId &&
            !latestNotif.isRead) {
          // 1. Show in-app toast (when app is in foreground)
          _incomingToast = latestNotif;

          // 2. Show system notification (visible even when app is minimized/background)
          LocalNotificationService.instance.showTransactionNotification(
            notifType: latestNotif.notifType,
            title: latestNotif.title,
            message: latestNotif.message,
          );
        }
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('[NotificationProvider] Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
      _readIds.add(id);
      _saveReadIds();
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
      _readIds.add(n.id);
    }
    _saveReadIds();
    notifyListeners();
  }

  void clearToast() {
    _incomingToast = null;
    // no notifyListeners needed — caller handles UI
  }

  void dismiss(String id) {
    _notifications.removeWhere((n) => n.id == id);
    // Mark as read so it doesn't reappear as unread if refreshed
    _readIds.add(id);
    _saveReadIds();
    notifyListeners();
  }

  void clearAll() {
    for (final n in _notifications) {
      _readIds.add(n.id);
    }
    _notifications.clear();
    _saveReadIds();
    notifyListeners();
  }
}
