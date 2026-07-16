import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
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

  // Helper to group actual cylinders by oxygenType & size
  List<Map<String, dynamic>> _getGroupedCylinders(List<dynamic> list) {
    final Map<String, List<dynamic>> grouped = {};
    for (var cyl in list) {
      final String otName = cyl['oxygenType']?['name'] ?? 'Medical Oxygen';
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
      final maintenance = items.where((i) => i['status'] == 'MAINTENANCE').length;

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
      final maintenance = items.where((i) => i['status'] == 'MAINTENANCE').length;

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
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ScannerScreen(),
                ),
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                                  style: TextStyle(color: AppColors.textSecondary),
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
      return _buildSellableCard(
        item['title'],
        item['sku'],
        item['tersedia'],
      );
    }
  }

  // ── TOP SUMMARY CARDS ──────────────────────────────────────────────────────
  Widget _buildSummarySection(WarehouseProvider provider) {
    final tabungCount = provider.actualCylinders.length;
    final tersediaCount = provider.getCountByStatus('AVAILABLE');
    final kosongCount = provider.getCountByStatus('EMPTY');
    final rusakCount = provider.getCountByStatus('MAINTENANCE') + provider.getCountByStatus('AT_VENDOR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
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
              _buildSummaryCard('Tabung', '$tabungCount', 'Aset Terdaftar', const Color(0xFF0055FF)),
              const SizedBox(width: 12),
              _buildSummaryCard('Tersedia', '$tersediaCount', 'Siap disewakan', const Color(0xFF00A67E)),
              const SizedBox(width: 12),
              _buildSummaryCard('Kosong', '$kosongCount', 'Perlu isi ulang', const Color(0xFFF59E0B)),
              const SizedBox(width: 12),
              _buildSummaryCard('Rusak / Maint', '$rusakCount', 'Dalam perbaikan', const Color(0xFFEF4444)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String count, String subtitle, Color color) {
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
          Text(title, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
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
    final chips = ['Semua', 'Tabung Oksigen', 'Aksesoris Sewa', 'Alat Medis Jual'];
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
                  color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
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
                _buildGridStatusItem('Tersedia', '$tersedia', const Color(0xFF00A67E)),
                _buildGridStatusItem('Kosong', '$kosong', const Color(0xFFF59E0B)),
                _buildGridStatusItem('Disewa', '$disewa', const Color(0xFF0055FF)),
                _buildGridStatusItem('Di Vendor', '$vendor', const Color(0xFF8B5CF6)),
                _buildGridStatusItem('Maintenance', '$maintenance', const Color(0xFFEF4444)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
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
                _buildGridStatusItem('Tersedia', '$tersedia', const Color(0xFF00A67E)),
                _buildGridStatusItem('Disewa', '$disewa', const Color(0xFF0055FF)),
                _buildGridStatusItem('Maintenance', '$maintenance', const Color(0xFFEF4444)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── SELLABLE CARD ──────────────────────────────────────────────────────────
  Widget _buildSellableCard(
    String title,
    String sku,
    int tersedia,
  ) {
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  style: AppTextStyles.caption.copyWith(color: AppColors.success),
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
  void _showAddStockBottomSheet(BuildContext context, WarehouseProvider provider) {
    // Populate items dynamically from API response (products)
    final dropdownItems = provider.products.map((p) => p['name']?.toString() ?? 'Produk').toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Form Stok Masuk',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // Dropdown using dynamic product names
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Pilih Tabung / Barang',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: dropdownItems.map((name) {
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (val) {},
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Jumlah (Unit)',
                          hintText: '0',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Status Tujuan',
                          hintText: 'Tersedia',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Keterangan / Nama Supplier',
                    hintText: 'Opsional',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0055FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Stok baru berhasil disimpan'),
                          backgroundColor: Color(0xFF00A67E),
                        ),
                      );
                    },
                    child: const Text(
                      'Simpan Stok',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
