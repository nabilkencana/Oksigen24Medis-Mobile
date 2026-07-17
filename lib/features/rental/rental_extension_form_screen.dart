import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/features/payment/payment_screen.dart';
import 'package:oksigen24medis_mobile2/features/payment/receipt_item.dart';
import 'package:oksigen24medis_mobile2/features/transaction/transaction_detail_screen.dart';

class RentalExtensionFormScreen extends StatefulWidget {
  final String rentalId;
  final String invoiceNo;
  final String customerName;
  final String returnDeadline;
  final List<DetailItem> items;

  const RentalExtensionFormScreen({
    super.key,
    required this.rentalId,
    required this.invoiceNo,
    required this.customerName,
    required this.returnDeadline,
    required this.items,
  });

  @override
  State<RentalExtensionFormScreen> createState() => _RentalExtensionFormScreenState();
}

class _RentalExtensionFormScreenState extends State<RentalExtensionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _originalDueDate;
  late DateTime _newDueDate;
  late TextEditingController _feeController;

  @override
  void initState() {
    super.initState();
    // Parse returnDeadline or default to today + 7
    DateTime parsedOriginal;
    try {
      // returnDeadline is usually '2026-07-21' or similar
      parsedOriginal = DateTime.parse(widget.returnDeadline);
    } catch (_) {
      parsedOriginal = DateTime.now();
    }
    _originalDueDate = parsedOriginal;
    // Default new due date to original + 7 days
    _newDueDate = _originalDueDate.add(const Duration(days: 7));

    // Calculate suggested fee: e.g. Rp 10.000 per item per day
    final totalUnits = widget.items.fold<int>(0, (sum, item) => sum + item.qty);
    const costPerDay = 10000;
    final extensionDays = _newDueDate.difference(_originalDueDate).inDays;
    final suggestedFee = totalUnits * costPerDay * (extensionDays > 0 ? extensionDays : 7);

    _feeController = TextEditingController(text: _formatCurrencyRaw(suggestedFee));
    _feeController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _feeController.removeListener(_onAmountChanged);
    _feeController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    setState(() {});
  }

  String _formatCurrencyRaw(int amount) {
    final valueStr = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < valueStr.length; i++) {
      if (i > 0 && (valueStr.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(valueStr[i]);
    }
    return buffer.toString();
  }

  String _formatCurrency(int amount) {
    return 'Rp ${_formatCurrencyRaw(amount)}';
  }

  Future<void> _selectNewDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _newDueDate.isAfter(_originalDueDate) ? _newDueDate : _originalDueDate.add(const Duration(days: 1)),
      firstDate: _originalDueDate.add(const Duration(days: 1)),
      lastDate: _originalDueDate.add(const Duration(days: 180)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _newDueDate) {
      setState(() {
        _newDueDate = picked;
      });
      // Update suggested price when date changes
      final totalUnits = widget.items.fold<int>(0, (sum, item) => sum + item.qty);
      const costPerDay = 10000;
      final extensionDays = _newDueDate.difference(_originalDueDate).inDays;
      final suggestedFee = totalUnits * costPerDay * (extensionDays > 0 ? extensionDays : 1);
      _feeController.text = _formatCurrencyRaw(suggestedFee);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extensionDays = _newDueDate.difference(_originalDueDate).inDays;
    final int extraFee = int.tryParse(_feeController.text.replaceAll('.', '')) ?? 0;

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
          'Perpanjangan Sewa',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ORIGINAL TRANSACTION CARD
              _buildSectionHeader('Info Transaksi Asal', Icons.receipt_outlined),
              const SizedBox(height: 8),
              _buildTransactionInfoCard(),

              const SizedBox(height: 24),

              // 2. RENTED ITEMS LIST CARD
              _buildSectionHeader('Item Yang Diperpanjang', Icons.shopping_basket_outlined),
              const SizedBox(height: 8),
              _buildItemsCard(),

              const SizedBox(height: 24),

              // 3. EXTENSION SETUP CARD
              _buildSectionHeader('Detail Perpanjangan', Icons.calendar_month_outlined),
              const SizedBox(height: 8),
              _buildExtensionSetupCard(extensionDays),

              const SizedBox(height: 100), // Scroll padding
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomCheckout(extraFee),
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

  Widget _buildTransactionInfoCard() {
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
          _buildInfoRow('Invoice No.', widget.invoiceNo),
          const Divider(height: 20),
          _buildInfoRow('Pelanggan', widget.customerName),
          const Divider(height: 20),
          _buildInfoRow(
            'Batas Pengembalian Asal',
            '${_originalDueDate.day} ${_getMonthName(_originalDueDate.month)} ${_originalDueDate.year}',
            valueColor: AppColors.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
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
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.items.length,
        separatorBuilder: (context, index) => const Divider(height: 20),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${item.qty}x',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExtensionSetupCard(int extensionDays) {
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
          // Due Date Picker Trigger
          Text(
            'Batas Pengembalian Baru',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _selectNewDueDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_newDueDate.day} ${_getMonthName(_newDueDate.month)} ${_newDueDate.year}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+$extensionDays Hari',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Tariff input field
          TextFormField(
            controller: _feeController,
            keyboardType: TextInputType.number,
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Tarif Perpanjangan (Biaya Tambahan)',
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
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckout(int extraFee) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: const Color(0xFFC3C5D9).withAlpha(128),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Biaya Perpanjangan',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(extraFee),
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: extraFee > 0 ? _goToPayment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Lanjut Pembayaran',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToPayment() {
    final int extraFee = int.tryParse(_feeController.text.replaceAll('.', '')) ?? 0;
    if (extraFee <= 0) return;

    // Build ReceiptItem representing this extension
    final List<ReceiptItem> extensionReceiptItems = widget.items.map((item) {
      // Pro-rate the extraFee among items for representation
      final double fraction = item.qty / widget.items.fold<int>(0, (sum, i) => sum + i.qty);
      final itemPriceFraction = (extraFee * fraction / item.qty).round();
      return ReceiptItem(
        name: 'Perpanjangan: ${item.name}',
        price: itemPriceFraction,
        quantity: item.qty,
      );
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          quantity: widget.items.fold<int>(0, (sum, i) => sum + i.qty),
          selectedSize: widget.items.first.name,
          tarif: extraFee,
          deposit: 0,
          customerName: widget.customerName,
          invoiceNo: widget.invoiceNo,
          receiptItems: extensionReceiptItems,
          type: 'EXTENSION',
          rentalId: widget.rentalId,
          dueDate: _newDueDate,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }
}

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
