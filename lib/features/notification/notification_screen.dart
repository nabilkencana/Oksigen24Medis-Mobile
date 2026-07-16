import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/core/state/dashboard_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<AppNotification>? _loadedNotifications;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).fetchSummary(silent: true);
    });
  }

  void _initializeNotifications(Map<String, dynamic> summary) {
    if (_loadedNotifications != null) return;
    
    final List<AppNotification> list = [];
    
    // 1. Map lowStockItems (Warning alerts)
    final lowStock = summary['lowStockItems'] as List? ?? [];
    for (var item in lowStock) {
      list.add(AppNotification(
        id: 'low_${item['id']}',
        title: 'Peringatan Stok Rendah',
        message: 'Stok ${item['name']} tersisa ${item['currentStock']} unit (Stok minimum: ${item['minStock']} unit).',
        time: 'Baru saja',
        type: NotificationType.warning,
        isRead: false,
      ));
    }
    
    // 2. Map recentActivities (Dynamic log notifications)
    final activities = summary['recentActivities'] as List? ?? [];
    for (var m in activities) {
      NotificationType nType = NotificationType.info;
      final type = m['type'] as String? ?? '';
      
      if (type.contains('RENT') || type.contains('SALE') || type.contains('OUT')) {
        nType = NotificationType.success;
      } else if (type.contains('RETURN') || type.contains('IN')) {
        nType = NotificationType.info;
      } else if (type.contains('ALERT') || type.contains('OVERDUE')) {
        nType = NotificationType.alert;
      }
      
      String timeStr = 'Baru saja';
      if (m['createdAt'] != null) {
        try {
          final dt = DateTime.parse(m['createdAt']);
          timeStr = _formatRelativeTime(dt);
        } catch (_) {}
      }

      list.add(AppNotification(
        id: 'act_${m['id']}',
        title: '${m['type']} - ${m['itemName']}',
        message: 'Aktivitas ${m['type']} sebanyak ${m['quantity']} unit dilakukan oleh ${m['createdBy'] is Map ? (m['createdBy']['fullName'] ?? 'Staff') : (m['createdBy'] ?? 'Staff')}.',
        time: timeStr,
        type: nType,
        isRead: true, // Mark operational log activities as read by default
      ));
    }
    
    _loadedNotifications = list;
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) {
      return 'Baru saja';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} menit lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    } else {
      return '${diff.inDays} hari lalu';
    }
  }

  void _markAllAsRead() {
    if (_loadedNotifications == null) return;
    setState(() {
      for (var n in _loadedNotifications!) {
        n.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua notifikasi ditandai telah dibaca'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _loadedNotifications?.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua notifikasi dihapus'),
        backgroundColor: AppColors.textSecondary,
      ),
    );
  }

  void _dismissNotification(int index) {
    if (_loadedNotifications == null) return;
    final removed = _loadedNotifications![index];
    setState(() {
      _loadedNotifications!.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notifikasi "${removed.title}" dihapus'),
        action: SnackBarAction(
          label: 'BATAL',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _loadedNotifications!.insert(index, removed);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);
    final summary = dashboard.summary;

    if (dashboard.isLoading && _loadedNotifications == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (summary != null) {
      _initializeNotifications(summary);
    }

    final notifications = _loadedNotifications ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifikasi',
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: notifications.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.done_all, color: AppColors.primary),
                  tooltip: 'Tandai semua dibaca',
                  onPressed: _markAllAsRead,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
                  tooltip: 'Hapus semua',
                  onPressed: _clearAll,
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_none_outlined,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada notifikasi baru',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Semua aktivitas operasional Anda terpantau aman.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Dismissible(
                  key: Key(item.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (dir) => _dismissNotification(index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: item.isRead ? AppColors.surface : const Color(0xFFF4F6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.isRead ? const Color(0xFFECEFF3) : AppColors.primary.withAlpha(38),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getBgColorForType(item.type),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconForType(item.type),
                          color: _getColorForType(item.type),
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            item.time,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          item.message,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          item.isRead = true;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.warning:
        return AppColors.warning;
      case NotificationType.alert:
        return AppColors.error;
      case NotificationType.success:
        return AppColors.success;
      case NotificationType.info:
        return AppColors.primary;
    }
  }

  Color _getBgColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.warning:
        return const Color(0xFFFFF7EC);
      case NotificationType.alert:
        return const Color(0xFFFCE8E6);
      case NotificationType.success:
        return const Color(0xFFE6F4EA);
      case NotificationType.info:
        return const Color(0xFFF1F3FF);
    }
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.alert:
        return Icons.error_outline_rounded;
      case NotificationType.success:
        return Icons.check_circle_outline_rounded;
      case NotificationType.info:
        return Icons.info_outline_rounded;
    }
  }
}

enum NotificationType { warning, alert, success, info }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String time;
  final NotificationType type;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    required this.isRead,
  });
}
