import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/features/return/return_form_screen.dart';
import 'package:oksigen24medis_mobile2/features/rental/rental_extension_form_screen.dart';
import 'package:oksigen24medis_mobile2/core/services/printer_service.dart';
import 'package:oksigen24medis_mobile2/core/services/pdf_service.dart';
import 'package:oksigen24medis_mobile2/features/payment/receipt_item.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class TransactionDetailScreen extends StatelessWidget {
  final String? rentalId;
  final String invoiceNo;
  final String customerName;
  final String customerType;
  final String dateStr;
  final String status;
  final String method;
  final int totalTagihan;
  final int deposit;
  final int sewaDays;
  final String returnDeadline;
  final List<DetailItem> items;

  const TransactionDetailScreen({
    super.key,
    this.rentalId,
    this.invoiceNo = 'INV-20260714-01',
    this.customerName = 'RS. Medika Utama',
    this.customerType = 'Penyewaan Instansi',
    this.dateStr = '14 Juli 2026, 10:45 WIB',
    this.status = 'BERJALAN',
    this.method = 'Transfer Bank',
    this.totalTagihan = 500000,
    this.deposit = 2000000,
    this.sewaDays = 7,
    this.returnDeadline = '21 Juli 2026',
    this.items = const [
      DetailItem(name: 'Tabung Oksigen 6m3', qty: 5, unitPrice: 75000),
      DetailItem(name: 'Regulator Medis', qty: 5, unitPrice: 25000),
    ],
  });

  @override
  Widget build(BuildContext context) {
    final String rawStatus = status.toUpperCase();
    final String statusText;
    final Color badgeBg;
    final Color badgeText;

    if (rawStatus == 'RETURNED' || rawStatus == 'SELESAI') {
      statusText = 'SELESAI';
      badgeBg = const Color(0xFFE6F4EA); // Light success green
      badgeText = AppColors.success;
    } else if (rawStatus == 'RENTING' || rawStatus == 'BERJALAN') {
      statusText = 'BERJALAN';
      badgeBg = const Color(0xFFFEF3D6); // Light warning orange
      badgeText = AppColors.warning;
    } else if (rawStatus == 'OVERDUE' || rawStatus == 'TERLAMBAT') {
      statusText = 'TERLAMBAT';
      badgeBg = const Color(0xFFFCE8E6); // Light error red
      badgeText = AppColors.error;
    } else {
      statusText = rawStatus;
      badgeBg = const Color(0xFFF1F5F9);
      badgeText = AppColors.textSecondary;
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
          'Detail Transaksi',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.share_outlined,
              color: AppColors.primary,
            ),
            tooltip: 'Bagikan PDF',
            onPressed: () async {
              final pdfService = PdfService();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Menyiapkan file PDF...'),
                  backgroundColor: AppColors.primary,
                ),
              );

              final receiptItems = items.map((e) => ReceiptItem(
                name: e.name,
                price: e.unitPrice,
                quantity: e.qty,
              )).toList();

              // Calculate change safely based on received amount if available, otherwise 0
              final received = totalTagihan;
              final change = 0;

              await pdfService.shareInvoicePdf(
                invoiceNo: invoiceNo,
                customerName: customerName,
                cashierName: 'Kasir',
                receiptItems: receiptItems,
                paymentMethod: method,
                totalTagihan: totalTagihan,
                receivedAmount: received,
                change: change,
              );
            },
          ),
          const SizedBox(width: 8),
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
          children: [
            // ── COMPONENT 1: HEADER & STATUS (CARD 1) ────────────────────────
            _buildHeaderStatusCard(statusText, badgeBg, badgeText),

            const SizedBox(height: 16),

            // ── COMPONENT 2: DATA PELANGGAN (CARD 2) ─────────────────────────
            _buildCustomerCard(),

            const SizedBox(height: 16),

            // ── COMPONENT 3: DETAIL ITEM & DURASI (CARD 3) ────────────────────
            _buildOrderDetailsCard(),

            const SizedBox(height: 16),

            // ── COMPONENT 4: RINCIAN PEMBAYARAN (CARD 4) ──────────────────────
            _buildPaymentDepositCard(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(context),
    );
  }

  // ── Header & Status Card ───────────────────────────────────────────────────
  Widget _buildHeaderStatusCard(
    String statusText,
    Color badgeBg,
    Color badgeText,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: AppTextStyles.caption.copyWith(
                color: badgeText,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            invoiceNo,
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateStr,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Customer Card ──────────────────────────────────────────────────────────
  Widget _buildCustomerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'INFORMASI PELANGGAN',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            customerName,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            customerType,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Order Details Card ─────────────────────────────────────────────────────
  Widget _buildOrderDetailsCard() {
    final int subtotal = items.fold(
      0,
      (sum, item) => sum + (item.unitPrice * item.qty),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'DETAIL PESANAN',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Items listing
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.qty}x ${item.name}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@ Rp ${_formatCurrency(item.unitPrice)}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Rp ${_formatCurrency(item.unitPrice * item.qty)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          _buildDashedLine(),
          const SizedBox(height: 12),
          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Rp ${_formatCurrency(subtotal)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sewaDays > 0) ...[
            const SizedBox(height: 16),
            // Rental duration banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withAlpha(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Durasi Sewa',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$sewaDays Hari',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '(Batas: $returnDeadline)',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Payment & Deposit Card ─────────────────────────────────────────────────
  Widget _buildPaymentDepositCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payment_outlined,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'PEMBAYARAN & DEPOSIT',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Metode', method, isBold: true),
          const SizedBox(height: 10),
          _buildInfoRow(
            'Total Tagihan',
            'Rp ${_formatCurrency(totalTagihan)}',
            isBold: true,
          ),
          if (sewaDays > 0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Deposit',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                Text(
                  'Rp ${_formatCurrency(deposit)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Bottom Action Bar ──────────────────────────────────────────────────────
  Widget _buildBottomActionBar(BuildContext context) {
    final String rawStatus = status.toUpperCase();
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
          child: Builder(
            builder: (context) {
              final bool showThreeButtons = sewaDays > 0 && rawStatus != 'RETURNED' && rawStatus != 'SELESAI';

              // Printer trigger helper
              Future<void> triggerPrint() async {
                final printer = PrinterService();
                Future<void> doPrint() async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mengirim data to printer...'),
                      backgroundColor: AppColors.primary,
                    ),
                  );

                  final receiptItems = items.map((e) => ReceiptItem(
                    name: e.name,
                    price: e.unitPrice,
                    quantity: e.qty,
                  )).toList();

                  final success = await printer.printReceipt(
                    invoiceNo: invoiceNo,
                    customerName: customerName,
                    cashierName: 'Kasir',
                    receiptItems: receiptItems,
                    paymentMethod: method,
                    totalTagihan: totalTagihan,
                    receivedAmount: totalTagihan,
                    change: 0,
                  );

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Struk berhasil dicetak' : 'Gagal mencetak struk. Periksa status printer.'),
                      backgroundColor: success ? AppColors.success : AppColors.error,
                    ),
                  );
                }

                final connected = await printer.isConnected();
                if (!context.mounted) return;

                if (!connected) {
                  _showPrinterScanDialog(context, () {
                    doPrint();
                  });
                } else {
                  await doPrint();
                }
              }

              if (showThreeButtons) {
                return Row(
                  children: [
                    // 1. CETAK STRUK BUTTON (Vertical)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: triggerPrint,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size.fromHeight(60),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.print, size: 20),
                            SizedBox(height: 4),
                            Text(
                              'Cetak Struk',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 2. PERPANJANG BUTTON (Vertical)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => RentalExtensionFormScreen(
                                rentalId: rentalId ?? '',
                                invoiceNo: invoiceNo,
                                customerName: customerName,
                                returnDeadline: returnDeadline,
                                items: items,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size.fromHeight(60),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 20),
                            SizedBox(height: 4),
                            Text(
                              'Perpanjang',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 3. KEMBALI BUTTON (Vertical)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ReturnFormScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.surface,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size.fromHeight(60),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_return_outlined, size: 20),
                            SizedBox(height: 4),
                            Text(
                              'Kembali',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Only 1 Button: Cetak Struk (Horizontal)
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: triggerPrint,
                    icon: const Icon(Icons.print, size: 20),
                    label: const Text(
                      'Cetak Struk',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // ── Reusable info row ──────────────────────────────────────────────────────
  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFC3C5D9)),
              ),
            );
          }),
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

  void _showPrinterScanDialog(BuildContext context, VoidCallback onConnected) {
    final printer = PrinterService();
    Future<List<BluetoothInfo>>? devicesFuture;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Lazy load the future on first render
            devicesFuture ??= printer.getBluetoothDevices();

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: FutureBuilder<List<BluetoothInfo>>(
                  future: devicesFuture,
                  builder: (context, snapshot) {
                    final isLoading = snapshot.connectionState == ConnectionState.waiting;
                    final devices = snapshot.data ?? [];

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6EEFF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.print_rounded,
                                    color: Color(0xFF0055FF),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Printer Bluetooth',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        if (isLoading) ...[
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 36.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ScanningPulse(),
                                  SizedBox(height: 24),
                                  Text(
                                    'Memindai printer Bluetooth...',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Pastikan Bluetooth perangkat Anda aktif',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else if (devices.isEmpty) ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFFF1F2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.bluetooth_disabled_rounded,
                                      color: Color(0xFFF43F5E),
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Printer Tidak Ditemukan',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Text(
                                      'Pastikan printer thermal Bluetooth Anda sudah dinyalakan dan berpasangan (paired) di pengaturan Bluetooth HP Anda.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Pilih perangkat printer berpasangan:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: devices.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final d = devices[index];
                                return InkWell(
                                  onTap: () async {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Menghubungkan ke ${d.name}...'),
                                        backgroundColor: const Color(0xFF0055FF),
                                      ),
                                    );
                                    final success = await printer.connect(d.macAdress);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(success
                                              ? 'Berhasil terhubung ke ${d.name}'
                                              : 'Gagal terhubung ke ${d.name}'),
                                          backgroundColor: success
                                              ? const Color(0xFF00A67E)
                                              : const Color(0xFFEF4444),
                                        ),
                                      );
                                      if (success) {
                                        onConnected();
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x02000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE6EEFF),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.print_rounded,
                                            color: Color(0xFF0055FF),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                d.name.isNotEmpty ? d.name : 'Printer Tanpa Nama',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                d.macAdress,
                                                style: const TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 11,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE6EEFF),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Text(
                                            'Pilih',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0055FF),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),

                        // Actions Row (Batal / Pindai Ulang)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Batal',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0055FF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text(
                                  'Pindai Ulang',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        setModalState(() {
                                          devicesFuture = printer.getBluetoothDevices();
                                        });
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class DetailItem {
  final String name;
  final int qty;
  final int unitPrice;

  const DetailItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
  });
}

// ── PULSING SEARCH ANIMATION FOR BLUETOOTH DIALOG ─────────────────────────────
class _ScanningPulse extends StatefulWidget {
  const _ScanningPulse();

  @override
  State<_ScanningPulse> createState() => _ScanningPulseState();
}

class _ScanningPulseState extends State<_ScanningPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse circle
              Container(
                width: 60 + 100 * _controller.value,
                height: 60 + 100 * _controller.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0055FF).withOpacity(0.2 * (1.0 - _controller.value)),
                ),
              ),
              // Middle pulse circle
              Container(
                width: 60 + 50 * _controller.value,
                height: 60 + 50 * _controller.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0055FF).withOpacity(0.4 * (1.0 - _controller.value)),
                ),
              ),
              // Glowing center icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0055FF),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x330055FF),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bluetooth_searching_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
