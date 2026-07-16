import 'dart:convert';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:oksigen24medis_mobile2/features/payment/receipt_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  // Get list of paired bluetooth devices
  Future<List<BluetoothInfo>> getBluetoothDevices() async {
    try {
      final List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;
      return devices;
    } catch (e) {
      return [];
    }
  }

  // Connect to a device by MAC address
  Future<bool> connect(String macAddress) async {
    try {
      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      return result;
    } catch (e) {
      return false;
    }
  }

  // Check connection status
  Future<bool> isConnected() async {
    try {
      final bool result = await PrintBluetoothThermal.connectionStatus;
      return result;
    } catch (e) {
      return false;
    }
  }

  // Disconnect from printer
  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
  }

  // Print receipt to thermal printer
  Future<bool> printReceipt({
    required String invoiceNo,
    required String customerName,
    required String cashierName,
    required List<ReceiptItem> receiptItems,
    required String paymentMethod,
    required int totalTagihan,
    required int receivedAmount,
    required int change,
  }) async {
    final connected = await isConnected();
    if (!connected) return false;

    // Load custom settings
    final prefs = await SharedPreferences.getInstance();
    final shopName = prefs.getString('receipt_shop_name') ?? 'OKSIGEN MEDIS 24 JAM';
    final shopAddress = prefs.getString('receipt_shop_address') ?? 'Dusun Sembon, Sembon, Karangrejo\nTulungagung, Jawa Timur';
    final shopAddressLines = shopAddress.split('\n');
    final footer = prefs.getString('receipt_footer') ?? 'Terima Kasih atas\nKepercayaan Anda';
    final footerLines = footer.split('\n');

    List<int> bytes = [];

    // ESC/POS commands
    const escInit = [0x1b, 0x40]; // Initialize printer
    const alignCenter = [0x1b, 0x61, 1]; // Center alignment
    const alignLeft = [0x1b, 0x61, 0]; // Left alignment
    const boldOn = [0x1b, 0x45, 1]; // Bold text ON
    const boldOff = [0x1b, 0x45, 0]; // Bold text OFF
    const feedPaper = [0x1b, 0x64, 4]; // Feed 4 lines



    void addLine(String text) {
      bytes.addAll(latin1.encode('$text\n'));
    }

    // Begin receipt layout (assuming 58mm printer - 32 characters wide)
    bytes.addAll(escInit);
    bytes.addAll(alignCenter);
    bytes.addAll(boldOn);
    addLine(shopName);
    bytes.addAll(boldOff);
    for (var line in shopAddressLines) {
      if (line.trim().isNotEmpty) {
        addLine(line.trim());
      }
    }
    addLine('Kasir: $cashierName');
    addLine('--------------------------------');

    bytes.addAll(alignLeft);
    addLine('Invoice: $invoiceNo');
    addLine('Pelanggan: $customerName');
    addLine('Tanggal: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}');
    addLine('--------------------------------');

    // Print items
    for (var item in receiptItems) {
      // Line 1: Item Name
      addLine('${item.quantity}x ${item.name}');
      
      // Line 2: Price info & Subtotal
      final priceStr = '@ Rp ${_formatNumber(item.price)}';
      final subtotalStr = 'Rp ${_formatNumber(item.price * item.quantity)}';
      
      // Format to fit 32 chars: priceStr left aligned, subtotalStr right aligned
      final spaces = 32 - priceStr.length - subtotalStr.length;
      if (spaces > 0) {
        addLine(priceStr + (' ' * spaces) + subtotalStr);
      } else {
        addLine('$priceStr  $subtotalStr');
      }
    }
    addLine('--------------------------------');

    // Totals
    final totalLabel = 'Total Tagihan:';
    final totalVal = 'Rp ${_formatNumber(totalTagihan)}';
    final totalSpaces = 32 - totalLabel.length - totalVal.length;
    bytes.addAll(boldOn);
    addLine(totalLabel + (' ' * (totalSpaces > 0 ? totalSpaces : 2)) + totalVal);
    bytes.addAll(boldOff);

    final receivedLabel = 'Diterima:';
    final receivedVal = 'Rp ${_formatNumber(receivedAmount)}';
    final recSpaces = 32 - receivedLabel.length - receivedVal.length;
    addLine(receivedLabel + (' ' * (recSpaces > 0 ? recSpaces : 2)) + receivedVal);

    final changeLabel = 'Kembali:';
    final changeVal = 'Rp ${_formatNumber(change)}';
    final changeSpaces = 32 - changeLabel.length - changeVal.length;
    addLine(changeLabel + (' ' * (changeSpaces > 0 ? changeSpaces : 2)) + changeVal);

    addLine('--------------------------------');
    bytes.addAll(alignCenter);
    bytes.addAll(boldOn);
    for (var line in footerLines) {
      if (line.trim().isNotEmpty) {
        addLine(line.trim());
      }
    }
    bytes.addAll(boldOff);
    
    // Add feed and cut
    bytes.addAll(feedPaper);

    // Send to printer
    final result = await PrintBluetoothThermal.writeBytes(bytes);
    return result;
  }

  String _formatNumber(int val) {
    return val.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
