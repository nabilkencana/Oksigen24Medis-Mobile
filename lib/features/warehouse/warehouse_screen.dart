import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/core/services/api_service.dart';
import 'package:oksigen24medis_mobile2/core/state/auth_provider.dart';
import 'package:oksigen24medis_mobile2/core/state/warehouse_provider.dart';
import 'package:oksigen24medis_mobile2/features/warehouse/stock_detail_screen.dart';
import 'package:oksigen24medis_mobile2/features/warehouse/scanner_screen.dart';
import 'package:provider/provider.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedChipIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WarehouseProvider>(context, listen: false).fetchInventory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _mapOxygenTypeName(String name) {
    final lowercase = name.toLowerCase();
    if (lowercase == 'medical oxygen 99.5%' || lowercase == 'medical oxygen') {
      return 'Tabung Oksigen';
    }
    return name;
  }

  // Helper to group actual cylinders by oxygenType & size
  List<Map<String, dynamic>> _getGroupedCylinders(List<dynamic> list) {
    final Map<String, List<dynamic>> grouped = {};
    for (var cyl in list) {
      final String otNameRaw = cyl['oxygenType']?['name'] ?? 'Medical Oxygen';
      final String otName = _mapOxygenTypeName(otNameRaw);
      final String size = cyl['size'] ?? '6m3';
      final key = '$otName ($size)';
      grouped.putIfAbsent(key, () => []).add(cyl);
    }

    return grouped.entries.map((e) {
      final items = e.value;
      final tersedia = items.where((i) => i['status'] == 'AVAILABLE').length;
      final kosong = items.where((i) => i['status'] == 'EMPTY').length;
      final disewa = items.where((i) => i['status'] == 'RENTED').length;
      final vendor = items.where((i) => i['status'] == 'AT_VENDOR').length;
      final maintenance = items
          .where((i) => i['status'] == 'MAINTENANCE')
          .length;

      return {
        'type': 'cylinder',
        'title': e.key,
        'sku': 'SKU: CYL-${items.first['size'] ?? 'UNIT'}',
        'total': items.length,
        'tersedia': tersedia,
        'kosong': kosong,
        'disewa': disewa,
        'vendor': vendor,
        'maintenance': maintenance,
      };
    }).toList();
  }

  // Helper to group rentable accessories
  List<Map<String, dynamic>> _getGroupedRentables(List<dynamic> list) {
    final Map<String, List<dynamic>> grouped = {};
    for (var cyl in list) {
      final String otName = cyl['oxygenType']?['name'] ?? 'Aksesoris Sewa';
      final key = otName;
      grouped.putIfAbsent(key, () => []).add(cyl);
    }

    return grouped.entries.map((e) {
      final items = e.value;
      final tersedia = items.where((i) => i['status'] == 'AVAILABLE').length;
      final disewa = items.where((i) => i['status'] == 'RENTED').length;
      final maintenance = items
          .where((i) => i['status'] == 'MAINTENANCE')
          .length;

      return {
        'type': 'rentable',
        'title': e.key,
        'sku': 'SKU: RNT-ACC',
        'total': items.length,
        'tersedia': tersedia,
        'disewa': disewa,
        'maintenance': maintenance,
      };
    }).toList();
  }

  // List of all items fetched from backend (mapped to visual card format)
  List<Map<String, dynamic>> _buildMappedItems(WarehouseProvider provider) {
    final List<Map<String, dynamic>> list = [];

    // Chip 1 or Chip 0
    if (_selectedChipIndex == 0 || _selectedChipIndex == 1) {
      list.addAll(_getGroupedCylinders(provider.actualCylinders));
    }

    // Chip 2 or Chip 0
    if (_selectedChipIndex == 0 || _selectedChipIndex == 2) {
      list.addAll(_getGroupedRentables(provider.rentableAccessories));
    }

    // Chip 3 or Chip 0
    if (_selectedChipIndex == 0 || _selectedChipIndex == 3) {
      for (var prod in provider.products) {
        list.add({
          'type': 'sellable',
          'title': prod['name'] ?? 'Produk Medis',
          'sku': prod['sku'] ?? 'SKU: PROD-001',
          'tersedia': prod['currentStock'] ?? 0,
        });
      }
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      return list.where((i) {
        final title = (i['title'] ?? '').toString().toLowerCase();
        final sku = (i['sku'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery) || sku.contains(_searchQuery);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final provider = Provider.of<WarehouseProvider>(context);

    final mappedItems = _buildMappedItems(provider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // Light off-white
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 40,
        title: Text(
          'Stok Gudang',
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.qr_code_scanner,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ScannerScreen()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            color: const Color(0xFFC3C5D9).withAlpha(128),
            height: 0.5,
          ),
        ),
      ),
      body: provider.isLoading && provider.cylinders.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: () => provider.fetchInventory(),
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Horizontal Summaries
                    _buildSummarySection(provider),
                    // Search box
                    _buildSearchBox(),
                    // Filter category chips
                    _buildFilterChips(),
                    const SizedBox(height: 16),
                    // Product / Cylinder list
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: mappedItems.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(32),
                              child: const Center(
                                child: Text(
                                  'Barang tidak ditemukan',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: mappedItems.length,
                              itemBuilder: (context, index) {
                                final item = mappedItems[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _renderItemCard(item),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 100), // Spacer for FAB
                  ],
                ),
              ),
            ),
      // RBAC: Disable Stok Masuk button if role is FINANCE
      floatingActionButton: auth.userRole == 'FINANCE'
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddStockBottomSheet(context, provider),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.surface,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add, size: 28),
            ),
    );
  }

  // ── Render Card Selector Helper ───────────────────────────────────────────
  Widget _renderItemCard(Map<String, dynamic> item) {
    final String type = item['type'];
    if (type == 'cylinder') {
      return _buildCylinderCard(
        item['title'],
        item['sku'],
        item['total'],
        item['tersedia'],
        item['kosong'],
        item['disewa'],
        item['vendor'],
        item['maintenance'],
      );
    } else if (type == 'rentable') {
      return _buildRentableCard(
        item['title'],
        item['sku'],
        item['total'],
        item['tersedia'],
        item['disewa'],
        item['maintenance'],
      );
    } else {
      return _buildSellableCard(item['title'], item['sku'], item['tersedia']);
    }
  }

  // ── TOP SUMMARY CARDS ──────────────────────────────────────────────────────
  Widget _buildSummarySection(WarehouseProvider provider) {
    final tabungCount = provider.actualCylinders.length;
    final tersediaCount = provider.getCountByStatus('AVAILABLE');
    final kosongCount = provider.getCountByStatus('EMPTY');
    final rusakCount =
        provider.getCountByStatus('MAINTENANCE') +
        provider.getCountByStatus('AT_VENDOR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 8.0,
          ),
          child: Row(
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
        ),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildSummaryCard(
                'Tabung',
                '$tabungCount',
                'Aset Terdaftar',
                const Color(0xFF0055FF),
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                'Tersedia',
                '$tersediaCount',
                'Siap disewakan',
                const Color(0xFF00A67E),
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                'Kosong',
                '$kosongCount',
                'Perlu isi ulang',
                const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                'Rusak / Maint',
                '$rusakCount',
                'Dalam perbaikan',
                const Color(0xFFEF4444),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String count,
    String subtitle,
    Color color,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x02000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                count,
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 22,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Unit',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: const Color(0xFF8E92A4),
            ),
          ),
        ],
      ),
    );
  }

  // ── SEARCH BOX ─────────────────────────────────────────────────────────────
  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextFormField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari SKU atau nama tabung...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          fillColor: AppColors.surface,
          filled: true,
        ),
      ),
    );
  }

  // ── FILTER CHIPS ───────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    final chips = [
      'Semua',
      'Tabung Oksigen',
      'Aksesoris Sewa',
      'Alat Medis Jual',
    ];
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == _selectedChipIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedChipIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                chips[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── CYLINDER CARD ──────────────────────────────────────────────────────────
  Widget _buildCylinderCard(
    String title,
    String sku,
    int total,
    int tersedia,
    int kosong,
    int disewa,
    int vendor,
    int maintenance,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StockDetailScreen(
              title: title,
              sku: sku,
              total: total,
              tersedia: tersedia,
              kosong: kosong,
              disewa: disewa,
              vendor: vendor,
              maintenance: maintenance,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEFF5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sku,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Stok',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total',
                      style: AppTextStyles.h2.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(color: Color(0xFFECEFF5), height: 1),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.0,
              crossAxisSpacing: 8,
              mainAxisSpacing: 12,
              children: [
                _buildGridStatusItem(
                  'Tersedia',
                  '$tersedia',
                  const Color(0xFF00A67E),
                ),
                _buildGridStatusItem(
                  'Kosong',
                  '$kosong',
                  const Color(0xFFF59E0B),
                ),
                _buildGridStatusItem(
                  'Disewa',
                  '$disewa',
                  const Color(0xFF0055FF),
                ),
                _buildGridStatusItem(
                  'Di Vendor',
                  '$vendor',
                  const Color(0xFF8B5CF6),
                ),
                _buildGridStatusItem(
                  'Maintenance',
                  '$maintenance',
                  const Color(0xFFEF4444),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── RENTABLE CARD ──────────────────────────────────────────────────────────
  Widget _buildRentableCard(
    String title,
    String sku,
    int total,
    int tersedia,
    int disewa,
    int maintenance,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StockDetailScreen(
              title: title,
              sku: sku,
              total: total,
              tersedia: tersedia,
              kosong: 0,
              disewa: disewa,
              vendor: 0,
              maintenance: maintenance,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEFF5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sku,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Stok',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total',
                      style: AppTextStyles.h2.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(color: Color(0xFFECEFF5), height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGridStatusItem(
                  'Tersedia',
                  '$tersedia',
                  const Color(0xFF00A67E),
                ),
                _buildGridStatusItem(
                  'Disewa',
                  '$disewa',
                  const Color(0xFF0055FF),
                ),
                _buildGridStatusItem(
                  'Maintenance',
                  '$maintenance',
                  const Color(0xFFEF4444),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── SELLABLE CARD ──────────────────────────────────────────────────────────
  Widget _buildSellableCard(String title, String sku, int tersedia) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StockDetailScreen(
              title: title,
              sku: sku,
              total: tersedia,
              tersedia: tersedia,
              kosong: 0,
              disewa: 0,
              vendor: 0,
              maintenance: 0,
              isProduct: true,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEFF5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sku,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Stok Tersedia',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$tersedia',
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridStatusItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Form Stok Masuk Bottom Sheet ───────────────────────────────────────────
  void _showAddStockBottomSheet(
    BuildContext context,
    WarehouseProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _AddStockBottomSheet(provider: provider);
      },
    );
  }
}

class _AddStockBottomSheet extends StatefulWidget {
  final WarehouseProvider provider;
  const _AddStockBottomSheet({required this.provider});

  @override
  State<_AddStockBottomSheet> createState() => _AddStockBottomSheetState();
}

class _AddStockBottomSheetState extends State<_AddStockBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedVendorId;
  String? _selectedProductId;

  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _unitCostController = TextEditingController(
    text: '0',
  );
  final TextEditingController _amountPaidController = TextEditingController(
    text: '0',
  );

  bool _isAutoAmountPaid = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitCostController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  int get _quantity {
    return int.tryParse(_quantityController.text) ?? 0;
  }

  double get _unitCost {
    final clean = _unitCostController.text.replaceAll('.', '');
    return double.tryParse(clean) ?? 0.0;
  }

  double get _amountPaid {
    final clean = _amountPaidController.text.replaceAll('.', '');
    return double.tryParse(clean) ?? 0.0;
  }

  double get _totalCost {
    return _quantity * _unitCost;
  }

  void _onCalculationsChanged() {
    if (_isAutoAmountPaid) {
      final total = _totalCost.toInt();
      _amountPaidController.text = _formatCurrency(total);
    }
    setState(() {});
  }

  void _onAmountPaidManualChanged() {
    final double currentAmt = _amountPaid;
    if (currentAmt != _totalCost) {
      _isAutoAmountPaid = false;
    }
    setState(() {});
  }

  void _onProductSelected(String? productId) {
    setState(() {
      _selectedProductId = productId;
      if (productId != null) {
        final product = widget.provider.products.firstWhere(
          (p) => p['id'] == productId,
          orElse: () => null,
        );
        if (product != null) {
          final rawCost = product['cost'];
          double cost = 0.0;
          if (rawCost is num) {
            cost = rawCost.toDouble();
          } else if (rawCost is String) {
            cost = double.tryParse(rawCost) ?? 0.0;
          }
          _unitCostController.text = _formatCurrency(cost.toInt());
          if (_isAutoAmountPaid) {
            _amountPaidController.text = _formatCurrency(
              (_quantity * cost).toInt(),
            );
          }
        }
      }
    });
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'vendorId': _selectedVendorId,
        'amountPaid': _amountPaid,
        'items': [
          {
            'productId': _selectedProductId,
            'quantity': _quantity,
            'unitCost': _unitCost,
          },
        ],
      };

      await widget.provider.addStock(type: 'purchases', data: payload);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stok baru (pembelian) berhasil disimpan ✓'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan stok: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double total = _totalCost;
    final formattedTotal = _formatCurrency(total.toInt());

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Form Stok Masuk (Pembelian)',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFECEFF5)),
              const SizedBox(height: 16),

              // ── SUPPLIER / VENDOR DROPDOWN ─────────────────────────────────
              Text(
                'Supplier / Vendor',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedVendorId,
                      decoration: InputDecoration(
                        hintText: 'Pilih Supplier',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                      items: widget.provider.vendors
                          .map<DropdownMenuItem<String>>((vendor) {
                            return DropdownMenuItem<String>(
                              value: vendor['id']?.toString(),
                              child: Text(
                                vendor['name']?.toString() ?? 'Supplier',
                              ),
                            );
                          })
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedVendorId = val);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Pilih supplier terlebih dahulu';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    onPressed: _showAddVendorDialog,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── PRODUCT DROPDOWN ───────────────────────────────────────────
              Text(
                'Pilih Barang / Tabung',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedProductId,
                      decoration: InputDecoration(
                        hintText: 'Pilih Produk',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                      items: widget.provider.products
                          .map<DropdownMenuItem<String>>((product) {
                            return DropdownMenuItem<String>(
                              value: product['id']?.toString(),
                              child: Text(
                                product['name']?.toString() ?? 'Produk',
                              ),
                            );
                          })
                          .toList(),
                      onChanged: _onProductSelected,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Pilih produk terlebih dahulu';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    onPressed: _showAddProductDialog,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── QUANTITY AND UNIT COST SIDE-BY-SIDE ────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jumlah (Unit)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText: '0',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (val) {
                            _onCalculationsChanged();
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Wajib';
                            }
                            final val = int.tryParse(value);
                            if (val == null || val <= 0) {
                              return 'Min 1';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Harga Beli Satuan',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _unitCostController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyInputFormatter()],
                          decoration: InputDecoration(
                            prefixText: 'Rp ',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (val) {
                            _onCalculationsChanged();
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Wajib';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── AMOUNT PAID ────────────────────────────────────────────────
              Text(
                'Jumlah Dibayar ke Supplier',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountPaidController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: _isAutoAmountPaid
                      ? IconButton(
                          icon: const Icon(
                            Icons.edit_note,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            setState(() => _isAutoAmountPaid = false);
                          },
                          tooltip: 'Ubah manual',
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.autorenew,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _isAutoAmountPaid = true;
                              _amountPaidController.text = _formatCurrency(
                                _totalCost.toInt(),
                              );
                            });
                          },
                          tooltip: 'Bayar Lunas (Otomatis)',
                        ),
                ),
                onChanged: (val) {
                  _onAmountPaidManualChanged();
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Wajib';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── TOTAL SUMMARY BOX ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Tagihan Beli',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Rp $formattedTotal',
                      style: AppTextStyles.priceText.copyWith(
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── ACTION BUTTONS ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Simpan Stok Masuk',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddVendorDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tambah Supplier Baru',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: Color(0xFFECEFF5), height: 1),
                      const SizedBox(height: 16),
                      Text(
                        'Nama Supplier',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'PT Samator Gas',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Nama wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nomor Telepon',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '08123456789',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Alamat',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Alamat lengkap supplier',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() => isSaving = true);
                          try {
                            final api = ApiService();
                            final res = await api.dio.post(
                              '/inventory/vendors',
                              data: {
                                'name': nameController.text.trim(),
                                'phone': phoneController.text.trim().isEmpty
                                    ? null
                                    : phoneController.text.trim(),
                                'address': addressController.text.trim().isEmpty
                                    ? null
                                    : addressController.text.trim(),
                              },
                            );

                            final created = api.handleResponse(res);
                            final String? createdId = created?['id']
                                ?.toString();

                            if (context.mounted) {
                              Navigator.pop(context); // Close dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Berhasil menambah supplier baru ✓',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );

                              // Refresh warehouse lists
                              await widget.provider.fetchInventory(
                                silent: true,
                              );

                              if (context.mounted && createdId != null) {
                                setState(() {
                                  _selectedVendorId = createdId;
                                });
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal menambah supplier: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            setModalState(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(100, 40),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Simpan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddProductDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final skuController = TextEditingController(
      text:
          'PRD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final priceController = TextEditingController(text: '0');
    final costController = TextEditingController(text: '0');
    final minStockController = TextEditingController(text: '5');

    String? selectedCategoryId;
    List<dynamic> categories = [];
    bool isLoadingCats = true;
    bool isSaving = false;

    // Open dialog first
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Fetch categories if not yet fetched
            if (categories.isEmpty && isLoadingCats) {
              _fetchCategories().then((list) {
                setModalState(() {
                  categories = list;
                  isLoadingCats = false;
                  if (categories.isNotEmpty) {
                    selectedCategoryId = categories.first['id']?.toString();
                  }
                });
              });
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tambah Barang Baru',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: Color(0xFFECEFF5), height: 1),
                      const SizedBox(height: 16),
                      Text(
                        'Nama Barang / Tabung',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'Regulator Nesco',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Nama wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'SKU / Kode',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: skuController,
                        decoration: InputDecoration(
                          hintText: 'REG-NES-001',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'SKU wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Kategori',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      isLoadingCats
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: selectedCategoryId,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                              items: categories.map<DropdownMenuItem<String>>((
                                cat,
                              ) {
                                final rawName =
                                    cat['name']?.toString() ?? 'Kategori';
                                String displayName = rawName;
                                final lower = rawName.toLowerCase();
                                if (lower == 'cylinder') {
                                  displayName = 'Tabung';
                                } else if (lower == 'accessory' ||
                                    lower == 'accessories') {
                                  displayName = 'Aksesoris';
                                } else if (lower == 'regulators' ||
                                    lower == 'regulator') {
                                  displayName = 'Regulator';
                                } else if (lower == 'gas') {
                                  displayName = 'Gas';
                                } else if (lower == 'consumables' ||
                                    lower == 'consumable') {
                                  displayName = 'Habis Pakai';
                                }
                                return DropdownMenuItem<String>(
                                  value: cat['id']?.toString(),
                                  child: Text(displayName),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setModalState(() => selectedCategoryId = val);
                              },
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Kategori wajib dipilih'
                                  : null,
                            ),
                      const SizedBox(height: 16),
                      Text(
                        'Harga Jual',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Harga jual wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Harga Beli',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: costController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Harga beli wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Stok Minimum',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: minStockController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '5',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        validator: (v) => v == null || int.tryParse(v) == null
                            ? 'Stok minimum tidak valid'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() => isSaving = true);
                          try {
                            final cleanPrice = priceController.text.replaceAll(
                              '.',
                              '',
                            );
                            final cleanCost = costController.text.replaceAll(
                              '.',
                              '',
                            );

                            final api = ApiService();
                            final res = await api.dio.post(
                              '/inventory/products',
                              data: {
                                'name': nameController.text.trim(),
                                'sku': skuController.text.trim(),
                                'categoryId': selectedCategoryId,
                                'price': double.parse(cleanPrice),
                                'cost': double.parse(cleanCost),
                                'minStock': int.parse(minStockController.text),
                                'currentStock': 0,
                              },
                            );

                            final created = api.handleResponse(res);
                            final String? createdId = created?['id']
                                ?.toString();

                            if (context.mounted) {
                              Navigator.pop(context); // Close dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Berhasil menambah barang baru ✓',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );

                              // Refresh warehouse lists
                              await widget.provider.fetchInventory(
                                silent: true,
                              );

                              if (context.mounted && createdId != null) {
                                setState(() {
                                  _selectedProductId = createdId;

                                  // Update unit cost controller
                                  final double costVal = double.parse(
                                    cleanCost,
                                  );
                                  _unitCostController.text = _formatCurrency(
                                    costVal.toInt(),
                                  );
                                  if (_isAutoAmountPaid) {
                                    _amountPaidController.text =
                                        _formatCurrency(
                                          (_quantity * costVal).toInt(),
                                        );
                                  }
                                });
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal menambah barang: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            setModalState(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(100, 40),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Simpan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<dynamic>> _fetchCategories() async {
    try {
      final api = ApiService();
      final res = await api.dio.get(
        '/inventory/categories',
        queryParameters: {'limit': 100},
      );
      final handled = api.handleResponse(res);
      if (handled is List) return handled;
      if (handled is Map && handled['items'] is List)
        return List<dynamic>.from(handled['items']);
      if (handled is Map && handled['data'] is List)
        return List<dynamic>.from(handled['data']);
      return [];
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return [];
    }
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    final String cleanText = newValue.text.replaceAll('.', '');
    final int? value = int.tryParse(cleanText);

    if (value == null) {
      return newValue;
    }

    final String formatted = _formatNumber(value);

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatNumber(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
