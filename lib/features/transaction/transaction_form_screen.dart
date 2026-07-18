import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/features/payment/payment_screen.dart';
import 'package:oksigen24medis_mobile2/features/payment/receipt_item.dart';

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  DateTime _returnDate = DateTime(
    2026,
    7,
    21,
  ); // Default 7 days from 14 July 2026
  final TextEditingController _searchController = TextEditingController(
    text: 'Klinik Sehat Bersama',
  );

  // Quantities for all 8 items
  int _qtyTabungBesarRent = 0;
  int _qtyTabungSedangRent = 0;
  int _qtyTabungKecilRent = 1; // Default
  int _qtyRegulatorRent = 1; // Default

  int _qtyIsiUlangBesar = 0;
  int _qtyIsiUlangSedang = 0;
  int _qtyIsiUlangKecil = 0;

  int _qtyTroliJual = 0;

  // Prices
  final int _priceTabungBesarRent = 50000;
  final int _priceTabungSedangRent = 35000;
  final int _priceTabungKecilRent = 25000;
  final int _priceRegulatorRent = 15000;

  final int _priceIsiUlangBesar = 100000;
  final int _priceIsiUlangSedang = 75000;
  final int _priceIsiUlangKecil = 50000;

  final int _priceTroliJual = 250000;

  int _calculateDays(DateTime date) {
    final today = DateTime(2026, 7, 14); // Anchored today matching mockup
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

  int get _totalRentals {
    final sum =
        (_priceTabungBesarRent * _qtyTabungBesarRent) +
        (_priceTabungSedangRent * _qtyTabungSedangRent) +
        (_priceTabungKecilRent * _qtyTabungKecilRent) +
        (_priceRegulatorRent * _qtyRegulatorRent);
    return sum * _rentalDays;
  }

  int get _totalRefills {
    return (_priceIsiUlangBesar * _qtyIsiUlangBesar) +
        (_priceIsiUlangSedang * _qtyIsiUlangSedang) +
        (_priceIsiUlangKecil * _qtyIsiUlangKecil);
  }

  int get _totalSales {
    return _priceTroliJual * _qtyTroliJual;
  }

  int get _totalEstimasi => _totalRentals + _totalRefills + _totalSales;

  Future<void> _selectReturnDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: DateTime(2026, 7, 15),
      lastDate: DateTime(2027, 7, 14),
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'Transaksi Baru',
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
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── COMPONENT 1: PELANGGAN & DURASI SEWA ─────────────────────────
            _buildCustomerAndDurationCard(),

            const SizedBox(height: 16),

            // ── COMPONENT 2: KATEGORI SEWA (RENTALS) ─────────────────────────
            Text(
              'Sewa Tabung & Aksesoris',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF434656),
              ),
            ),
            const SizedBox(height: 8),
            _buildRentalsCard(),

            const SizedBox(height: 16),

            // ── COMPONENT 3: KATEGORI ISI ULANG (REFILLS) ────────────────────
            Text(
              'Isi Ulang Oksigen',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF434656),
              ),
            ),
            const SizedBox(height: 8),
            _buildRefillsCard(),

            const SizedBox(height: 16),

            // ── COMPONENT 4: KATEGORI PENJUALAN (SALES) ──────────────────────
            Text(
              'Penjualan Barang',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF434656),
              ),
            ),
            const SizedBox(height: 8),
            _buildSalesCard(),

            const SizedBox(height: 100), // Scroll padding
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomCheckout(),
    );
  }

  // ── Customer and Duration Card ─────────────────────────────────────────────
  Widget _buildCustomerAndDurationCard() {
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
            children: [
              Expanded(
                child: TextFormField(
                  controller: _searchController,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari Pelanggan...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _showAddCustomerBottomSheet(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  foregroundColor: AppColors.primary,
                ),
                child: Text(
                  '+ Baru',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: AppColors.border, height: 1),
          ),
          GestureDetector(
            onTap: () => _selectReturnDate(context),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tgl Pengembalian (Untuk item sewa)',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatIndonesianDate(_returnDate)} ($_rentalDays Hari)',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Rentals Card ───────────────────────────────────────────────────────────
  Widget _buildRentalsCard() {
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
      child: Column(
        children: [
          _buildItemRow(
            'Tabung Besar',
            'Rp ${_formatCurrency(_priceTabungBesarRent)} / hari',
            _qtyTabungBesarRent,
            (newQty) => setState(() => _qtyTabungBesarRent = newQty),
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildItemRow(
            'Tabung Sedang',
            'Rp ${_formatCurrency(_priceTabungSedangRent)} / hari',
            _qtyTabungSedangRent,
            (newQty) => setState(() => _qtyTabungSedangRent = newQty),
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildItemRow(
            'Tabung Kecil',
            'Rp ${_formatCurrency(_priceTabungKecilRent)} / hari',
            _qtyTabungKecilRent,
            (newQty) => setState(() => _qtyTabungKecilRent = newQty),
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildItemRow(
            'Regulator Medis',
            'Rp ${_formatCurrency(_priceRegulatorRent)} / hari',
            _qtyRegulatorRent,
            (newQty) => setState(() => _qtyRegulatorRent = newQty),
          ),
        ],
      ),
    );
  }

  // ── Refills Card ───────────────────────────────────────────────────────────
  Widget _buildRefillsCard() {
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
      child: Column(
        children: [
          _buildItemRow(
            'Isi Ulang Besar',
            'Rp ${_formatCurrency(_priceIsiUlangBesar)}',
            _qtyIsiUlangBesar,
            (newQty) => setState(() => _qtyIsiUlangBesar = newQty),
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildItemRow(
            'Isi Ulang Sedang',
            'Rp ${_formatCurrency(_priceIsiUlangSedang)}',
            _qtyIsiUlangSedang,
            (newQty) => setState(() => _qtyIsiUlangSedang = newQty),
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildItemRow(
            'Isi Ulang Kecil (min 0.5)',
            'Rp ${_formatCurrency(_priceIsiUlangKecil)}',
            _qtyIsiUlangKecil,
            (newQty) => setState(() => _qtyIsiUlangKecil = newQty),
          ),
        ],
      ),
    );
  }

  // ── Sales Card ─────────────────────────────────────────────────────────────
  Widget _buildSalesCard() {
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
      child: Column(
        children: [
          _buildItemRow(
            'Troli Tabung',
            'Rp ${_formatCurrency(_priceTroliJual)}',
            _qtyTroliJual,
            (newQty) => setState(() => _qtyTroliJual = newQty),
            subWidget: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Hanya Jual (Tidak Disewakan)',
                style: AppTextStyles.caption.copyWith(
                  color: const Color(
                    0xFFF59E0B,
                  ), // AppColors.warning orange-red
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable Item Row Helper ───────────────────────────────────────────────
  Widget _buildItemRow(
    String name,
    String priceText,
    int qty,
    ValueChanged<int> onQtyChanged, {
    Widget? subWidget,
  }) {
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
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  priceText,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                subWidget ?? const SizedBox.shrink(),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (qty > 0) {
                    onQtyChanged(qty - 1);
                  }
                },
                icon: const Icon(
                  Icons.remove,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size(36, 36),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$qty',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  onQtyChanged(qty + 1);
                },
                icon: const Icon(Icons.add, color: AppColors.surface, size: 20),
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(36, 36),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom Checkout ────────────────────────────────────────────────────────
  Widget _buildBottomCheckout() {
    final formattedPrice = _formatCurrency(_totalEstimasi);

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
                    'Total Estimasi',
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
                    if (_totalEstimasi <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pilih minimal 1 item untuk diproses'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    // Build itemized list for PaymentScreen
                    final List<ReceiptItem> receiptItems = [];
                    if (_qtyTabungBesarRent > 0) {
                      receiptItems.add(
                        ReceiptItem(
                          name: 'Sewa Tabung Besar',
                          price: _priceTabungBesarRent * _rentalDays,
                          quantity: _qtyTabungBesarRent,
                          subtitle: 'Rent: $_rentalDays Hari',
                        ),
                      );
                    }
                    if (_qtyTabungSedangRent > 0) {
                      receiptItems.add(
                        ReceiptItem(
                          name: 'Sewa Tabung Sedang',
                          price: _priceTabungSedangRent * _rentalDays,
                          quantity: _qtyTabungSedangRent,
                          subtitle: 'Rent: $_rentalDays Hari',
                        ),
                      );
                    }
                    if (_qtyTabungKecilRent > 0) {
                      receiptItems.add(
                        ReceiptItem(
                          name: 'Sewa Tabung Kecil',
                          price: _priceTabungKecilRent * _rentalDays,
                          quantity: _qtyTabungKecilRent,
                          subtitle: 'Rent: $_rentalDays Hari',
                        ),
                      );
                    }
                    if (_qtyRegulatorRent > 0) {
                      receiptItems.add(
                        ReceiptItem(
                          name: 'Sewa Regulator',
                          price: _priceRegulatorRent * _rentalDays,
                          quantity: _qtyRegulatorRent,
                          subtitle: 'Rent: $_rentalDays Hari',
                        ),
                      );
                    }
                    if (_qtyIsiUlangBesar > 0) {
                      receiptItems.add(
                        ReceiptItem(
                          name: 'Isi Ulang Besar',
                          price: _priceIsiUlangBesar,
                          quantity: _qtyIsiUlangBesar,
                        ),
                      );
                    }
                    if (_qtyIsiUlangSedang > 0) {
                      receiptItems.add(
                        ReceiptItem(
                          name: 'Isi Ulang Sedang',
                          price: _priceIsiUlangSedang,
                          quantity: _qtyIsiUlangSedang,
                        ),
                      );
                    }
                    if (_qtyIsiUlangKecil > 0) {
                      receiptItems.add(
                        ReceiptItem(
                          name: 'Isi Ulang Kecil (min 0.5)',
                          price: _priceIsiUlangKecil,
                          quantity: _qtyIsiUlangKecil,
                        ),
                      );
                    }
                    if (_qtyTroliJual > 0) {
                      receiptItems.add(
                        ReceiptItem(
                          name: 'Beli Troli Tabung',
                          price: _priceTroliJual,
                          quantity: _qtyTroliJual,
                        ),
                      );
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PaymentScreen(
                          customerName: _searchController.text,
                          invoiceNo: 'INV-20260714-02',
                          receiptItems: receiptItems,
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
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 18),
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

  // ── Bottom Sheet for adding customer ───────────────────────────────────────
  void _showAddCustomerBottomSheet(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tambah Pelanggan Baru',
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Pelanggan',
                      labelStyle: AppTextStyles.bodyMedium,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Nomor Telepon',
                      labelStyle: AppTextStyles.bodyMedium,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Nomor telepon wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Alamat Lengkap',
                      labelStyle: AppTextStyles.bodyMedium,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Alamat wajib diisi' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        setState(() {
                          _searchController.text = nameController.text;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Pelanggan "${nameController.text}" Berhasil Ditambahkan',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Simpan'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
