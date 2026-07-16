import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/core/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:oksigen24medis_mobile2/core/state/warehouse_provider.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';

class StockDetailScreen extends StatefulWidget {
  final String title;
  final String sku;
  final int total;
  final int tersedia;
  final int kosong;
  final int disewa;
  final int vendor;
  final int maintenance;
  final bool isProduct;

  const StockDetailScreen({
    super.key,
    this.title = 'Tabung Oksigen 6m3',
    this.sku = 'SKU: TO-6000',
    this.total = 150,
    this.tersedia = 100,
    this.kosong = 28,
    this.disewa = 12,
    this.vendor = 8,
    this.maintenance = 2,
    this.isProduct = false,
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  List<dynamic> _movements = [];
  bool _isLoadingMovements = false;
  int _currentPage = 1;
  static const int _pageSize = 10;
  String _selectedSerialFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _fetchMovements();
  }

  Future<void> _fetchMovements() async {
    if (mounted) {
      setState(() => _isLoadingMovements = true);
    }
    try {
      final api = ApiService();
      final response = await api.dio.get('/transactions/stock-movements', queryParameters: {'limit': 100});
      final data = api.handleResponse(response);
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map) {
        if (data['data'] is List) {
          list = data['data'];
        } else if (data['items'] is List) {
          list = data['items'];
        }
      }

      if (!mounted) return;

      // Filter movements related to this cylinder/product
      final provider = Provider.of<WarehouseProvider>(context, listen: false);
      setState(() {
        _movements = list.where((m) {
          if (widget.isProduct) {
            if (m['product'] == null) return false;
            final pName = m['product']?['name']?.toString().toLowerCase() ?? '';
            return pName == widget.title.toLowerCase();
          } else {
            if (m['cylinderId'] == null) return false;

            // Find matching cylinder in provider list to get relation fields
            final c = provider.cylinders.firstWhere(
              (cyl) => cyl['id'] == m['cylinderId'],
              orElse: () => null,
            );

            if (c == null) {
              // Fallback based on size if not found in provider
              final size = m['cylinder']?['size']?.toString().toLowerCase() ?? '';
              if (widget.sku.contains('RNT-ACC') || widget.sku.contains('ACC')) {
                return size == 'pcs';
              } else {
                final searchTitle = widget.title.toLowerCase();
                return size.isNotEmpty && searchTitle.contains('($size)');
              }
            }

            if (widget.sku.contains('RNT-ACC') || widget.sku.contains('ACC')) {
              // Accessory match
              final otName = c['oxygenType']?['name']?.toString() ?? 'Aksesoris Sewa';
              return otName.toLowerCase() == widget.title.toLowerCase();
            } else {
              // Cylinder match
              final otName = c['oxygenType']?['name']?.toString() ?? 'Oksigen Medis';
              final size = c['size']?.toString() ?? '1m3';
              return '$otName ($size)'.toLowerCase() == widget.title.toLowerCase();
            }
          }
        }).toList();
      });
    } catch (e) {
      debugPrint('Error fetching movements: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMovements = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> serialNumbers = [];
    if (!widget.isProduct) {
      try {
        final provider = Provider.of<WarehouseProvider>(context);
        final allCylinders = widget.sku.contains('RNT-ACC') || widget.sku.contains('ACC')
            ? provider.rentableAccessories
            : provider.actualCylinders;

        final matchingCylinders = allCylinders.where((c) {
          if (widget.sku.contains('RNT-ACC') || widget.sku.contains('ACC')) {
            final otName = c['oxygenType']?['name'] ?? 'Aksesoris Sewa';
            return otName == widget.title;
          } else {
            final otName = c['oxygenType']?['name'] ?? 'Oksigen Medis';
            final size = c['size'] ?? '1m3';
            return '$otName $size' == widget.title;
          }
        }).toList();

        serialNumbers = matchingCylinders
            .map((c) => c['serialNumber']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      } catch (e) {
        debugPrint('Error getting serial numbers: $e');
      }
    }

    final dropdownValue = (serialNumbers.contains(_selectedSerialFilter) || _selectedSerialFilter == 'Semua')
        ? _selectedSerialFilter
        : 'Semua';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // Light off-white
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Detail Stok',
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.textSecondary),
            onPressed: () {},
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
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── COMPONENT 1: HEADER & ITEM INFO ──────────────────────────────
            _buildHeaderInfoCard(),

            if (!widget.isProduct) ...[
              const SizedBox(height: 24),

              // Section Title: Distribusi Status
              Text(
                'Distribusi Status',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              // ── COMPONENT 2: STATUS BREAKDOWN (5 STATES) ─────────────────────
              _buildStatusBreakdownCard(),

              const SizedBox(height: 24),

              // ── COMPONENT 3: QUICK ACTIONS ───────────────────────────────────
              _buildQuickActions(),

              if (serialNumbers.isNotEmpty) ...[
                const SizedBox(height: 28),
                // Section Title: Daftar Unit Aset
                Text(
                  'Daftar Unit Aset',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                // ── COMPONENT 3.5: LIST OF ASSET UNITS ───────────────────────────
                _buildAssetUnitsCard(serialNumbers),
              ],
            ],

            const SizedBox(height: 28),

            // Section Title: Riwayat Pergerakan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Riwayat Pergerakan',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (!widget.isProduct && serialNumbers.isNotEmpty)
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC3C5D9).withAlpha(128)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: dropdownValue,
                        isDense: true,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: 'Semua',
                            child: Text('Semua Unit'),
                          ),
                          ...serialNumbers.map((s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text('S/N: $s'),
                              )),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedSerialFilter = val;
                              _currentPage = 1; // Reset to page 1
                            });
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // ── COMPONENT 4: HISTORY LOG (RIWAYAT PERGERAKAN) ────────────────
            _buildHistoryLogCard(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Header Info Card ───────────────────────────────────────────────────────
  Widget _buildHeaderInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEFF5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.sku,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showQRDialog(widget.sku, 'SKU Barang: ${widget.sku}'),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(color: Color(0xFFECEFF5), height: 1),
          ),
          Row(
            children: [
              Text(
                'Total Stok Keseluruhan',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${widget.total} Unit',
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Status Breakdown Card ──────────────────────────────────────────────────
  Widget _buildStatusBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 2.5,
        children: [
          _buildGridStatusItem('Tersedia', '${widget.tersedia}', const Color(0xFF00A67E)),
          _buildGridStatusItem('Kosong', '${widget.kosong}', const Color(0xFFF59E0B)),
          _buildGridStatusItem('Disewa', '${widget.disewa}', const Color(0xFF0055FF)),
          _buildGridStatusItem('Di Vendor', '${widget.vendor}', const Color(0xFF8B5CF6)),
          _buildGridStatusItem('Maintenance', '${widget.maintenance}', const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _buildGridStatusItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ── Quick Actions ──────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    final isAccessory = widget.sku.contains('RNT-ACC') || widget.sku.contains('ACC');
    final secondButtonLabel = isAccessory ? 'Sewa Baru' : 'Isi Ulang';
    final secondButtonIcon = isAccessory ? Icons.assignment_turned_in_rounded : Icons.local_gas_station_rounded;
    final secondButtonSnackbar = isAccessory ? 'Membuka form sewa...' : 'Membuka form isi ulang...';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Membuka form ubah status...'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            icon: const Icon(Icons.sync_alt, size: 20),
            label: const Text(
              'Ubah Status',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0055FF),
              side: const BorderSide(color: Color(0xFF0055FF), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(secondButtonSnackbar),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            icon: Icon(secondButtonIcon, size: 20),
            label: Text(
              secondButtonLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0055FF),
              foregroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }

  List<dynamic> get _filteredMovements {
    if (_selectedSerialFilter == 'Semua') {
      return _movements;
    }
    return _movements.where((m) {
      final cSerial = m['cylinder']?['serialNumber']?.toString() ?? '';
      return cSerial == _selectedSerialFilter;
    }).toList();
  }

  int get _totalPages {
    final list = _filteredMovements;
    if (list.isEmpty) return 1;
    return (list.length / _pageSize).ceil();
  }

  List<dynamic> get _paginatedMovements {
    final list = _filteredMovements;
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize;
    if (startIndex >= list.length) return [];
    return list.sublist(
      startIndex,
      endIndex > list.length ? list.length : endIndex,
    );
  }

  // ── History Log Card ───────────────────────────────────────────────────────
  Widget _buildHistoryLogCard() {
    if (_isLoadingMovements) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_movements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: const Center(
          child: Text(
            'Belum ada riwayat pergerakan stok untuk barang ini',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final total = _totalPages;
    final paginated = _paginatedMovements;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginated.length,
            separatorBuilder: (context, index) => const Divider(color: Color(0xFFECEFF5), height: 1),
            itemBuilder: (context, index) {
              final m = paginated[index];
              final refType = m['referenceType']?.toString().toUpperCase() ?? '';
              final isOut = m['type'] == 'OUT';
              final String date = m['createdAt'] != null
                  ? DateTime.parse(m['createdAt']).toLocal().toString().substring(0, 16)
                  : '';

              String actionTitle = 'Mutasi Stok';
              IconData actionIcon = Icons.swap_horiz_rounded;
              Color actionColor = const Color(0xFF6B7280);
              Color actionBg = const Color(0xFFF3F4F6);

              if (refType == 'RENTAL') {
                actionTitle = 'Sewa Kontrak';
                actionIcon = Icons.assignment_turned_in_rounded;
                actionColor = const Color(0xFF0055FF);
                actionBg = const Color(0xFFE6F0FF);
              } else if (refType == 'RETURN') {
                actionTitle = 'Pengembalian';
                actionIcon = Icons.assignment_return_rounded;
                actionColor = const Color(0xFF00A67E);
                actionBg = const Color(0xFFE6F7F0);
              } else if (refType == 'REFILL') {
                actionTitle = 'Isi Ulang';
                actionIcon = Icons.local_gas_station_rounded;
                actionColor = const Color(0xFFF59E0B);
                actionBg = const Color(0xFFFEF3C7);
              } else if (refType == 'SALE') {
                actionTitle = 'Penjualan';
                actionIcon = Icons.shopping_bag_rounded;
                actionColor = const Color(0xFF8B5CF6);
                actionBg = const Color(0xFFF5F3FF);
              } else if (refType == 'PURCHASE') {
                actionTitle = 'Pembelian';
                actionIcon = Icons.add_shopping_cart_rounded;
                actionColor = const Color(0xFFEC4899);
                actionBg = const Color(0xFFFDF2F8);
              } else if (refType == 'ADJUSTMENT') {
                actionTitle = 'Penyesuaian';
                actionIcon = Icons.tune_rounded;
                actionColor = const Color(0xFF6B7280);
                actionBg = const Color(0xFFF3F4F6);
              } else {
                if (isOut) {
                  actionTitle = 'Stok Keluar';
                  actionIcon = Icons.arrow_upward_rounded;
                  actionColor = const Color(0xFFEF4444);
                  actionBg = const Color(0xFFFCE8E6);
                } else {
                  actionTitle = 'Stok Masuk';
                  actionIcon = Icons.arrow_downward_rounded;
                  actionColor = const Color(0xFF00A67E);
                  actionBg = const Color(0xFFE6F4EA);
                }
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: actionBg,
                  child: Icon(
                    actionIcon,
                    color: actionColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  actionTitle,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Oleh: ${m['createdBy'] is Map ? (m['createdBy']['fullName'] ?? 'Staff') : (m['createdBy'] ?? 'Staff')}${m['cylinder'] != null && m['cylinder']['serialNumber'] != null ? ' (S/N: ${m['cylinder']['serialNumber']})' : ''}\n$date',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.3),
                  ),
                ),
                trailing: Text(
                  '${isOut ? "-" : "+"}${m['quantity']} Unit',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isOut ? const Color(0xFFEF4444) : const Color(0xFF00A67E),
                  ),
                ),
              );
            },
          ),
          if (total > 1) ...[
            const Divider(color: Color(0xFFECEFF5), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    color: _currentPage > 1 ? AppColors.primary : AppColors.textSecondary.withAlpha(100),
                    onPressed: _currentPage > 1
                        ? () {
                            setState(() {
                              _currentPage--;
                            });
                          }
                        : null,
                  ),
                  Text(
                    'Halaman $_currentPage dari $total',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    color: _currentPage < total ? AppColors.primary : AppColors.textSecondary.withAlpha(100),
                    onPressed: _currentPage < total
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Asset Units Card ───────────────────────────────────────────────────────
  Widget _buildAssetUnitsCard(List<String> serials) {
    if (serials.isEmpty) return const SizedBox.shrink();
    final provider = Provider.of<WarehouseProvider>(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: serials.length,
        separatorBuilder: (context, index) => const Divider(color: Color(0xFFECEFF5), height: 1),
        itemBuilder: (context, index) {
          final sNum = serials[index];
          final c = provider.cylinders.firstWhere((cyl) => cyl['serialNumber'] == sNum, orElse: () => null);
          final status = c != null ? c['status']?.toString() ?? 'AVAILABLE' : 'AVAILABLE';

          Color statusColor = const Color(0xFF00A67E);
          String statusText = 'Tersedia';

          if (status == 'RENTED') {
            statusColor = const Color(0xFF0055FF);
            statusText = 'Disewa';
          } else if (status == 'MAINTENANCE') {
            statusColor = const Color(0xFFEF4444);
            statusText = 'Maint';
          } else if (status == 'EMPTY') {
            statusColor = const Color(0xFFF59E0B);
            statusText = 'Kosong';
          } else if (status == 'AT_VENDOR') {
            statusColor = const Color(0xFF8B5CF6);
            statusText = 'Vendor';
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: statusColor.withAlpha(25),
              child: Icon(Icons.qr_code_2_rounded, color: statusColor, size: 16),
            ),
            title: Text(
              'S/N: $sNum',
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 20),
                  onPressed: () => _showQRDialog(sNum, 'Serial Number: $sNum'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── QR Code Dialog ─────────────────────────────────────────────────────────
  void _showQRDialog(String data, String subtitle) {
    final encodedData = Uri.encodeComponent(data);
    final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=$encodedData';
    final GlobalKey labelKey = GlobalKey();
    bool _isQrLoaded = false;
    bool _isExporting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E293B), // Slate dark theme
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.qr_code_2, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Label QR Code',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Printable white card preview (captured by RepaintBoundary)
                    RepaintBoundary(
                      key: labelKey,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'OKSIGEN MEDIS 24 JAM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[600],
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 140,
                              height: 1,
                              color: Colors.grey[200],
                            ),
                            const SizedBox(height: 16),
                            
                            // QR Image from network
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[200]!, width: 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  qrUrl,
                                  width: 160,
                                  height: 160,
                                  fit: BoxFit.contain,
                                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                    if (frame != null && !_isQrLoaded) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        setModalState(() {
                                          _isQrLoaded = true;
                                        });
                                      });
                                    }
                                    return child;
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 160,
                                      height: 160,
                                      color: Colors.grey[100],
                                      child: const Center(
                                        child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 160,
                                      height: 160,
                                      color: Colors.grey[100],
                                      child: const Center(
                                        child: CircularProgressIndicator(color: AppColors.primary),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Item name
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // Subtitle (Monospace SKU / SN)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Share / Save Image button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0055FF),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0xFF0055FF).withOpacity(0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          disabledBackgroundColor: const Color(0xFF0055FF).withOpacity(0.5),
                        ),
                        icon: _isExporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.share_rounded, size: 20),
                        label: Text(
                          _isExporting ? 'Memproses...' : 'Ekspor & Bagikan Gambar',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: !_isQrLoaded || _isExporting
                            ? null
                            : () async {
                                setModalState(() => _isExporting = true);
                                try {
                                  // Wait for rendering framework
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  
                                  final boundary = labelKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                                  final image = await boundary.toImage(pixelRatio: 3.0);
                                  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                                  final pngBytes = byteData!.buffer.asUint8List();

                                  await Printing.sharePdf(
                                    bytes: pngBytes,
                                    filename: 'label_${subtitle.replaceAll(" ", "_")}.png',
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal membuat gambar: $e'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                } finally {
                                  setModalState(() => _isExporting = false);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
