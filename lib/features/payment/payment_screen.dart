import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/core/state/transaction_provider.dart';
import 'package:oksigen24medis_mobile2/core/state/auth_provider.dart';
import 'package:oksigen24medis_mobile2/core/services/api_service.dart';
import 'package:oksigen24medis_mobile2/features/payment/receipt_screen.dart';
import 'package:oksigen24medis_mobile2/features/payment/receipt_item.dart';
import 'package:provider/provider.dart';

class PaymentScreen extends StatefulWidget {
  final int quantity;
  final String selectedSize;
  final int tarif;
  final int deposit;
  final String customerName;
  final String invoiceNo;
  final List<ReceiptItem>? receiptItems;

  // dynamic integration properties
  final String type; // 'RENTAL', 'SALE', 'REFILL', 'EXTENSION'
  final String? customerId;
  final String? rentalId;
  final DateTime? dueDate;
  final List<String>? cylinderIds;
  final List<Map<String, dynamic>>? items;

  const PaymentScreen({
    super.key,
    this.quantity = 1,
    this.selectedSize = '1 m3',
    this.tarif = 50000,
    this.deposit = 500000,
    this.customerName = 'Klinik Sehat Bersama',
    this.invoiceNo = 'INV-20260714-02',
    this.receiptItems,
    this.type = 'RENTAL',
    this.customerId,
    this.rentalId,
    this.dueDate,
    this.cylinderIds,
    this.items,
  });

  int get totalPrice {
    if (receiptItems != null && receiptItems!.isNotEmpty) {
      return receiptItems!.fold(0, (sum, item) => sum + (item.price * item.quantity));
    }
    return (tarif + deposit) * quantity;
  }

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'Tunai';
  final TextEditingController _receivedController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _methods = [
    {'name': 'Tunai', 'icon': Icons.payments_outlined},
    {'name': 'QRIS', 'icon': Icons.qr_code_2_rounded},
    {'name': 'Transfer', 'icon': Icons.account_balance_outlined},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.totalPrice == 150000) {
      _receivedController.text = '200.000';
    } else {
      _receivedController.text = _formatCurrency(widget.totalPrice);
    }
    _receivedController.addListener(_onReceivedChanged);
  }

  @override
  void dispose() {
    _receivedController.removeListener(_onReceivedChanged);
    _receivedController.dispose();
    super.dispose();
  }

  void _onReceivedChanged() {
    setState(() {});
  }

  int get _receivedAmount {
    return int.tryParse(_receivedController.text.replaceAll('.', '')) ?? 0;
  }

  Future<void> _handlePaymentProcess(TransactionProvider provider) async {
    if (_selectedMethod == 'Tunai' && _receivedAmount < widget.totalPrice) {
      final int deficit = widget.totalPrice - _receivedAmount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pembayaran kurang Rp ${_formatCurrency(deficit)}. Silakan sesuaikan nominal uang diterima.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String dynamicInvoiceNo = widget.invoiceNo;

      if (widget.type == 'RENTAL') {
        String notesPayload = 'Customer checkout from mobile client';
        if (widget.receiptItems != null && widget.receiptItems!.isNotEmpty) {
          try {
            final mapped = widget.receiptItems!.map((item) => {
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
              'subtitle': item.subtitle,
            }).toList();
            notesPayload = jsonEncode(mapped);
          } catch (e) {
            debugPrint('Error serializing receiptItems: $e');
          }
        }

        // Submit Rental API
        final result = await provider.submitRental(
          customerId: widget.customerId ?? 'cust-uuid',
          dueDate: widget.dueDate ?? DateTime.now().add(const Duration(days: 7)),
          amountPaid: _selectedMethod == 'Tunai' ? _receivedAmount.toDouble() : widget.totalPrice.toDouble(),
          cylinderIds: widget.cylinderIds ?? [],
          notes: notesPayload,
          totalAmount: widget.totalPrice.toDouble(),
        );
        if (result['invoiceNo'] != null) {
          dynamicInvoiceNo = result['invoiceNo'];
        }
      } else if (widget.type == 'SALE') {
        // Submit Sale API
        final result = await provider.submitSale(
          customerId: widget.customerId,
          amountPaid: _selectedMethod == 'Tunai' ? _receivedAmount.toDouble() : widget.totalPrice.toDouble(),
          paymentMethod: _selectedMethod.toUpperCase(),
          items: widget.items ?? [],
        );
        if (result['invoiceNo'] != null) {
          dynamicInvoiceNo = result['invoiceNo'];
        }
      } else if (widget.type == 'REFILL') {
        // Submit Customer Refill API
        final result = await provider.submitCustomerRefill(
          customerId: widget.customerId,
          amountPaid: _selectedMethod == 'Tunai' ? _receivedAmount.toDouble() : widget.totalPrice.toDouble(),
          paymentMethod: _selectedMethod.toUpperCase(),
          items: widget.items ?? [],
          notes: 'Customer refill checkout from mobile client',
        );
        if (result['invoiceNo'] != null) {
          dynamicInvoiceNo = result['invoiceNo'];
        }
      } else if (widget.type == 'EXTENSION') {
        // Submit Extension API
        final result = await provider.extendRental(
          rentalId: widget.rentalId ?? '',
          newDueDate: widget.dueDate ?? DateTime.now(),
          amountPaid: _selectedMethod == 'Tunai' ? _receivedAmount.toDouble() : widget.totalPrice.toDouble(),
        );
        if (result['invoiceNo'] != null) {
          dynamicInvoiceNo = result['invoiceNo'];
        }
      }

      if (mounted) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final cashierName = auth.currentUser?['fullName'] as String?;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              quantity: widget.quantity,
              selectedSize: widget.selectedSize,
              tarif: widget.tarif,
              deposit: widget.deposit,
              receivedAmount: _selectedMethod == 'Tunai' ? _receivedAmount : widget.totalPrice,
              paymentMethod: _selectedMethod,
              customerName: widget.customerName,
              invoiceNo: dynamicInvoiceNo,
              cashierName: cashierName,
              receiptItems: widget.receiptItems,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Gagal memproses transaksi di server.';
        if (e is ApiException) {
          errorMsg = e.messages.isNotEmpty ? e.messages.first : e.message;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
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
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);

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
          'Pembayaran',
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
            // ── ORDER SUMMARY CARD ───────────────────────────────────────────
            _buildOrderSummaryCard(),

            const SizedBox(height: 24),

            // ── PAYMENT METHOD GRID ──────────────────────────────────────────
            Text(
              'Metode Pembayaran',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF434656), // grey title
              ),
            ),
            const SizedBox(height: 12),
            _buildPaymentMethodGrid(),

            const SizedBox(height: 24),

            // ── PAYMENT DETAILS (ONLY FOR CASH) ──────────────────────────────
            if (_selectedMethod == 'Tunai') ...[
              Text(
                'Detail Pembayaran',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF434656), // grey title
                ),
              ),
              const SizedBox(height: 12),
              _buildCashInputDetails(),
            ] else
              _buildNonCashDetails(),

            const SizedBox(
              height: 100,
            ), // Extra space to scroll past bottom bar
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(transactionProvider),
    );
  }

  // ── Order Summary Card ─────────────────────────────────────────────────────
  Widget _buildOrderSummaryCard() {
    final formattedTotal = _formatCurrency(widget.totalPrice);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
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
                'Ringkasan Pesanan',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF434656),
                ),
              ),
              Text(
                widget.invoiceNo,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Pelanggan: ${widget.customerName}',
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: Color(0xFFECEFF5), height: 1),
          ),
          if (widget.receiptItems != null && widget.receiptItems!.isNotEmpty)
            ...widget.receiptItems!.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity}x ${item.name}',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    Text(
                      _formatCurrency(item.price * item.quantity),
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              );
            })
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.quantity}x Tabung Oksigen ${widget.selectedSize}',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                ),
                Text(
                  _formatCurrency(widget.tarif * widget.quantity),
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Deposit Tabung',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  _formatCurrency(widget.deposit * widget.quantity),
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: Color(0xFFECEFF5), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Tagihan',
                style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Text(
                'Rp $formattedTotal',
                style: AppTextStyles.priceText.copyWith(fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Payment Method Grid ────────────────────────────────────────────────────
  Widget _buildPaymentMethodGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: _methods.length,
      itemBuilder: (context, index) {
        final m = _methods[index];
        final isSelected = _selectedMethod == m['name'];

        return InkWell(
          onTap: () {
            setState(() {
              _selectedMethod = m['name'];
              if (_selectedMethod != 'Tunai') {
                _receivedController.text = _formatCurrency(widget.totalPrice);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  m['icon'],
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  m['name'],
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Cash Details ───────────────────────────────────────────────────────────
  Widget _buildCashInputDetails() {
    final int change = _receivedAmount - widget.totalPrice;
    final formattedChange = change >= 0 ? _formatCurrency(change) : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _receivedController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
            inputFormatters: [CurrencyInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Uang Diterima',
              prefixText: 'Rp ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kembalian',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                'Rp $formattedChange',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: change >= 0 ? AppColors.success : AppColors.error,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNonCashDetails() {
    final isTransfer = _selectedMethod == 'Transfer';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          if (isTransfer) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F3057), Color(0xFF00587A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x330F3057),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BANK MANDIRI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Icon(Icons.account_balance_wallet_rounded, color: Colors.white.withAlpha(204), size: 20),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Nomor Rekening',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '1710010751439',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: '1710010751439'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nomor rekening berhasil disalin'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nama Penerima',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'AVIP PRAMONO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/qris.png',
                width: 260,
                fit: BoxFit.contain,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            isTransfer
                ? 'Silakan transfer ke rekening Bank Mandiri di atas'
                : 'Silakan scan QR Code di atas untuk pembayaran $_selectedMethod',
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            isTransfer
                ? 'Konfirmasi manual ke admin setelah melakukan transfer'
                : 'Konfirmasi pembayaran otomatis setelah dana masuk',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Bottom Action Bar ──────────────────────────────────────────────────────
  Widget _buildBottomActionBar(TransactionProvider provider) {
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
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : () => _handlePaymentProcess(provider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _isSubmitting ? 'Memproses Transaksi...' : 'Proses Pembayaran',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward, size: 20),
              ],
            ),
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
