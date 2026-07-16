import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/core/state/auth_provider.dart';
import 'package:oksigen24medis_mobile2/core/state/dashboard_provider.dart';
import 'package:oksigen24medis_mobile2/features/rental/rental_form_screen.dart';
import 'package:oksigen24medis_mobile2/features/refill/refill_form_screen.dart';
import 'package:oksigen24medis_mobile2/features/sales/sales_form_screen.dart';
import 'package:oksigen24medis_mobile2/features/return/return_form_screen.dart';
import 'package:oksigen24medis_mobile2/features/transaction/transaction_history_screen.dart';
import 'package:oksigen24medis_mobile2/features/warehouse/warehouse_screen.dart';
import 'package:oksigen24medis_mobile2/features/profile/profile_screen.dart';
import 'package:oksigen24medis_mobile2/features/notification/notification_screen.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).fetchSummary();
    });
  }

  // Helper function to format currency manually
  String _formatCurrency(num amount) {
    final cleanAmount = amount.round();
    final valueStr = cleanAmount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < valueStr.length; i++) {
      if (i > 0 && (valueStr.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(valueStr[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  // Helper to format date cleanly
  String _getTodayString() {
    final now = DateTime.now();
    final days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  // ── Quick action data ─────────────────────────────────────────────────────
  static const List<_QuickActionData> _quickActions = [
    _QuickActionData(
      label: 'Kontrak Sewa',
      icon: Icons.medical_services_rounded,
      allowedRoles: ['OWNER', 'ADMIN', 'WAREHOUSE', 'FINANCE'],
    ),
    _QuickActionData(
      label: 'Isi Ulang',
      icon: Icons.ev_station_rounded,
      allowedRoles: ['OWNER', 'ADMIN', 'WAREHOUSE', 'FINANCE'],
    ),
    _QuickActionData(
      label: 'Penjualan',
      icon: Icons.shopping_cart_rounded,
      allowedRoles: ['OWNER', 'ADMIN', 'FINANCE', 'WAREHOUSE'],
    ),
    _QuickActionData(
      label: 'Pengembalian',
      icon: Icons.assignment_return_rounded,
      allowedRoles: ['OWNER', 'ADMIN', 'WAREHOUSE', 'FINANCE'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final dashboardProvider = Provider.of<DashboardProvider>(context);

    Widget currentBody;
    PreferredSizeWidget? currentAppBar;

    if (_selectedIndex == 0) {
      currentAppBar = PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _buildAppBar(
          authProvider,
          (dashboardProvider.summary?['lowStockCount'] as int? ?? 0) > 0,
        ),
      );
      currentBody = RefreshIndicator(
        onRefresh: () => dashboardProvider.fetchSummary(),
        color: AppColors.primary,
        child: _buildDashboardContent(dashboardProvider, authProvider),
      );
    } else if (_selectedIndex == 1) {
      currentAppBar = null;
      currentBody = const TransactionHistoryScreen();
    } else if (_selectedIndex == 2) {
      currentAppBar = null;
      currentBody = const WarehouseScreen();
    } else {
      currentAppBar = null;
      currentBody = const ProfileScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: currentAppBar,
      body: currentBody,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar(AuthProvider auth, bool hasUnread) {
    final name = auth.currentUser?['fullName'] ?? 'Staff Kasir';
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      toolbarHeight: 64,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(
          color: const Color(0xFFC3C5D9).withAlpha(128),
          height: 0.5,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $name',
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _getTodayString(),
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF646464),
                  ),
                ),
              ],
            ),
          ),
          // Notification bell — 44px touch target
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_outlined, size: 24),
                  color: AppColors.primary,
                  padding: EdgeInsets.zero,
                ),
                if (hasUnread)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Main Content Area ──────────────────────────────────────────────────────
  Widget _buildDashboardContent(DashboardProvider provider, AuthProvider auth) {
    if (provider.isLoading && provider.summary == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (provider.error != null && provider.summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal menyambung ke server',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => provider.fetchSummary(),
                child: const Text(
                  'Coba Lagi',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final summary = provider.summary ?? {};
    final activeRentals = summary['activeRentals'] ?? 0;
    final vendorCylinders = summary['vendorCylinders'] ?? 0;
    final lowStockCount = summary['lowStockCount'] ?? 0;
    final todayRevenue = summary['todayRevenue'] ?? 0;
    final List<dynamic> recentActivities = summary['recentActivities'] ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Grid Cards
          _buildKpiSection(
            activeRentals,
            vendorCylinders,
            lowStockCount,
            todayRevenue,
          ),
          const SizedBox(height: 24.0),

          // Quick actions grid
          _buildQuickActions(auth),
          const SizedBox(height: 24.0),

          // Dynamic Activities
          _buildActivitySection(recentActivities),
        ],
      ),
    );
  }

  // ── KPI horizontal scroll ─────────────────────────────────────────────────
  Widget _buildKpiSection(
    int activeRentals,
    int vendorCylinders,
    int lowStockCount,
    num todayRevenue,
  ) {
    final kpis = [
      _KpiData(
        label: 'Tabung Disewa',
        value: '$activeRentals',
        hasBadge: vendorCylinders > 0,
        badgeValue: '$vendorCylinders Di Vendor',
        subLabel: 'Hingga hari ini',
        accentBorder: false,
        valueColor: AppColors.textPrimary,
      ),
      _KpiData(
        label: 'Stok Kritis',
        value: '$lowStockCount Item',
        hasBadge: false,
        badgeValue: '',
        subLabel: 'Perlu diisi ulang segera',
        accentBorder: true,
        valueColor: AppColors.warning,
      ),
      _KpiData(
        label: 'Pendapatan Hari Ini',
        value: _formatCurrency(todayRevenue),
        hasBadge: false,
        badgeValue: '',
        subLabel: 'Update realtime',
        accentBorder: false,
        valueColor: AppColors.primary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RINGKASAN UTAMA',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF434656),
                letterSpacing: 0.5,
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.swipe_left_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Geser ke samping',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kpis.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _KpiCard(data: kpis[index]),
          ),
        ),
      ],
    );
  }

  // ── Quick actions grid ────────────────────────────────────────────────────
  Widget _buildQuickActions(AuthProvider auth) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12.0,
      mainAxisSpacing: 12.0,
      childAspectRatio: 1.3,
      children: _quickActions.map((a) {
        return _QuickActionButton(
          data: a,
          onTap: () {
            // RBAC role check
            if (!auth.hasRole(a.allowedRoles)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Akses Ditolak: Peran Anda (${auth.userRole}) tidak diizinkan mengakses menu ini.',
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
              return;
            }

            // Route mapping
            if (a.label == 'Kontrak Sewa') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RentalFormScreen(),
                ),
              );
            } else if (a.label == 'Isi Ulang') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RefillFormScreen(),
                ),
              );
            } else if (a.label == 'Penjualan') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SalesFormScreen(),
                ),
              );
            } else if (a.label == 'Pengembalian') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ReturnFormScreen(),
                ),
              );
            }
          },
        );
      }).toList(),
    );
  }

  // ── Recent activity ───────────────────────────────────────────────────────
  Widget _buildActivitySection(List<dynamic> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Aktivitas Terbaru', style: AppTextStyles.h3),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Lihat Semua',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (activities.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC3C5D9).withAlpha(77)),
            ),
            child: const Center(
              child: Text(
                'Belum ada aktivitas hari ini',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length > 5 ? 5 : activities.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final act = activities[index];
              final isOut = act['type'] == 'OUT';
              final String time = act['createdAt'] != null
                  ? DateTime.parse(
                      act['createdAt'],
                    ).toLocal().toString().substring(11, 16)
                  : '--:--';

              // Map generic action to transactional name and colors
              String title = isOut ? 'Stok Keluar' : 'Stok Masuk';
              IconData icon = isOut
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded;
              Color iconBg = isOut
                  ? const Color(0xFFFFDBD1)
                  : const Color(0xFFE6F4EA);
              Color iconColor = isOut ? const Color(0xFF972500) : AppColors.success;

              final String refType = act['referenceType']?.toString().toUpperCase() ?? '';
              final String itemName = act['itemName']?.toString().toLowerCase() ?? '';

              if (refType == 'RENTAL') {
                title = 'Sewa Kontrak Baru';
                icon = Icons.assignment_outlined;
                iconBg = const Color(0xFFE2F0FD); // Soft medical blue
                iconColor = const Color(0xFF0B66C2);
              } else if (refType == 'RETURN') {
                title = 'Pengembalian Tabung';
                icon = Icons.assignment_return_outlined;
                iconBg = const Color(0xFFE6F4EA); // Soft green success
                iconColor = AppColors.success;
              } else if (refType == 'VENDOR_REFILL') {
                title = isOut ? 'Kirim Isi Ulang (Vendor)' : 'Terima Isi Ulang (Vendor)';
                icon = Icons.loop_rounded;
                iconBg = const Color(0xFFFFF3CD); // Warning warningLight
                iconColor = const Color(0xFFB7791F);
              } else if (refType == 'SALE') {
                if (itemName.contains('refill') || itemName.contains('isi ulang') || itemName.contains('isi')) {
                  title = 'Isi Ulang Oksigen';
                  icon = Icons.local_gas_station_rounded;
                  iconBg = const Color(0xFFE0F2FE); // sky blue
                  iconColor = const Color(0xFF0369A1);
                } else {
                  title = 'Penjualan Barang';
                  icon = Icons.shopping_bag_outlined;
                  iconBg = const Color(0xFFF1F5F9); // cool gray
                  iconColor = const Color(0xFF475569);
                }
              } else if (refType == 'PURCHASE') {
                title = 'Pembelian Stok';
                icon = Icons.add_shopping_cart_rounded;
                iconBg = const Color(0xFFF3E8FF); // soft purple
                iconColor = const Color(0xFF7E22CE);
              }

              final mappedAct = _ActivityData(
                title: title,
                subtitle:
                    '${act['itemName']} - ${act['quantity']} Pcs (${act['createdBy'] is Map ? (act['createdBy']['fullName'] ?? 'Staff') : (act['createdBy'] ?? 'Staff')})',
                time: '$time WIB',
                icon: icon,
                iconBg: iconBg,
                iconColor: iconColor,
              );

              return _ActivityItem(data: mappedAct);
            },
          ),
      ],
    );
  }

  // ── Bottom Navigation Bar ─────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      _NavItem(icon: Icons.home_rounded, label: 'Beranda'),
      _NavItem(icon: Icons.receipt_long_rounded, label: 'Transaksi'),
      _NavItem(icon: Icons.inventory_2_rounded, label: 'Gudang'),
      _NavItem(icon: Icons.person_rounded, label: 'Profil'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFC3C5D9), width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              items.length,
              (i) => _BottomNavItem(
                item: items[i],
                isActive: i == _selectedIndex,
                onTap: () => setState(() => _selectedIndex = i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models (private)
// ─────────────────────────────────────────────────────────────────────────────
class _KpiData {
  final String label;
  final String value;
  final bool hasBadge;
  final String badgeValue;
  final String subLabel;
  final bool accentBorder;
  final Color valueColor;

  const _KpiData({
    required this.label,
    required this.value,
    required this.hasBadge,
    required this.badgeValue,
    required this.subLabel,
    required this.accentBorder,
    required this.valueColor,
  });
}

class _QuickActionData {
  final String label;
  final IconData icon;
  final List<String> allowedRoles;

  const _QuickActionData({
    required this.label,
    required this.icon,
    required this.allowedRoles,
  });
}

class _ActivityData {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _ActivityData({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// _KpiCard — glass card style, min-width 200, no overflow
// ─────────────────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(217), // rgba(255,255,255,0.85)
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000), // rgba(0,0,0,0.04)
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            if (data.accentBorder)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: Container(color: AppColors.warning),
              ),
            Padding(
              padding: EdgeInsets.only(
                left: data.accentBorder ? 20 : 16,
                right: 16,
                top: 14,
                bottom: 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Label
                  Text(
                    data.label,
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF5E5E5E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Value + badge row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        data.value,
                        style: AppTextStyles.kpiNumber.copyWith(
                          fontSize:
                              20, // slightly smaller to avoid currency overflow
                          color: data.valueColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Sub label or badge details
                  Text(
                    data.hasBadge ? data.badgeValue : data.subLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: data.hasBadge
                          ? AppColors.primary
                          : const Color(0xFF737688),
                      fontWeight: data.hasBadge
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuickActionButton — min-h 140px equivalent, icon 56×56
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionButton extends StatelessWidget {
  final _QuickActionData data;
  final VoidCallback onTap;
  const _QuickActionButton({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primaryLight,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent, // Let Material control background
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon circle — primary-container/10
              Container(
                width: (data.label == 'Kontrak Sewa' || data.label == 'Isi Ulang') ? 80 : 56,
                height: (data.label == 'Kontrak Sewa' || data.label == 'Isi Ulang') ? 80 : 56,
                decoration: BoxDecoration(
                  color: (data.label == 'Kontrak Sewa' || data.label == 'Isi Ulang') ? Colors.transparent : AppColors.primary.withAlpha(26), // /10 opacity
                  shape: BoxShape.circle,
                ),
                child: data.label == 'Kontrak Sewa'
                    ? Center(
                        child: Image.asset(
                          'assets/images/kontrak_sewa.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      )
                    : data.label == 'Isi Ulang'
                        ? Center(
                            child: Image.asset(
                              'assets/images/isi_ulang.png',
                              width: 80,
                              height: 80,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Icon(data.icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                data.label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActivityItem — icon left, [title + time] row, subtitle below
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityItem extends StatelessWidget {
  final _ActivityData data;
  const _ActivityItem({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC3C5D9).withAlpha(77)), // /30
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: data.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      data.time,
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xFF737688),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF646464),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BottomNavItem — active uses primary, inactive is secondary text
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: isActive
            ? const EdgeInsets.symmetric(horizontal: 18, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isActive
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: AppColors.surface, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.surface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: const Color(0xFF646464), size: 22),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF646464),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
