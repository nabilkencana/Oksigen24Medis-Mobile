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
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return FutureBuilder<List<BluetoothInfo>>(
              future: printer.getBluetoothDevices(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: const Text('Cari Printer Bluetooth'),
                    content: const Row(
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text('Sedang memindai perangkat...'),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ],
                  );
                }

                final devices = snapshot.data ?? [];
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: const Text('Pilih Printer Bluetooth'),
                  content: devices.isEmpty
                      ? const Text('Tidak ada perangkat printer bluetooth yang berpasangan. Hubungkan printer di pengaturan Bluetooth HP Anda terlebih dahulu.')
                      : SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                              final d = devices[index];
                              return ListTile(
                                leading: const Icon(Icons.print, color: AppColors.primary),
                                title: Text(d.name),
                                subtitle: Text(d.macAdress),
                                onTap: () async {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Menghubungkan ke ${d.name}...'),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );
                                  final success = await printer.connect(d.macAdress);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success 
                                            ? 'Berhasil terhubung ke ${d.name}' 
                                            : 'Gagal terhubung ke ${d.name}'),
                                        backgroundColor: success ? AppColors.success : AppColors.error,
                                      ),
                                    );
                                    if (success) {
                                      onConnected();
                                    }
                                  }
                                },
                              );
                            },
                          ),
                        ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ],
                );
              },
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
