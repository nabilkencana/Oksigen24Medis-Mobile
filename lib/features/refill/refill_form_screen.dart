import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/core/state/transaction_provider.dart';
import 'package:oksigen24medis_mobile2/core/state/warehouse_provider.dart';
import 'package:oksigen24medis_mobile2/features/payment/payment_screen.dart';
import 'package:oksigen24medis_mobile2/features/payment/receipt_item.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:oksigen24medis_mobile2/features/warehouse/transaction_scanner_screen.dart';

class RefillFormScreen extends StatefulWidget {
  const RefillFormScreen({super.key});

  @override
  State<RefillFormScreen> createState() => _RefillFormScreenState();
}

class _RefillFormScreenState extends State<RefillFormScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCustomerId;

  // Dynamic qty map: size -> quantity (derived from real backend sizes)
  final Map<String, int> _cylinderQty = {};

  late TextEditingController _tarifController;

  @override
  void initState() {
    super.initState();
    _tarifController = TextEditingController(text: '80.000');
    _tarifController.addListener(_onAmountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(context, listen: false).fetchCustomers();
      Provider.of<WarehouseProvider>(context, listen: false).fetchInventory();
    });
  }

  @override
  void dispose() {
    _tarifController.removeListener(_onAmountChanged);
    _tarifController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    setState(() {});
  }

  // Recalculates suggested tariff based on cylinder quantities
  void _updateSuggestedPrices() {
    const Map<String, int> tarifPerUnit = {
      '0.3m3': 30000,
      '0.5m3': 40000,
      '1m3': 50000,
      '6m3': 150000,
    };
    int total = 0;
    _cylinderQty.forEach((size, qty) {
      total += (tarifPerUnit[size] ?? 50000) * qty;
    });
    _tarifController.text = _formatCurrency(total);
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final warehouseProvider = Provider.of<WarehouseProvider>(context);

    // ── Build dynamic stock map per cylinder size ──────────────────────────
    final Map<String, int> stockBySize = {};
    for (final cyl in warehouseProvider.actualCylinders) {
      if (cyl['status'] == 'AVAILABLE') {
        final size = cyl['size']?.toString() ?? 'Unknown';
        stockBySize[size] = (stockBySize[size] ?? 0) + 1;
      }
    }

    // Standard pre-defined sizes for refill
    final Set<String> allSizes = {'0.3m3', '0.5m3', '1m3', '6m3'};
    
    // Add any other sizes found dynamically in the database
    for (final cyl in warehouseProvider.actualCylinders) {
      final size = cyl['size']?.toString();
      if (size != null && size != 'Pcs' && size.toLowerCase() != 'unknown') {
        allSizes.add(size);
      }
    }

    final List<String> sizes = allSizes.toList()
      ..sort((a, b) {
        final numA = double.tryParse(a.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        final numB = double.tryParse(b.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        return numA.compareTo(numB);
      });

    for (final size in sizes) {
      _cylinderQty.putIfAbsent(size, () => 0);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Isi Ulang Oksigen',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
            onPressed: () => _openScanner(context, warehouseProvider),
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
            // Section Header: Pelanggan
            _buildSectionHeader('Pelanggan', Icons.person_outline),
            const SizedBox(height: 8),
            // ── COMPONENT 1: PELANGGAN ───────────────────────────────────────
            _buildCustomerCard(txProvider),

            const SizedBox(height: 24),

            // Section Header: Pilihan Item Isi Ulang
            _buildSectionHeader(
              'Pilihan Item Isi Ulang',
              Icons.assignment_outlined,
            ),
            const SizedBox(height: 8),
            // ── COMPONENT 2: PILIHAN ITEM ISI ULANG ──────────────────────────
            _buildItemsCard(sizes, stockBySize),

            const SizedBox(height: 24),

            // Section Header: Rincian Biaya
            _buildSectionHeader(
              'Rincian Biaya',
              Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 8),
            // ── COMPONENT 3: INPUT BIAYA MANUAL ──────────────────────────────
            _buildBillingDetailsCard(),

            const SizedBox(height: 100), // Scroll padding
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomCheckout(warehouseProvider),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  // ── Customer Card ──────────────────────────────────────────────────────────
  Widget _buildCustomerCard(TransactionProvider tx) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pilih Pelanggan (Wajib)',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () => _showAddCustomerSheet(context),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pelanggan Baru',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showCustomerPicker(context, tx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _searchController.text.isNotEmpty
                          ? _searchController.text
                          : 'Pilih Pelanggan...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _searchController.text.isNotEmpty
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (tx.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  else
                    const Icon(Icons.expand_more,
                        color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Items Card (DYNAMIC) ───────────────────────────────────────────────────
  Widget _buildItemsCard(List<String> sizes, Map<String, int> stockBySize) {
    if (sizes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                'Tidak ada stok tabung tersedia',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<Widget> rows = [];
    for (int i = 0; i < sizes.length; i++) {
      final size = sizes[i];
      final stock = stockBySize[size] ?? 0;
      final qty = _cylinderQty[size] ?? 0;
      if (i > 0) rows.add(const Divider(color: AppColors.border, height: 1));
      rows.add(
        _buildItemStepper('Tabung Oksigen $size', stock, qty, (v) {
          setState(() => _cylinderQty[size] = v);
          _updateSuggestedPrices();
        }),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: rows),
    );
  }

  // ── Item Stepper Generator ─────────────────────────────────────────────────
  Widget _buildItemStepper(
    String name,
    int stock,
    int qty,
    ValueChanged<int> onChanged,
  ) {
    final isSelected = qty > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stok Toko: $stock (Bisa Isi Langsung)',
                  style: AppTextStyles.caption.copyWith(
                    color: stock <= 3
                        ? AppColors.warning
                        : AppColors.textSecondary,
                    fontWeight: stock <= 3
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: qty > 0 ? () => onChanged(qty - 1) : null,
                icon: const Icon(Icons.remove_circle_outline, size: 24),
                color: AppColors.textSecondary,
              ),
              Text(
                '$qty',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => onChanged(qty + 1),
                icon: const Icon(Icons.add_circle_outline, size: 24),
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Billing Details Card ───────────────────────────────────────────────────
  Widget _buildBillingDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _tarifController,
            keyboardType: TextInputType.number,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
            inputFormatters: [CurrencyInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Tarif Refill Manual',
              prefixText: 'Rp ',
              labelStyle: AppTextStyles.bodyMedium,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Checkout ────────────────────────────────────────────────────────
  Widget _buildBottomCheckout(WarehouseProvider provider) {
    final int tarif =
        int.tryParse(_tarifController.text.replaceAll('.', '')) ?? 0;
    final formattedPrice = _formatCurrency(tarif);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFC3C5D9), width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Tagihan',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rp',
                        style: AppTextStyles.priceText.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedPrice,
                        style: AppTextStyles.priceText.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedCustomerId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pilih pelanggan terlebih dahulu'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    if (tarif <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Tarif refill wajib diisi untuk diproses',
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    // Map cylinder IDs dynamically per size
                    final totalQty = _cylinderQty.values.fold(
                      0,
                      (a, b) => a + b,
                    );

                    if (totalQty == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Pilih minimal 1 tabung untuk diisi ulang',
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    // Build per-size items list for the API
                    // Buat items per ukuran tabung
                    final List<Map<String, dynamic>> items = [];
                    final List<ReceiptItem> receiptItems = [];

                    _cylinderQty.forEach((size, qty) {
                      if (qty > 0) {
                        final pricePerUnit = tarif ~/ totalQty;
                        // Untuk API customer refill:
                        items.add({
                          'cylinderSize': size,
                          'quantity': qty,
                          'unitPrice': pricePerUnit,
                        });
                        // Untuk struk: tampilkan per ukuran
                        receiptItems.add(ReceiptItem(
                          name: 'Refill Tabung Oksigen $size',
                          price: pricePerUnit * qty,
                          quantity: qty,
                        ));
                      }
                    });

                    // Jika receiptItems kosong (edge case), tambahkan satu item total
                    if (receiptItems.isEmpty) {
                      receiptItems.add(ReceiptItem(
                        name: 'Refill Oksigen Medis',
                        price: tarif,
                        quantity: 1,
                      ));
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PaymentScreen(
                          quantity: totalQty,
                          selectedSize: 'Refill',
                          tarif: tarif,
                          deposit: 0,
                          customerName: _searchController.text,
                          invoiceNo: 'RFL-TEMP',
                          receiptItems: receiptItems,
                          type: 'REFILL',
                          customerId: _selectedCustomerId,
                          items: items,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Lanjut Pembayaran',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // ── Customer Picker Bottom Sheet ───────────────────────────────────────────
  Future<void> _showCustomerPicker(
      BuildContext context, TransactionProvider tx) async {
    if (tx.customers.isEmpty && !tx.isCustomerLoading) {
      tx.fetchCustomers();
    }
    if (!mounted) return;

    final searchCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AnimatedBuilder(
          animation: tx,
          builder: (ctx, _) {
            return StatefulBuilder(
              builder: (ctx, setSheet) {
                final query = searchCtrl.text.toLowerCase();
                final allCustomers = tx.customers;
                final isLoading = tx.isCustomerLoading;
                final filtered = allCustomers
                    .where((c) =>
                        (c['name'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(query) ||
                        (c['phone'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(query))
                    .toList();

                return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom),
                  child: Container(
                    height: MediaQuery.of(ctx).size.height * 0.78,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        // Handle bar
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              const Icon(Icons.people_outline,
                                  color: AppColors.primary, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Pilih Pelanggan',
                                style: AppTextStyles.h3
                                    .copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _showAddCustomerSheet(context);
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Baru'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Search bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: TextField(
                            controller: searchCtrl,
                            onChanged: (_) => setSheet(() {}),
                            decoration: InputDecoration(
                              hintText: 'Cari nama atau no. HP...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              filled: true,
                              fillColor: AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        searchCtrl.clear();
                                        setSheet(() {});
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        // List
                        Expanded(
                          child: isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary),
                                )
                              : filtered.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.person_search_outlined,
                                              size: 48,
                                              color: AppColors.textSecondary),
                                          const SizedBox(height: 8),
                                          Text(
                                            allCustomers.isEmpty
                                                ? (tx.error != null
                                                    ? 'Gagal memuat data:\n${tx.error}'
                                                    : 'Belum ada pelanggan')
                                                : 'Pelanggan tidak ditemukan',
                                            textAlign: TextAlign.center,
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                    color: tx.error != null
                                                        ? AppColors.error
                                                        : AppColors.textSecondary),
                                          ),
                                          if (allCustomers.isEmpty) ...[
                                            const SizedBox(height: 12),
                                            TextButton.icon(
                                              onPressed: () {
                                                tx.fetchCustomers();
                                              },
                                              icon: const Icon(Icons.refresh,
                                                  size: 16),
                                              label: const Text('Muat Ulang'),
                                            ),
                                          ],
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, _) =>
                                          const Divider(height: 1),
                                      itemBuilder: (_, i) {
                                        final c = filtered[i];
                                        final name =
                                            c['name']?.toString() ??
                                                'Pelanggan';
                                        final phone =
                                            c['phone']?.toString() ?? '';
                                        final isSelected =
                                            c['id']?.toString() ==
                                                _selectedCustomerId;
                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: isSelected
                                                ? AppColors.primary
                                                : AppColors.primary
                                                    .withAlpha(20),
                                            radius: 20,
                                            child: Text(
                                              name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            name,
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          subtitle: phone.isNotEmpty
                                              ? Text(phone,
                                                  style: AppTextStyles.caption)
                                              : null,
                                          trailing: isSelected
                                              ? const Icon(
                                                  Icons.check_circle_rounded,
                                                  color: AppColors.primary,
                                                  size: 20,
                                                )
                                              : null,
                                          onTap: () {
                                            setState(() {
                                              _selectedCustomerId =
                                                  c['id']?.toString();
                                              _searchController.text = name;
                                            });
                                            Navigator.of(ctx).pop();
                                          },
                                        );
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
      },
    );
  }

  // ── Add New Customer sheet ────────────────────────────────────────────────
  void _showAddCustomerSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Tambah Pelanggan Baru',
                            style: AppTextStyles.h3.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Nama
                      TextFormField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Nama Pelanggan *',
                          hintText: 'Contoh: Budi Santoso',
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // No HP
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'No. HP *',
                          hintText: '08xxxxxxxxxx',
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'No. HP wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Alamat
                      TextFormField(
                        controller: addressCtrl,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Alamat *',
                          hintText: 'Jl. Contoh No. 1, Kota...',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 20),
                            child: Icon(Icons.location_on_outlined, size: 20),
                          ),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Alamat wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setSheetState(() => isSubmitting = true);
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    final txProvider =
                                        Provider.of<TransactionProvider>(
                                      context,
                                      listen: false,
                                    );
                                    final newCustomer = await txProvider
                                        .createCustomer(
                                      name: nameCtrl.text.trim(),
                                      phone: phoneCtrl.text.trim(),
                                      address: addressCtrl.text.trim(),
                                    );
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                    if (mounted) {
                                      setState(() {
                                        _selectedCustomerId = newCustomer['id']
                                            ?.toString();
                                        _searchController.text =
                                            newCustomer['name'] ??
                                            nameCtrl.text.trim();
                                      });
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '✓ Pelanggan "${newCustomer['name']}" berhasil ditambahkan',
                                        ),
                                        backgroundColor: const Color(0xFF00A67E),
                                      ),
                                    );
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setSheetState(() => isSubmitting = false);
                                    }
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text('Gagal: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 20),
                          label: const Text(
                            'Simpan Pelanggan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isAccessoryAsset(String serial, String size) {
    final s = serial.toUpperCase();
    final sz = size.toUpperCase();
    return s.startsWith('REG-') || s.startsWith('TRL-') || s.startsWith('ACC-') || sz == 'PCS';
  }

  Future<void> _openScanner(BuildContext context, WarehouseProvider provider) async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      if (!context.mounted) return;
      final String? code = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const TransactionScannerScreen(),
        ),
      );
      if (code != null) {
        _onBarcodeScanned(code, provider);
      }
    } else {
      _showErrorSnackBar('Izin kamera dibutuhkan untuk scan barcode!');
    }
  }

  void _onBarcodeScanned(String code, WarehouseProvider provider) {
    String cleanCode = code.trim();
    if (cleanCode.toLowerCase().startsWith('sku:')) {
      cleanCode = cleanCode.substring(4).trim();
    }
    final cleanCodeLower = cleanCode.toLowerCase();

    // 1. Check if it's a product (sale-only)
    final prod = provider.products.firstWhere(
      (p) => p['sku']?.toString().toLowerCase() == cleanCodeLower ||
             p['name']?.toString().toLowerCase() == cleanCodeLower,
      orElse: () => null,
    );
    if (prod != null) {
      _showErrorSnackBar('Item ini tidak dapat diisi ulang! Hanya tabung oksigen yang bisa diisi ulang.');
      return;
    }

    // 2. Check if it's a cylinder or accessory (in provider.cylinders)
    final cyl = provider.cylinders.firstWhere(
      (c) => c['serialNumber']?.toString().toLowerCase() == cleanCodeLower,
      orElse: () => null,
    );

    if (cyl != null) {
      final isAcc = _isAccessoryAsset(cyl['serialNumber']?.toString() ?? '', cyl['size']?.toString() ?? '');
      if (isAcc) {
        _showErrorSnackBar('Aksesoris sewa tidak dapat diisi ulang! Hanya tabung oksigen yang bisa diisi ulang.');
        return;
      }

      // Rentable cylinder
      final size = cyl['size']?.toString() ?? '1m3';
      if (_cylinderQty.containsKey(size)) {
        final int stock = provider.actualCylinders.where((c) => (c['size'] ?? '1m3') == size && c['status'] == 'AVAILABLE').length;
        final int currentQty = _cylinderQty[size] ?? 0;
        if (currentQty >= stock) {
          _showErrorSnackBar('Stok isi ulang untuk tabung $size sudah mencapai batas maksimum!');
        } else {
          setState(() {
            _cylinderQty[size] = currentQty + 1;
          });
          _updateSuggestedPrices();
          _showSuccessSnackBar('Berhasil menambahkan isi ulang: Tabung Oksigen $size');
        }
      } else {
        _showErrorSnackBar('Tabung dengan ukuran $size tidak ditemukan di form!');
      }
      return;
    }

    // 3. Check if it's a cylinder group SKU (starts with 'cyl-')
    if (cleanCodeLower.startsWith('cyl-')) {
      final size = cleanCode.substring(4);
      if (_cylinderQty.containsKey(size)) {
        final int stock = provider.actualCylinders.where((c) => (c['size'] ?? '1m3') == size && c['status'] == 'AVAILABLE').length;
        final int currentQty = _cylinderQty[size] ?? 0;
        if (currentQty >= stock) {
          _showErrorSnackBar('Stok isi ulang untuk tabung $size sudah mencapai batas maksimum!');
        } else {
          setState(() {
            _cylinderQty[size] = currentQty + 1;
          });
          _updateSuggestedPrices();
          _showSuccessSnackBar('Berhasil menambahkan isi ulang: Tabung Oksigen $size');
        }
      } else {
        _showErrorSnackBar('Tabung dengan ukuran $size tidak ditemukan di form!');
      }
      return;
    }

    // 4. If accessory SKU is scanned
    if (cleanCodeLower == 'rnt-acc') {
      _showErrorSnackBar('Aksesoris sewa tidak dapat diisi ulang! Hanya tabung oksigen yang bisa diisi ulang.');
      return;
    }

    // 5. Not found
    _showErrorSnackBar('Barcode/QR tidak terdaftar di sistem!');
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)),
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF00A67E)),
    );
  }
}
