import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/core/state/transaction_provider.dart';
import 'package:oksigen24medis_mobile2/core/state/warehouse_provider.dart';
import 'package:oksigen24medis_mobile2/features/payment/payment_screen.dart';
import 'package:oksigen24medis_mobile2/features/payment/receipt_item.dart';
import 'package:provider/provider.dart';

class RentalFormScreen extends StatefulWidget {
  const RentalFormScreen({super.key});

  @override
  State<RentalFormScreen> createState() => _RentalFormScreenState();
}

class _RentalFormScreenState extends State<RentalFormScreen> {
  DateTime _returnDate = DateTime.now().add(const Duration(days: 7));
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCustomerId;

  // Dynamic qty map: size -> quantity (e.g. '1m3' -> 2)
  final Map<String, int> _cylinderQty = {};
  // Dynamic accessory qty map: name -> quantity (e.g. 'Sewa Regulator Medis' -> 1)
  final Map<String, int> _accessoryQty = {};

  late TextEditingController _tarifController;
  late TextEditingController _depositController;

  @override
  void initState() {
    super.initState();
    _tarifController = TextEditingController(text: '0');
    _depositController = TextEditingController(text: '0');
    _tarifController.addListener(_onAmountChanged);
    _depositController.addListener(_onAmountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(context, listen: false).fetchCustomers();
      Provider.of<WarehouseProvider>(context, listen: false).fetchInventory();
    });
  }

  // ── Customer Picker Bottom Sheet ───────────────────────────────────────────
  Future<void> _showCustomerPicker(
      BuildContext context, TransactionProvider tx) async {
    // 1. Fetch customers in background if empty
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

  // ── Add Customer Bottom Sheet ──────────────────────────────────────────────
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
                                  // Capture messenger before async gap
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
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
                                    // Auto-select the newly created customer
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
                                        backgroundColor: const Color(
                                          0xFF00A67E,
                                        ),
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
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 20),
                          label: Text(
                            isSubmitting ? 'Menyimpan...' : 'Simpan Pelanggan',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
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

  @override
  void dispose() {
    _tarifController.removeListener(_onAmountChanged);
    _depositController.removeListener(_onAmountChanged);
    _tarifController.dispose();
    _depositController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    setState(() {});
  }

  // Recalculate suggested tariff and deposit from cylinder quantities
  void _updateSuggestedPrices(Map<String, int> stockBySize) {
    // Price tiers per size (can be refined from backend pricePerUnit later)
    const Map<String, int> tarifPerUnit = {
      '0.3m3': 15000,
      '0.5m3': 20000,
      '1m3': 30000,
      '6m3': 80000,
    };
    const Map<String, int> depositPerUnit = {
      '0.3m3': 150000,
      '0.5m3': 200000,
      '1m3': 400000,
      '6m3': 1500000,
    };

    int tarif = 0;
    int deposit = 0;
    _cylinderQty.forEach((size, qty) {
      tarif += (tarifPerUnit[size] ?? 30000) * qty;
      deposit += (depositPerUnit[size] ?? 400000) * qty;
    });

    // Add accessories dynamic fees & deposits
    final provider = Provider.of<WarehouseProvider>(context, listen: false);
    final rentableAccessoriesList = provider.rentableAccessories;
    _accessoryQty.forEach((name, qty) {
      if (qty > 0) {
        final matchingAcc = rentableAccessoriesList.firstWhere(
          (c) => c['oxygenType']?['name'] == name,
          orElse: () => null,
        );
        final double basePrice = double.tryParse(matchingAcc?['oxygenType']?['pricePerUnit']?.toString() ?? '25000') ?? 25000.0;
        tarif += (basePrice.toInt() * qty);
        
        // Default deposit: 100,000 per unit for accessories
        deposit += 100000 * qty;
      }
    });

    _tarifController.text = _formatCurrency(tarif);
    _depositController.text = _formatCurrency(deposit);
  }

  int _calculateDays(DateTime date) {
    final today = DateTime.now();
    final diff = date.difference(today).inDays;
    return diff > 0 ? diff : 1;
  }

  String _formatIndonesianDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  int get _rentalDays => _calculateDays(_returnDate);

  Future<void> _selectReturnDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _returnDate) {
      setState(() {
        _returnDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final warehouseProvider = Provider.of<WarehouseProvider>(context);

    // ── Build dynamic stock map per cylinder size ──────────────────────────
    // Group AVAILABLE cylinders by size and count them
    final Map<String, int> stockBySize = {};
    for (final cyl in warehouseProvider.actualCylinders) {
      if (cyl['status'] == 'AVAILABLE') {
        final size = cyl['size']?.toString() ?? 'Unknown';
        stockBySize[size] = (stockBySize[size] ?? 0) + 1;
      }
    }

    // Get all unique sizes sorted naturally (e.g. 0.3m3, 1m3, 6m3)
    final List<String> sizes = stockBySize.keys.toList()
      ..sort((a, b) {
        // Sort by numeric value extracted from size string
        final numA = double.tryParse(a.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        final numB = double.tryParse(b.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        return numA.compareTo(numB);
      });

    // Ensure qty map has an entry for every size
    for (final size in sizes) {
      _cylinderQty.putIfAbsent(size, () => 0);
    }

    // ── Build dynamic stock map per accessory ──────────────────────────────
    final Map<String, int> stockByAccessory = {};
    for (final acc in warehouseProvider.rentableAccessories) {
      if (acc['status'] == 'AVAILABLE') {
        final name = acc['oxygenType']?['name']?.toString() ?? 'Accessory';
        stockByAccessory[name] = (stockByAccessory[name] ?? 0) + 1;
      }
    }

    // Get all unique accessory names (either in stock or currently selected with quantity > 0)
    final Set<String> allAccessoryNames = {...stockByAccessory.keys, ..._accessoryQty.keys};
    final List<String> sortedAccessories = allAccessoryNames.toList()..sort();

    // Ensure qty map has an entry for every accessory
    for (final name in sortedAccessories) {
      _accessoryQty.putIfAbsent(name, () => 0);
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
          'Sewa Kontrak Baru',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            color: const Color(0xFFC3C5D9).withAlpha(128),
            height: 0.5,
          ),
        ),
      ),
      body: warehouseProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── COMPONENT 1: PELANGGAN & TANGGAL ───────────────────────
                  _buildCustomerAndDurationCard(txProvider),

                  const SizedBox(height: 24),

                  // ── COMPONENT 2: PILIHAN ITEM SEWA ─────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ITEM YANG DISEWA',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF434656),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Kelola Jumlah',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (sizes.isEmpty && sortedAccessories.isEmpty)
                    Container(
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
                              'Tidak ada stok tersedia',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _buildCylinderSection(sizes, stockBySize),
                    if (sizes.isNotEmpty && sortedAccessories.isNotEmpty)
                      const SizedBox(height: 20),
                    _buildAccessorySection(sortedAccessories, stockByAccessory, stockBySize),
                  ],

                  const SizedBox(height: 24),

                  // ── COMPONENT 3: INPUT BIAYA MANUAL ────────────────────────
                  Text(
                    'Rincian Biaya',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF434656),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBillingDetailsCard(),

                  const SizedBox(height: 100), // Scroll padding
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomCheckout(warehouseProvider),
    );
  }

  // ── Customer and Duration Card ─────────────────────────────────────────────
  Widget _buildCustomerAndDurationCard(TransactionProvider tx) {
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
                    Icon(
                      Icons.add_circle_outline,
                      size: 14,
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
          // Customer picker — always tappable, opens bottom sheet
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: AppColors.border, height: 1),
          ),
          Text(
            'Tgl Pengembalian (Wajib)',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _selectReturnDate(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatIndonesianDate(_returnDate)} ($_rentalDays Hari)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cylinder Items Section ────────────────────────────────────────────────
  Widget _buildCylinderSection(
    List<String> sizes,
    Map<String, int> stockBySize,
  ) {
    if (sizes.isEmpty) {
      return const SizedBox.shrink();
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
          _updateSuggestedPrices(stockBySize);
        }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TABUNG OKSIGEN',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF434656),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
        ),
      ],
    );
  }

  // ── Accessory Items Section ───────────────────────────────────────────────
  Widget _buildAccessorySection(
    List<String> accessoryNames,
    Map<String, int> stockByAccessory,
    Map<String, int> stockBySize,
  ) {
    if (accessoryNames.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Widget> rows = [];
    for (int i = 0; i < accessoryNames.length; i++) {
      final name = accessoryNames[i];
      final stock = stockByAccessory[name] ?? 0;
      final qty = _accessoryQty[name] ?? 0;

      if (i > 0) rows.add(const Divider(color: AppColors.border, height: 1));

      rows.add(
        _buildItemStepper(name, stock, qty, (v) {
          setState(() => _accessoryQty[name] = v);
          _updateSuggestedPrices(stockBySize);
        }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AKSESORIS SEWA',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF434656),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
        ),
      ],
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
                  'Stok Tersedia: $stock',
                  style: AppTextStyles.caption.copyWith(
                    color: stock == 0
                        ? AppColors.error
                        : stock <= 3
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
                onPressed: qty < stock ? () => onChanged(qty + 1) : null,
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
              labelText: 'Tarif Sewa Manual',
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
          TextFormField(
            controller: _depositController,
            keyboardType: TextInputType.number,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
            inputFormatters: [CurrencyInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Total Uang Jaminan (Deposit)',
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
    final int deposit =
        int.tryParse(_depositController.text.replaceAll('.', '')) ?? 0;
    final int totalPrice = tarif + deposit;
    final formattedPrice = _formatCurrency(totalPrice);

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

                    if (totalPrice <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Rincian biaya wajib diisi untuk diproses',
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    // Collect AVAILABLE cylinder UUIDs dynamically per size
                    final List<String> cylinderIds = [];
                    final availableCyls = provider.actualCylinders
                        .where((c) => c['status'] == 'AVAILABLE')
                        .toList();

                    _cylinderQty.forEach((size, qty) {
                      if (qty > 0) {
                        final picked = availableCyls
                            .where((c) => c['size'] == size)
                            .take(qty)
                            .map((c) => c['id'].toString())
                            .toList();
                        cylinderIds.addAll(picked);
                      }
                    });

                    // Add accessory IDs dynamically
                    final availableAccessories = provider.rentableAccessories
                        .where((c) => c['status'] == 'AVAILABLE')
                        .toList();

                    _accessoryQty.forEach((name, qty) {
                      if (qty > 0) {
                        final picked = availableAccessories
                            .where((c) => c['oxygenType']?['name'] == name)
                            .take(qty)
                            .map((c) => c['id'].toString())
                            .toList();
                        cylinderIds.addAll(picked);
                      }
                    });

                    final int totalQty =
                        _cylinderQty.values.fold<int>(0, (a, b) => a + b) +
                        _accessoryQty.values.fold<int>(0, (a, b) => a + b);

                    // Determine primary size/label for receipt
                    final primarySize =
                        _cylinderQty.entries
                            .where((e) => e.value > 0)
                            .map((e) => e.key)
                            .firstOrNull ??
                        _accessoryQty.entries
                            .where((e) => e.value > 0)
                            .map((e) => e.key)
                            .firstOrNull ??
                        'Aksesoris';

                    // Build receipt items list
                    final List<ReceiptItem> receiptItems = [];
                    const Map<String, int> tarifPerUnit = {
                      '0.3m3': 15000,
                      '0.5m3': 20000,
                      '1m3': 30000,
                      '6m3': 80000,
                    };

                    _cylinderQty.forEach((size, qty) {
                      if (qty > 0) {
                        final price = tarifPerUnit[size] ?? 30000;
                        receiptItems.add(
                          ReceiptItem(
                            name: 'Sewa Tabung Oksigen $size',
                            price: price,
                            quantity: qty,
                            subtitle: 'Rent: $_rentalDays Hari',
                          ),
                        );
                      }
                    });

                    _accessoryQty.forEach((name, qty) {
                      if (qty > 0) {
                        final matchingAcc = availableAccessories.firstWhere(
                          (c) => c['oxygenType']?['name'] == name,
                          orElse: () => null,
                        );
                        final double basePrice = double.tryParse(matchingAcc?['oxygenType']?['pricePerUnit']?.toString() ?? '25000') ?? 25000.0;
                        receiptItems.add(
                          ReceiptItem(
                            name: name,
                            price: basePrice.toInt(),
                            quantity: qty,
                            subtitle: 'Rent: $_rentalDays Hari',
                          ),
                        );
                      }
                    });
                    if (deposit > 0) {
                      receiptItems.add(
                        ReceiptItem(
                          name: 'Deposit Jaminan',
                          price: deposit,
                          quantity: 1,
                        ),
                      );
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PaymentScreen(
                          quantity: totalQty,
                          selectedSize: primarySize,
                          tarif: tarif,
                          deposit: deposit,
                          customerName: _searchController.text,
                          invoiceNo: 'RNT-TEMP',
                          receiptItems: receiptItems,
                          type: 'RENTAL',
                          customerId: _selectedCustomerId,
                          dueDate: _returnDate,
                          cylinderIds: cylinderIds,
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
}

// ── Currency Input Formatter ───────────────────────────────────────────────
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final digits = newValue.text.replaceAll('.', '');
    final number = int.tryParse(digits);
    if (number == null) return oldValue;
    final formatted = number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
