import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/core/state/notification_provider.dart';

export 'package:oksigen24medis_mobile2/core/state/notification_provider.dart'
    show AppNotification, NotificationType;

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _formatAmount(double amount) {
    final str = amount.round().toString();
    final buffer = StringBuffer('Rp ');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false)
          .fetchNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  NotificationType _typeFromCategory(String cat) {
    switch (cat) {
      case 'success':
        return NotificationType.success;
      case 'warning':
        return NotificationType.warning;
      case 'alert':
        return NotificationType.alert;
      default:
        return NotificationType.info;
    }
  }

  Color _getColor(NotificationType t) {
    switch (t) {
      case NotificationType.success:
        return const Color(0xFF00B87A);
      case NotificationType.warning:
        return const Color(0xFFFF9500);
      case NotificationType.alert:
        return const Color(0xFFFF3B30);
      case NotificationType.info:
        return AppColors.primary;
    }
  }

  Color _getBgColor(NotificationType t) {
    switch (t) {
      case NotificationType.success:
        return const Color(0xFFE6FAF4);
      case NotificationType.warning:
        return const Color(0xFFFFF4E6);
      case NotificationType.alert:
        return const Color(0xFFFFEBEA);
      case NotificationType.info:
        return const Color(0xFFF0F3FF);
    }
  }

  IconData _getIcon(String notifType) {
    switch (notifType) {
      case 'RENTAL':
        return Icons.assignment_outlined;
      case 'RETURN':
        return Icons.assignment_return_outlined;
      case 'SALE':
        return Icons.shopping_cart_outlined;
      case 'CUSTOMER_REFILL':
        return Icons.local_gas_station_outlined;
      case 'VENDOR_SEND':
        return Icons.local_shipping_outlined;
      case 'VENDOR_RECEIVE':
        return Icons.move_to_inbox_outlined;
      case 'PURCHASE':
        return Icons.inventory_2_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    final months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agt','Sep','Okt','Nov','Des'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // ── Notification Card ───────────────────────────────────────────────────────

  Widget _buildCard(AppNotification item, NotificationProvider provider) {
    final type = _typeFromCategory(item.category);
    final color = _getColor(type);
    final bg = _getBgColor(type);
    final icon = _getIcon(item.notifType);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade50, Colors.red.shade100],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 22),
            const SizedBox(height: 2),
            Text(
              'Hapus',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        provider.dismiss(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notifikasi "${item.title}" dihapus'),
            backgroundColor: AppColors.textSecondary,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          provider.markAsRead(item.id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: item.isRead ? AppColors.surface : bg.withAlpha(120),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead
                  ? const Color(0xFFECEFF3)
                  : color.withAlpha(60),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: item.isRead
                    ? Colors.black.withAlpha(5)
                    : color.withAlpha(15),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withAlpha(40), width: 1),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),

                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: item.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Unread dot + time
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!item.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(bottom: 3),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Text(
                                _formatTime(item.createdAt),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        item.message,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 6),

                      // Footer row
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 11,
                            color: AppColors.textSecondary.withAlpha(160),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.createdBy,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary.withAlpha(160),
                              fontSize: 10,
                            ),
                          ),
                          if (item.amount != null) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _formatAmount(item.amount!),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmpty(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F3FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_outlined,
              size: 38,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Semua aktivitas operasional terpantau aman.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Main Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotificationProvider>(context);
    final all = provider.notifications;
    final unread = all.where((n) => !n.isRead).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifikasi',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (provider.unreadCount > 0)
              Text(
                '${provider.unreadCount} belum dibaca',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        actions: [
          if (all.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all_rounded,
                  color: AppColors.primary, size: 22),
              tooltip: 'Tandai semua dibaca',
              onPressed: () {
                HapticFeedback.lightImpact();
                provider.markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Semua notifikasi ditandai dibaca'),
                    backgroundColor: AppColors.success,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          if (all.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined,
                  color: Colors.red.shade400, size: 22),
              tooltip: 'Hapus semua',
              onPressed: () {
                HapticFeedback.lightImpact();
                _showClearAllDialog(provider);
              },
            ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: [
            Tab(text: 'Semua (${all.length})'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Belum Dibaca'),
                  if (unread.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${unread.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: provider.isLoading && all.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => provider.fetchNotifications(),
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: All
                  all.isEmpty
                      ? _buildEmpty('Tidak ada notifikasi')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          itemCount: all.length,
                          itemBuilder: (_, i) => _buildCard(all[i], provider),
                        ),

                  // Tab 2: Unread
                  unread.isEmpty
                      ? _buildEmpty('Tidak ada notifikasi baru')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          itemCount: unread.length,
                          itemBuilder: (_, i) =>
                              _buildCard(unread[i], provider),
                        ),
                ],
              ),
            ),
    );
  }

  void _showClearAllDialog(NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Semua Notifikasi'),
        content: const Text(
            'Semua notifikasi akan dihapus dari tampilan. Data transaksi tidak terpengaruh.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              provider.clearAll();
            },
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }
}

// ── In-App Toast Widget (used in DashboardScreen) ────────────────────────────

class TransactionToast extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;

  const TransactionToast({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<TransactionToast> createState() => _TransactionToastState();
}

class _TransactionToastState extends State<TransactionToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim =
        Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, 0.5),
    ));

    _ctrl.forward();

    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  Color _getColor() {
    switch (widget.notification.category) {
      case 'success':
        return const Color(0xFF00B87A);
      case 'warning':
        return const Color(0xFFFF9500);
      case 'alert':
        return const Color(0xFFFF3B30);
      default:
        return AppColors.primary;
    }
  }

  IconData _getIcon() {
    switch (widget.notification.notifType) {
      case 'RENTAL':
        return Icons.assignment_outlined;
      case 'RETURN':
        return Icons.assignment_return_outlined;
      case 'SALE':
        return Icons.shopping_cart_outlined;
      case 'CUSTOMER_REFILL':
        return Icons.local_gas_station_outlined;
      case 'VENDOR_SEND':
        return Icons.local_shipping_outlined;
      case 'VENDOR_RECEIVE':
        return Icons.move_to_inbox_outlined;
      case 'PURCHASE':
        return Icons.inventory_2_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            margin: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 8,
              16,
              0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha(60), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(40),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getIcon(), color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.notification.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.notification.message,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF6B7280),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _dismiss,
                  child: Icon(Icons.close_rounded,
                      size: 18, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
