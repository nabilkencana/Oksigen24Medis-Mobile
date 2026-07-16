import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/core/state/transaction_provider.dart';
import 'package:oksigen24medis_mobile2/features/transaction/transaction_detail_screen.dart';
import 'package:provider/provider.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(context, listen: false).fetchTransactions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Format currency manually
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

  // Get dynamic heading for dates
  String _getDateHeader(String createdAtStr) {
    try {
      final date = DateTime.parse(createdAtStr).toLocal();
      final now = DateTime.now();
      final months = [
        'JANUARI', 'FEBRUARI', 'MARET', 'APRIL', 'MEI', 'JUNI',
        'JULI', 'AGUSTUS', 'SEPTEMBER', 'OKTOBER', 'NOVEMBER', 'DESEMBER'
      ];
      final monthStr = months[date.month - 1];

      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return 'HARI INI - ${date.day} $monthStr ${date.year}';
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
        return 'KEMARIN - ${date.day} $monthStr ${date.year}';
      }
      return '${date.day} $monthStr ${date.year}';
    } catch (_) {
      return 'LAINNYA';
    }
  }

  // Combine and map backend list elements
  List<Map<String, dynamic>> _buildMappedTxs(TransactionProvider provider) {
    final List<Map<String, dynamic>> list = [];

    // Map rentals
    for (var r in provider.rentals) {
      list.add({
        'id': r['id'],
        'invoiceNo': r['invoiceNo'] ?? 'INV-RENTAL',
        'customerName': r['customer']?['name'] ?? 'Jual Putus',
        'createdAt': r['createdAt'] ?? r['startDate'] ?? DateTime.now().toIso8601String(),
        'type': 'Sewa Tabung',
        'status': r['status'] ?? 'RENTING',
        'totalAmount': double.tryParse(r['totalAmount']?.toString() ?? '0') ?? 0.0,
        'original': r,
      });
    }

    // Map sales
    for (var s in provider.sales) {
      list.add({
        'id': s['id'],
        'invoiceNo': s['invoiceNo'] ?? 'INV-SALES',
        'customerName': s['customer']?['name'] ?? 'Jual Putus',
        'createdAt': s['createdAt'] ?? DateTime.now().toIso8601String(),
        'type': 'Penjualan',
        'status': 'SELESAI', // immediate sale is complete
        'totalAmount': double.tryParse(s['totalAmount']?.toString() ?? '0') ?? 0.0,
        'original': s,
      });
    }

    // Sort descending by date
    list.sort((a, b) => b['createdAt'].toString().compareTo(a['createdAt'].toString()));

    return list;
  }

  // Filter list by tab status
  List<Map<String, dynamic>> _filterList(List<Map<String, dynamic>> rawList, String tab) {
    var filtered = rawList;

    // Search query filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((tx) {
        final invoice = tx['invoiceNo'].toString().toLowerCase();
        final name = tx['customerName'].toString().toLowerCase();
        return invoice.contains(_searchQuery) || name.contains(_searchQuery);
      }).toList();
    }

    // Tab filter
    if (tab == 'BERJALAN') {
      filtered = filtered.where((tx) => tx['status'] == 'RENTING' || tx['status'] == 'OVERDUE').toList();
    } else if (tab == 'SELESAI') {
      filtered = filtered.where((tx) => tx['status'] == 'RETURNED' || tx['status'] == 'SELESAI').toList();
    }

    // Date range filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((tx) {
        try {
          final txDate = DateTime.parse(tx['createdAt']).toLocal();
          final dateOnly = DateTime(txDate.year, txDate.month, txDate.day);
          final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
          final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);

          return (dateOnly.isAtSameMomentAs(start) || dateOnly.isAfter(start)) &&
                 (dateOnly.isAtSameMomentAs(end) || dateOnly.isBefore(end));
        } catch (_) {
          return false;
        }
      }).toList();
    }

    return filtered;
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);
    final mappedTxs = _buildMappedTxs(provider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Riwayat Transaksi',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.calendar_today_outlined,
                color: _selectedDateRange != null
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
              onPressed: _selectDateRange,
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle: AppTextStyles.bodyMedium,
            tabs: const [
              Tab(text: 'Semua'),
              Tab(text: 'Berjalan'),
              Tab(text: 'Selesai'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Search Input
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextFormField(
                controller: _searchController,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari invoice atau pelanggan...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_selectedDateRange != null)
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withAlpha(40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.date_range_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${_selectedDateRange!.start.toString().substring(0, 10)} s/d ${_selectedDateRange!.end.toString().substring(0, 10)}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDateRange = null;
                              });
                            },
                            child: const Icon(Icons.close, size: 14, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // TabBarView for list contents
            Expanded(
              child: provider.isLoading && provider.rentals.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : TabBarView(
                      children: [
                        _buildTransactionList(mappedTxs, 'SEMUA'),
                        _buildTransactionList(mappedTxs, 'BERJALAN'),
                        _buildTransactionList(mappedTxs, 'SELESAI'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> rawList, String tab) {
    final filteredList = _filterList(rawList, tab);

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary, size: 64),
            const SizedBox(height: 12),
            Text(
              'Tidak ada transaksi ditemukan',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final tx = filteredList[index];
        final String currentHeader = _getDateHeader(tx['createdAt']);
        final showDateHeader = index == 0 || _getDateHeader(filteredList[index - 1]['createdAt']) != currentHeader;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDateHeader) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 12.0, left: 4.0),
                child: Text(
                  currentHeader,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
            _buildTransactionCard(tx),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  // ── Reusable Transaction Card ──────────────────────────────────────────────
  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final String status = tx['status'];
    final String type = tx['type'];

    // Badges details based on status
    final String statusText;
    final Color badgeBg;
    final Color badgeText;

    if (status == 'RETURNED' || status == 'SELESAI') {
      statusText = 'SELESAI';
      badgeBg = const Color(0xFFE6F4EA); // Light success green
      badgeText = AppColors.success;
    } else if (status == 'RENTING') {
      statusText = 'BERJALAN';
      badgeBg = const Color(0xFFFEF3D6); // Light warning orange
      badgeText = AppColors.warning;
    } else {
      statusText = 'TERLAMBAT';
      badgeBg = const Color(0xFFFCE8E6); // Light error red
      badgeText = AppColors.error;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Map items dynamically from backend object
            final List<DetailItem> detailItems = [];
            final original = tx['original'];

            if (type == 'Sewa Tabung') {
              final List<dynamic> items = original['items'] ?? [];
              for (var it in items) {
                final cyl = it['cylinder'] ?? {};
                final size = cyl['size'] ?? '6m3';
                final otName = cyl['oxygenType']?['name'] ?? 'Tabung Oksigen';
                detailItems.add(DetailItem(
                  name: '$otName ($size)',
                  qty: 1,
                  unitPrice: double.tryParse(it['price']?.toString() ?? '75000')?.round() ?? 75000,
                ));
              }
            } else {
              // Penjualan
              final List<dynamic> items = original['items'] ?? [];
              for (var it in items) {
                final prodName = it['product']?['name'] ?? 'Alat Medis';
                detailItems.add(DetailItem(
                  name: prodName,
                  qty: it['quantity'] ?? 1,
                  unitPrice: double.tryParse(it['unitPrice']?.toString() ?? '0')?.round() ?? 0,
                ));
              }
            }

            final dateStr = tx['createdAt'].toString().substring(0, 16).replaceAll('T', ', ');

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TransactionDetailScreen(
                  invoiceNo: tx['invoiceNo'],
                  customerName: tx['customerName'],
                  dateStr: dateStr,
                  status: status,
                  totalTagihan: tx['totalAmount'].round(),
                  deposit: type == 'Sewa Tabung' ? 200000 : 0,
                  sewaDays: type == 'Sewa Tabung' ? 7 : 0,
                  returnDeadline: type == 'Sewa Tabung' ? original['dueDate']?.toString().substring(0, 10) ?? '-' : '-',
                  items: detailItems,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tx['invoiceNo'],
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: AppTextStyles.caption.copyWith(
                          color: badgeText,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  tx['customerName'],
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tx['type'],
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    Text(
                      _formatCurrency(tx['totalAmount']),
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
