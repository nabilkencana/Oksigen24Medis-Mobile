import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/features/payment/receipt_item.dart';
import 'package:oksigen24medis_mobile2/core/services/printer_service.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:oksigen24medis_mobile2/core/services/pdf_service.dart';

class ReceiptScreen extends StatelessWidget {
  final int quantity;
  final String selectedSize;
  final int tarif;
  final int deposit;
  final int receivedAmount;
  final String paymentMethod;
  final String customerName;
  final String invoiceNo;
  final String? cashierName;

  final List<ReceiptItem>? receiptItems;

  const ReceiptScreen({
    super.key,
    required this.quantity,
    required this.selectedSize,
    required this.tarif,
    required this.deposit,
    required this.receivedAmount,
    required this.paymentMethod,
    required this.customerName,
    required this.invoiceNo,
    this.cashierName,
    this.receiptItems,
  });

  @override
  Widget build(BuildContext context) {
    final int totalTagihan;
    if (receiptItems != null && receiptItems!.isNotEmpty) {
      totalTagihan = receiptItems!.fold(
        0,
        (sum, item) => sum + (item.price * item.quantity),
      );
    } else {
      totalTagihan = (tarif * quantity) + (deposit * quantity);
    }
    final int change = receivedAmount - totalTagihan;
    final formattedChange = _formatCurrency(change > 0 ? change : 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(
              Icons.medical_services_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Oksigen Medis 24 Jam POS',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
          children: [
            const SizedBox(height: 16),
            // ── SUCCESS HEADER ───────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0FBA7C), // Success green circle
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppColors.surface,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pembayaran Berhasil',
                    style: AppTextStyles.h2.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatIndonesianDateTime(DateTime.now()),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── THE RECEIPT CARD ─────────────────────────────────────────────
            _buildReceiptCard(
              totalTagihan: totalTagihan,
              formattedChange: formattedChange,
            ),

            const SizedBox(height: 20),

            // ── INVENTORY BANNER ─────────────────────────────────────────────
            _buildInventoryBanner(),

            const SizedBox(height: 100), // Scroll padding
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(context),
    );
  }

  // ── Receipt Card ───────────────────────────────────────────────────────────
  Widget _buildReceiptCard({
    required int totalTagihan,
    required String formattedChange,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Center(
            child: Column(
              children: [
                Text(
                  'OKSIGEN MEDIS 24 JAM',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dusun Sembon, Sembon, Kec. Karangrejo, Kabupaten Tulungagung, Jawa Timur 66253',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Kasir: ${cashierName ?? "Budi Santoso"}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Dashed Divider line
          _buildDashedLine(),
          const SizedBox(height: 16),

          // Metadata Info
          _buildReceiptRow('No. Invoice', invoiceNo, isBold: true),
          const SizedBox(height: 10),
          _buildReceiptRow('Pelanggan', customerName, isBold: true),

          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Items listing
          if (receiptItems != null && receiptItems!.isNotEmpty)
            ...receiptItems!.map((item) {
              final String subtitleText = item.subtitle != null
                  ? '@ Rp ${_formatCurrency(item.price)} • ${item.subtitle}'
                  : '@ Rp ${_formatCurrency(item.price)}';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.quantity}x ${item.name}',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleText,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Rp ${_formatCurrency(item.price * item.quantity)}',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            })
          else ...[
            _buildItemRow(
              'Sewa Tabung $selectedSize',
              tarif * quantity,
              quantity,
            ),
            if (deposit > 0) ...[
              const SizedBox(height: 12),
              _buildItemRow('Deposit Jaminan', deposit * quantity, quantity),
            ],
          ],

          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Subtotals and details
          _buildReceiptRow('Subtotal', 'Rp ${_formatCurrency(totalTagihan)}'),
          const SizedBox(height: 10),
          _buildReceiptRow('Metode Pembayaran', paymentMethod),
          const SizedBox(height: 12),
          // Total bold row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                'Rp ${_formatCurrency(totalTagihan)}',
                style: AppTextStyles.priceText.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Cash change detail
          _buildReceiptRow('Diterima', 'Rp ${_formatCurrency(receivedAmount)}'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kembali',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Rp $formattedChange',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Terima kasih atas kepercayaan Anda',
              style: AppTextStyles.caption.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              height: 64,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  // ── Inventory Banner ───────────────────────────────────────────────────────
  Widget _buildInventoryBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFECEBFF), // Soft purple/blue container
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            'INVENTORY AUTO-UPDATED',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Action Bar ──────────────────────────────────────────────────────
  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16.0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final printer = PrinterService();

                // Define print action closure
                Future<void> doPrint() async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mengirim data ke printer...'),
                      backgroundColor: AppColors.primary,
                    ),
                  );

                  // Calculate totals locally
                  final int totalTagihan;
                  if (receiptItems != null && receiptItems!.isNotEmpty) {
                    totalTagihan = receiptItems!.fold(
                      0,
                      (sum, item) => sum + (item.price * item.quantity),
                    );
                  } else {
                    totalTagihan = (tarif * quantity) + (deposit * quantity);
                  }
                  final int change = receivedAmount - totalTagihan;

                  // Build a list of receipt items (ensure it is not empty)
                  final List<ReceiptItem> itemsToPrint = [];
                  if (receiptItems != null && receiptItems!.isNotEmpty) {
                    itemsToPrint.addAll(receiptItems!);
                  } else {
                    itemsToPrint.add(ReceiptItem(
                      name: 'Sewa Tabung $selectedSize',
                      price: tarif,
                      quantity: quantity,
                    ));
                    if (deposit > 0) {
                      itemsToPrint.add(ReceiptItem(
                        name: 'Deposit Jaminan',
                        price: deposit,
                        quantity: quantity,
                      ));
                    }
                  }

                  final success = await printer.printReceipt(
                    invoiceNo: invoiceNo,
                    customerName: customerName,
                    cashierName: cashierName ?? 'Budi Santoso',
                    receiptItems: itemsToPrint,
                    paymentMethod: paymentMethod,
                    totalTagihan: totalTagihan,
                    receivedAmount: receivedAmount,
                    change: change,
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
                  // Direct user to connect printer first in-place
                  _showPrinterScanDialog(context, () {
                    // Once connected, auto trigger print
                    doPrint();
                  });
                } else {
                  await doPrint();
                }
              },
              icon: const Icon(Icons.print, size: 20),
              label: const Text('Cetak Struk'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF434656), // neutral dark
                side: const BorderSide(color: Color(0xFFC3C5D9)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final pdfService = PdfService();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Menyiapkan file PDF...'),
                    backgroundColor: AppColors.primary,
                  ),
                );

                // Calculate totals locally
                final int totalTagihan;
                if (receiptItems != null && receiptItems!.isNotEmpty) {
                  totalTagihan = receiptItems!.fold(
                    0,
                    (sum, item) => sum + (item.price * item.quantity),
                  );
                } else {
                  totalTagihan = (tarif * quantity) + (deposit * quantity);
                }
                final int change = receivedAmount - totalTagihan;

                // Build a list of receipt items (ensure it is not empty)
                final List<ReceiptItem> itemsToPrint = [];
                if (receiptItems != null && receiptItems!.isNotEmpty) {
                  itemsToPrint.addAll(receiptItems!);
                } else {
                  itemsToPrint.add(ReceiptItem(
                    name: 'Sewa Tabung $selectedSize',
                    price: tarif,
                    quantity: quantity,
                  ));
                  if (deposit > 0) {
                    itemsToPrint.add(ReceiptItem(
                      name: 'Deposit Jaminan',
                      price: deposit,
                      quantity: quantity,
                    ));
                  }
                }

                await pdfService.shareInvoicePdf(
                  invoiceNo: invoiceNo,
                  customerName: customerName,
                  cashierName: cashierName ?? 'Budi Santoso',
                  receiptItems: itemsToPrint,
                  paymentMethod: paymentMethod,
                  totalTagihan: totalTagihan,
                  receivedAmount: receivedAmount,
                  change: change,
                );
              },
              icon: const Icon(Icons.share_outlined, size: 20),
              label: const Text('Bagikan PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.home_outlined, size: 20),
              label: const Text('Kembali ke Beranda'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────
  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(String name, int amount, int qty) {
    final int unitPrice = qty > 0 ? (amount ~/ qty) : amount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${qty}x $name',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '@ Rp ${_formatCurrency(unitPrice)}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        Text(
          'Rp ${_formatCurrency(amount)}',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
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

  String _formatIndonesianDateTime(DateTime dt) {
    const days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    
    final dayName = days[dt.weekday % 7];
    final day = dt.day;
    final monthName = months[dt.month - 1];
    final year = dt.year;
    
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    
    return '$dayName, $day $monthName $year • $hour:$minute WIB';
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
