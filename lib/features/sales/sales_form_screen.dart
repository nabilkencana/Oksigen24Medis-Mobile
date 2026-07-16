import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/core/state/transaction_provider.dart';
import 'package:oksigen24medis_mobile2/core/state/warehouse_provider.dart';
import 'package:oksigen24medis_mobile2/features/payment/payment_screen.dart';
import 'package:oksigen24medis_mobile2/features/payment/receipt_item.dart';
import 'package:provider/provider.dart';

class SalesFormScreen extends StatefulWidget {
  const SalesFormScreen({super.key});

  @override
  State<SalesFormScreen> createState() => _SalesFormScreenState();
}

class _SalesFormScreenState extends State<SalesFormScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCustomerId;

  // Local map to track selected quantity for each productId
  final Map<String, int> _selectedQuantities = {};

  late TextEditingController _tarifController;

  @override
  void initState() {
    super.initState();
    _tarifController = TextEditingController(text: '0');
    _tarifController.addListener(_onAmountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(context, listen: false).fetchCustomers();
      Provider.of<WarehouseProvider>(context, listen: false).fetchInventory().then((_) {
        // Initialize default mock quantities for user ease of checkout matching mockup
        final provider = Provider.of<WarehouseProvider>(context, listen: false);
        for (var p in provider.products) {
          final String id = p['id'].toString();
          if (p['name'].toString().contains('Trolley') || p['name'].toString().contains('Troli')) {
            _selectedQuantities[id] = 1;
          } else if (p['name'].toString().contains('Cannula') || p['name'].toString().contains('Nasal')) {
            _selectedQuantities[id] = 2;
          } else {
            _selectedQuantities[id] = 0;
          }
        }
        _updateSuggestedPrices(provider.products);
      });
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

  // Recalculates default suggested prices based on current quantities
  void _updateSuggestedPrices(List<dynamic> products) {
    double total = 0;
    _selectedQuantities.forEach((prodId, qty) {
      final prod = products.firstWhere((p) => p['id'] == prodId, orElse: () => null);
      if (prod != null) {
        final double price = double.tryParse(prod['price']?.toString() ?? '0') ?? 0;
        total += price * qty;
      }
    });

    _tarifController.text = _formatCurrency(total.round());
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final warehouseProvider = Provider.of<WarehouseProvider>(context);

    final int salesTotal = int.tryParse(_tarifController.text.replaceAll('.', '')) ?? 0;
    final int subtotal = (salesTotal / 1.1).round();
    final int ppn = salesTotal - subtotal;

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
          'Penjualan Barang',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
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
            // Section Header: Pelanggan
            _buildSectionHeader('Pelanggan', Icons.person_outline),
            const SizedBox(height: 8),
            // ── COMPONENT 1: PELANGGAN ───────────────────────────────────────
            _buildCustomerCard(txProvider),

            const SizedBox(height: 24),

            // Section Header: Pilihan Item Penjualan
            _buildSectionHeader('Pilihan Item Penjualan', Icons.shopping_basket_outlined),
            const SizedBox(height: 8),
            // ── COMPONENT 2: PILIHAN ITEM PENJUALAN ──────────────────────────
            _buildItemsCard(warehouseProvider),

            const SizedBox(height: 24),

            // Section Header: Rincian Biaya
            _buildSectionHeader('Rincian Biaya', Icons.receipt_long_outlined),
            const SizedBox(height: 8),
            // ── COMPONENT 3: INPUT BIAYA MANUAL ──────────────────────────────
            _buildBillingDetailsCard(subtotal, ppn),

            const SizedBox(height: 100), // Scroll padding
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomCheckout(salesTotal, warehouseProvider),
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
                'Pilih Pelanggan (Opsional)',
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
                  if (_selectedCustomerId != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCustomerId = null;
                          _searchController.clear();
                        });
                      },
                      child: const Icon(Icons.close,
                          color: AppColors.textSecondary, size: 18),
                    )
                  else if (tx.isLoading)
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

  // ── Items Card ─────────────────────────────────────────────────────────────
  Widget _buildItemsCard(WarehouseProvider provider) {
    if (provider.isLoading && provider.products.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: provider.products.length,
        separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
        itemBuilder: (context, index) {
          final p = provider.products[index];
          final String id = p['id'].toString();
          final String name = p['name'] ?? 'Barang';
          final int stock = p['currentStock'] ?? 0;
          final double price = double.tryParse(p['price']?.toString() ?? '0') ?? 0.0;
          final int qty = _selectedQuantities[id] ?? 0;

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
                          fontWeight: qty > 0 ? FontWeight.w800 : FontWeight.w600,
                          color: qty > 0 ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stok: $stock • @ ${_formatCurrency(price.round())}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: qty > 0
                          ? () {
                              setState(() => _selectedQuantities[id] = qty - 1);
                              _updateSuggestedPrices(provider.products);
                            }
                          : null,
                      icon: const Icon(Icons.remove_circle_outline, size: 24),
                      color: AppColors.textSecondary,
                    ),
                    Text(
                      '$qty',
                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: qty < stock
                          ? () {
                              setState(() => _selectedQuantities[id] = qty + 1);
                              _updateSuggestedPrices(provider.products);
                            }
                          : null,
                      icon: const Icon(Icons.add_circle_outline, size: 24),
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Billing Details Card ───────────────────────────────────────────────────
  Widget _buildBillingDetailsCard(int subtotal, int ppn) {
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
              labelText: 'Total Tagihan Manual',
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DPP (Subtotal)',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                'Rp ${_formatCurrency(subtotal)}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PPN (10% DPP)',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                'Rp ${_formatCurrency(ppn)}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom Checkout ────────────────────────────────────────────────────────
  Widget _buildBottomCheckout(int salesTotal, WarehouseProvider provider) {
    final formattedPrice = _formatCurrency(salesTotal);

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
                    if (salesTotal <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rincian biaya wajib diisi untuk diproses'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    // Dynamically map items to SaleItemDto format
                    final List<Map<String, dynamic>> checkoutItems = [];
                    final List<ReceiptItem> receiptItems = [];

                    _selectedQuantities.forEach((prodId, qty) {
                      if (qty > 0) {
                        final prod = provider.products.firstWhere((p) => p['id'] == prodId);
                        checkoutItems.add({
                          'productId': prodId,
                          'quantity': qty,
                        });
                        receiptItems.add(ReceiptItem(
                          name: prod['name'] ?? 'Alat Medis',
                          price: double.tryParse(prod['price']?.toString() ?? '0')?.round() ?? 0,
                          quantity: qty,
                        ));
                      }
                    });

                    final totalQty = checkoutItems.fold<int>(0, (sum, i) => sum + int.parse(i['quantity'].toString()));

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PaymentScreen(
                          quantity: totalQty,
                          selectedSize: 'Barang',
                          tarif: salesTotal,
                          deposit: 0,
                          customerName: _searchController.text.isNotEmpty ? _searchController.text : 'Jual Putus',
                          invoiceNo: 'SAL-TEMP',
                          receiptItems: receiptItems,
                          type: 'SALE',
                          customerId: _selectedCustomerId,
                          items: checkoutItems,
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

  // ── Add New Customer Sheet ─────────────────────────────────────────────────
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
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
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
                          prefixIcon:
                              const Icon(Icons.person_outline, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.5),
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
                          prefixIcon:
                              const Icon(Icons.phone_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.5),
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
                            child:
                                Icon(Icons.location_on_outlined, size: 20),
                          ),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.5),
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
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  setSheetState(
                                      () => isSubmitting = true);
                                  final messenger =
                                      ScaffoldMessenger.of(context);
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
                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                    }
                                    if (mounted) {
                                      setState(() {
                                        _selectedCustomerId =
                                            newCustomer['id']?.toString();
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
                                        backgroundColor:
                                            const Color(0xFF00A67E),
                                      ),
                                    );
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setSheetState(
                                          () => isSubmitting = false);
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
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
}
