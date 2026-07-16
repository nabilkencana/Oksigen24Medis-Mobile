import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/core/state/transaction_provider.dart';
import 'package:oksigen24medis_mobile2/core/services/api_service.dart';
import 'package:provider/provider.dart';

class ReturnFormScreen extends StatefulWidget {
  const ReturnFormScreen({super.key});

  @override
  State<ReturnFormScreen> createState() => _ReturnFormScreenState();
}

class _ReturnFormScreenState extends State<ReturnFormScreen> {
  final TextEditingController _fineNoteController = TextEditingController();
  final TextEditingController _fineAmountController = TextEditingController(text: '0');
  Map<String, dynamic>? _selectedRental;
  final Set<String> _selectedCylinderIds = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fineAmountController.addListener(_onAmountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(context, listen: false).fetchTransactions();
    });
  }

  @override
  void dispose() {
    _fineAmountController.removeListener(_onAmountChanged);
    _fineAmountController.dispose();
    _fineNoteController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    setState(() {});
  }

  // Format currency manually
  String _formatCurrency(int amount) {
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

  // Calculate late return days count
  int _calculateLateDays(String dueDateStr) {
    try {
      final dueDate = DateTime.parse(dueDateStr);
      final today = DateTime.now();
      final diff = today.difference(dueDate).inDays;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildDialogRow(
    String label,
    String value, {
    Color? valueColor,
    FontWeight? valueWeight,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: valueWeight ?? FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _processReturnSubmit(TransactionProvider provider) async {
    if (_selectedRental == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih invoice sewa terlebih dahulu'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedCylinderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu tabung yang dikembalikan'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await provider.submitReturn(
        rentalId: _selectedRental!['id'],
        cylinderIds: _selectedCylinderIds.toList(),
      );

      if (mounted) {
        final custName = _selectedRental?['customer']?['name'] ?? 'Pelanggan';
        final invNo = _selectedRental?['invoiceNo'] ?? '-';
        final totalReturned = _selectedCylinderIds.length;
        
        final int fineAmount = int.tryParse(_fineAmountController.text.replaceAll('.', '')) ?? 0;
        final double rawDeposit = double.tryParse(_selectedRental?['totalAmount']?.toString() ?? '200000') ?? 200000;
        final int initialDeposit = rawDeposit.round();
        final int refundAmount = initialDeposit - fineAmount;
        final int finalRefund = refundAmount > 0 ? refundAmount : 0;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 10,
              backgroundColor: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Double ring checkmark icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Pengembalian Berhasil!',
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Transaksi pengembalian tabung telah berhasil diproses & disimpan.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 16),
                    // Transaction details summary card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildDialogRow('Pelanggan', custName),
                          const SizedBox(height: 10),
                          _buildDialogRow('No. Invoice', invNo),
                          const SizedBox(height: 10),
                          _buildDialogRow('Item Kembali', '$totalReturned Item'),
                          const SizedBox(height: 10),
                          _buildDialogRow(
                            'Pengembalian Dana',
                            _formatCurrency(finalRefund),
                            valueColor: finalRefund > 0 ? AppColors.success : AppColors.textPrimary,
                            valueWeight: FontWeight.w700,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Action button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Pop ReturnFormScreen back to Home
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Kembali ke Beranda',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Gagal memproses pengembalian tabung.';
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
    final txProvider = Provider.of<TransactionProvider>(context);

    // Filter active/non-returned rentals only
    final activeRentals = txProvider.rentals
        .where((r) => r['status'] == 'RENTING' || r['status'] == 'OVERDUE')
        .toList();

    final int fineAmount = int.tryParse(_fineAmountController.text.replaceAll('.', '')) ?? 0;
    // Mock initial deposit based on rental size or totalAmount
    final double rawDeposit = double.tryParse(_selectedRental?['totalAmount']?.toString() ?? '200000') ?? 200000;
    final int initialDeposit = rawDeposit.round();
    final int refundAmount = initialDeposit - fineAmount;
    final int finalRefund = refundAmount > 0 ? refundAmount : 0;

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
          'Pengembalian Tabung',
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
            // ── COMPONENT 1: CARI TRANSAKSI SEWA ─────────────────────────────
            _buildSearchAndInvoiceCard(activeRentals),

            const SizedBox(height: 24),

            if (_selectedRental != null) ...[
              // Section Title: Item yang Dikembalikan
              Text(
                'Pilih Tabung yang Dikembalikan',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF434656),
                ),
              ),
              const SizedBox(height: 12),
              // ── COMPONENT 2: ITEM DIKEMBALIKAN ─────────────────────────────
              _buildItemsCard(),

              const SizedBox(height: 24),

              // Section Title: Denda & Potongan (Opsional)
              Text(
                'Denda & Potongan (Opsional)',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF434656),
                ),
              ),
              const SizedBox(height: 12),
              // ── COMPONENT 3: DENDA & POTONGAN ──────────────────────────────
              _buildFinesCard(),

              const SizedBox(height: 24),

              // Section Title: Rincian Dana
              Text(
                'Rincian Dana',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF434656),
                ),
              ),
              const SizedBox(height: 12),
              // ── COMPONENT 4: RINCIAN PENGEMBALIAN DANA ─────────────────────
              _buildRefundDetailsCard(initialDeposit, fineAmount, finalRefund),
            ],

            const SizedBox(height: 100), // Scroll padding
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(txProvider, finalRefund),
    );
  }

  // ── Search & Invoice Card ──────────────────────────────────────────────────
  Widget _buildSearchAndInvoiceCard(List<dynamic> activeRentals) {
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
              const Icon(Icons.receipt_long_outlined,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Pilih Invoice Sewa',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Tappable picker button
          GestureDetector(
            onTap: () => _showInvoicePicker(activeRentals),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedRental != null
                      ? AppColors.primary.withAlpha(80)
                      : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _selectedRental == null
                        ? Text(
                            'Ketuk untuk mencari invoice sewa...',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedRental!['invoiceNo'] ?? '-',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedRental!['customer']?['name'] ??
                                    'Pelanggan',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (_selectedRental != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRental = null;
                          _selectedCylinderIds.clear();
                          _fineNoteController.clear();
                          _fineAmountController.text = '0';
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.close,
                            size: 18, color: AppColors.textSecondary),
                      ),
                    )
                  else
                    const Icon(Icons.expand_more,
                        size: 20, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          if (_selectedRental != null) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 14),
            // Active Invoice Detail Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.primary.withAlpha(50)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedRental!['invoiceNo'] ?? '',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedRental!['customer']?['name'] ??
                                  '-',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildLateBadge(
                          _selectedRental!['dueDate'] ?? ''),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Batas Kembali: ${(_selectedRental!['dueDate'] ?? '').toString().length >= 10 ? (_selectedRental!['dueDate']).toString().substring(0, 10) : '-'}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  // Cylinder summary
                  ..._buildCylinderSummary(
                      _selectedRental!['items'] ?? []),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getGroupedChips(List<dynamic> openItems) {
    final Map<String, int> cylinderGroups = {}; // size -> count
    int accessoryCount = 0;

    for (final i in openItems) {
      final cyl = i['cylinder'] ?? {};
      final serial = (cyl['serialNumber'] ?? '').toString().toUpperCase();
      final size = (cyl['size'] ?? '').toString().toUpperCase();

      final isAccessory = serial.startsWith('REG-') ||
          serial.startsWith('TRL-') ||
          serial.startsWith('ACC-') ||
          size == 'PCS';

      if (isAccessory) {
        accessoryCount++;
      } else {
        final displaySize = cyl['size']?.toString() ?? '?';
        cylinderGroups[displaySize] = (cylinderGroups[displaySize] ?? 0) + 1;
      }
    }

    final List<Map<String, dynamic>> groups = [];
    cylinderGroups.forEach((size, count) {
      groups.add({
        'label': '$count× Tabung $size',
        'isAccessory': false,
      });
    });
    if (accessoryCount > 0) {
      groups.add({
        'label': '$accessoryCount× Aksesoris',
        'isAccessory': true,
      });
    }
    return groups;
  }

  List<Widget> _buildCylinderSummary(List<dynamic> items) {
    final open = items.where((i) => i['returnedAt'] == null).toList();
    if (open.isEmpty) return [];

    final chips = _getGroupedChips(open);

    return [
      const SizedBox(height: 10),
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: chips.map((c) {
          final isAcc = c['isAccessory'] as bool;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAcc
                  ? AppColors.warningLight
                  : AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAcc
                    ? AppColors.warning.withAlpha(80)
                    : AppColors.primary.withAlpha(40),
              ),
            ),
            child: Text(
              c['label'] as String,
              style: AppTextStyles.caption.copyWith(
                color: isAcc ? AppColors.warning : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }

  void _showInvoicePicker(List<dynamic> activeRentals) {
    final searchCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final query = searchCtrl.text.toLowerCase();
            final filtered = activeRentals.where((r) {
              final inv =
                  (r['invoiceNo'] ?? '').toString().toLowerCase();
              final name = (r['customer']?['name'] ?? '')
                  .toString()
                  .toLowerCase();
              final phone = (r['customer']?['phone'] ?? '')
                  .toString()
                  .toLowerCase();
              return inv.contains(query) ||
                  name.contains(query) ||
                  phone.contains(query);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.82,
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pilih Invoice Sewa',
                                style: AppTextStyles.h3.copyWith(
                                    fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${activeRentals.length} invoice aktif tersedia',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                            ],
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
                          hintText:
                              'Cari no. invoice, nama pelanggan, atau HP...',
                          prefixIcon:
                              const Icon(Icons.search, size: 20),
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
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.receipt_outlined,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    activeRentals.isEmpty
                                        ? 'Tidak ada sewa aktif saat ini'
                                        : 'Invoice tidak ditemukan',
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(
                                            color:
                                                AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final r = filtered[i];
                                final inv =
                                    r['invoiceNo']?.toString() ?? '-';
                                final name = r['customer']?['name']
                                        ?.toString() ??
                                    'Pelanggan';
                                final phone =
                                    r['customer']?['phone']?.toString() ??
                                        '';
                                final dueDate =
                                    r['dueDate']?.toString() ?? '';
                                final lateDays = dueDate.length >= 10
                                    ? _calculateLateDays(dueDate)
                                    : 0;
                                final isSelected = _selectedRental?['id']
                                        ?.toString() ==
                                    r['id']?.toString();

                                // Build cylinder summary for this rental
                                final items =
                                    (r['items'] as List?) ?? [];
                                final openItems = items
                                    .where(
                                        (i) => i['returnedAt'] == null)
                                    .toList();
                                final chips = _getGroupedChips(openItems);

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedRental = r;
                                      _selectedCylinderIds.clear();
                                      final late = dueDate.isNotEmpty
                                          ? _calculateLateDays(dueDate)
                                          : 0;
                                      if (late > 0) {
                                        _fineNoteController.text =
                                            'Terlambat mengembalikan $late hari';
                                        _fineAmountController.text =
                                            _formatCurrency(late * 15000);
                                      } else {
                                        _fineNoteController.clear();
                                        _fineAmountController.text = '0';
                                      }
                                    });
                                    Navigator.of(ctx).pop();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Avatar circle
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.primary
                                                    .withAlpha(18),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    inv,
                                                    style: AppTextStyles
                                                        .bodyMedium
                                                        .copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isSelected
                                                          ? AppColors
                                                              .primary
                                                          : AppColors
                                                              .textPrimary,
                                                    ),
                                                  ),
                                                  if (lateDays > 0)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: AppColors
                                                            .errorLight,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                    4),
                                                      ),
                                                      child: Text(
                                                        'Telat $lateDays hr',
                                                        style: AppTextStyles
                                                            .caption
                                                            .copyWith(
                                                          color: AppColors
                                                              .error,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w700,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                name,
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                        color: AppColors
                                                            .textSecondary),
                                              ),
                                              if (phone.isNotEmpty)
                                                Text(
                                                  phone,
                                                  style: AppTextStyles
                                                      .caption
                                                      .copyWith(
                                                          color: AppColors
                                                              .textSecondary,
                                                          fontSize: 11),
                                                ),
                                              if (dueDate.length >= 10)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 3),
                                                  child: Text(
                                                    'Batas: ${dueDate.substring(0, 10)}',
                                                    style: AppTextStyles
                                                        .caption
                                                        .copyWith(
                                                      color: lateDays > 0
                                                          ? AppColors.error
                                                          : AppColors
                                                              .textSecondary,
                                                      fontWeight: lateDays >
                                                              0
                                                          ? FontWeight.w600
                                                          : FontWeight
                                                              .normal,
                                                    ),
                                                  ),
                                                ),
                                              // Cylinder chips
                                              if (chips.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 6),
                                                  child: Wrap(
                                                    spacing: 4,
                                                    runSpacing: 4,
                                                    children: chips.map((c) {
                                                      final isAcc = c['isAccessory'] as bool;
                                                      return Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    8,
                                                                vertical: 3),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: isAcc
                                                              ? AppColors.warningLight
                                                              : AppColors.primary.withAlpha(12),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      20),
                                                          border: Border.all(
                                                            color: isAcc
                                                                ? AppColors.warning.withAlpha(80)
                                                                : AppColors.primary.withAlpha(40),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          c['label'] as String,
                                                          style: AppTextStyles
                                                              .caption
                                                              .copyWith(
                                                            color: isAcc
                                                                ? AppColors.warning
                                                                : AppColors.primary,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Padding(
                                            padding:
                                                EdgeInsets.only(left: 8),
                                            child: Icon(
                                              Icons.check_circle_rounded,
                                              color: AppColors.primary,
                                              size: 20,
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
                ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildLateBadge(String dueDateStr) {
    final lateDays = _calculateLateDays(dueDateStr);
    if (lateDays == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Tepat Waktu',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Terlambat $lateDays Hari',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── Items Card ─────────────────────────────────────────────────────────────
  Widget _buildItemsCard() {
    final List<dynamic> items = _selectedRental!['items'] ?? [];
    // Only filter cylinder items that are not returned
    final openItems = items.where((i) => i['returnedAt'] == null).toList();

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
        children: openItems.map((item) {
          final cyl = item['cylinder'] ?? {};
          final String serial = cyl['serialNumber'] ?? 'CYL-001';
          final String size = cyl['size'] ?? '6m3';
          final String id = cyl['id'] ?? '';
          final isSelected = _selectedCylinderIds.contains(id);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: CheckboxListTile(
              activeColor: AppColors.primary,
              title: Text(
                'Serial: $serial',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Kapasitas / Ukuran: $size',
                style: AppTextStyles.caption,
              ),
              value: isSelected,
              onChanged: (bool? val) {
                setState(() {
                  if (val == true) {
                    _selectedCylinderIds.add(id);
                  } else {
                    _selectedCylinderIds.remove(id);
                  }
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Fines Card ─────────────────────────────────────────────────────────────
  Widget _buildFinesCard() {
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
            controller: _fineAmountController,
            keyboardType: TextInputType.number,
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            inputFormatters: [CurrencyInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Jumlah Denda Potongan',
              prefixText: 'Rp ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _fineNoteController,
            maxLines: 2,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Alasan Denda / Keterangan',
              hintText: 'Cth: Terlambat, Kerusakan Regulator...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Refund Details Card ────────────────────────────────────────────────────
  Widget _buildRefundDetailsCard(int initialDeposit, int fineAmount, int finalRefund) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Jaminan (Awal)',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                _formatCurrency(initialDeposit),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Potongan Denda',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
              ),
              Text(
                '- ${_formatCurrency(fineAmount)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: Color(0xFFECEFF5), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pengembalian Dana',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                _formatCurrency(finalRefund),
                style: AppTextStyles.priceText.copyWith(
                  fontSize: 18,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom Action Bar ──────────────────────────────────────────────────────
  Widget _buildBottomActionBar(TransactionProvider provider, int finalRefund) {
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
            onPressed: _isSubmitting ? null : () => _processReturnSubmit(provider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size.fromHeight(52),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isSubmitting ? 'Memproses Pengembalian...' : 'Simpan Pengembalian',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (_isSubmitting) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
