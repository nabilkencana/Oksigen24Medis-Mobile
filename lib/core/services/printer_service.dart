import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:oksigen24medis_mobile2/features/payment/receipt_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  // Get list of paired bluetooth devices
  Future<List<BluetoothInfo>> getBluetoothDevices() async {
    try {
      // Request Bluetooth and Location permissions at runtime
      await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();

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

  // Load, resize, and rasterize logo.png to monochrome bytes
  Future<List<int>> _getLogoBytes() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      final Uint8List bytes = data.buffer.asUint8List();
      final img.Image? originalImage = img.decodePng(bytes);
      if (originalImage == null) return [];

      // Resize the logo to fit width (160 pixels is a perfect fit for 58mm thermal printers)
      final img.Image resized = img.copyResize(
        originalImage,
        width: 260,
        interpolation: img.Interpolation.nearest,
      );

      final int width = resized.width;
      final int height = resized.height;
      final int widthBytes = (width + 7) ~/ 8;

      final List<int> escposBytes = [];
      // Header for raster bit image: GS v 0 0 xL xH yL yH
      escposBytes.addAll([
        0x1d, 0x76, 0x30, 0,
        widthBytes & 0xff,
        (widthBytes >> 8) & 0xff,
        height & 0xff,
        (height >> 8) & 0xff,
      ]);

      // Write pixel data
      for (int y = 0; y < height; y++) {
        int currentByte = 0;
        for (int x = 0; x < widthBytes * 8; x++) {
          final int bitIndex = x % 8;
          if (x < width) {
            final img.Pixel pixel = resized.getPixel(x, y);
            final double r = pixel.r.toDouble();
            final double g = pixel.g.toDouble();
            final double b = pixel.b.toDouble();
            final double a = pixel.a.toDouble();
            final double luminance = 0.299 * r + 0.587 * g + 0.114 * b;
            
            // If pixel is dark and opaque, set bit to 1 (black)
            if (a > 128 && luminance < 128) {
              currentByte |= (1 << (7 - bitIndex));
            }
          }
          if (bitIndex == 7) {
            escposBytes.add(currentByte);
            currentByte = 0;
          }
        }
      }

      // Add a line feed after the image
      escposBytes.addAll([0x0a]);
      return escposBytes;
    } catch (_) {
      return [];
    }
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
    final shopAddress = prefs.getString('receipt_shop_address') ?? 'Dusun Sembon, Sembon, Karangrejo\nTulungagung, Jawa Timur\nHP: 085866972209 / 085733930575';
    List<String> shopAddressLines = shopAddress.split('\n');

    // Replace any occurrence of Telp: with HP: to prevent 32-character wrapping
    shopAddressLines = shopAddressLines.map((line) {
      if (line.contains('085866972209') || line.contains('085733930575')) {
        return line
            .replaceAll('Telp:', 'HP:')
            .replaceAll('Telpon:', 'HP:')
            .replaceAll('Telephone:', 'HP:');
      }
      return line;
    }).toList();

    final hasPhone = shopAddressLines.any((line) => line.contains('085866972209') || line.contains('085733930575'));
    if (!hasPhone) {
      shopAddressLines.add('HP: 085866972209 / 085733930575');
    }
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

    // Print logo if generated successfully
    final logoBytes = await _getLogoBytes();
    if (logoBytes.isNotEmpty) {
      bytes.addAll(logoBytes);
    }

    bytes.addAll(boldOn);
    addLine(shopName);
    bytes.addAll(boldOff);
    for (var line in shopAddressLines) {
      if (line.trim().isNotEmpty) {
        addLine(line.trim());
      }
    }
    addLine('--------------------------------');

    bytes.addAll(alignLeft);
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    addLine('No. Nota : $invoiceNo');
    addLine('Kasir    : $cashierName');
    addLine('Pelanggan: $customerName');
    addLine('Tanggal  : $dateStr');
    addLine('--------------------------------');

    // Print items
    for (var item in receiptItems) {
      // Line 1: Item Name
      addLine(item.name);
      
      // Line 2: Quantity & Subtotal
      final qtyPriceStr = '  ${item.quantity} x Rp ${_formatNumber(item.price)}';
      final subtotalStr = 'Rp ${_formatNumber(item.price * item.quantity)}';
      final spaces = 32 - qtyPriceStr.length - subtotalStr.length;
      
      if (spaces > 0) {
        addLine(qtyPriceStr + (' ' * spaces) + subtotalStr);
      } else {
        addLine('$qtyPriceStr  $subtotalStr');
      }
    }
    addLine('--------------------------------');

    // Totals
    final totalLabel = 'TOTAL:';
    final totalVal = 'Rp ${_formatNumber(totalTagihan)}';
    final totalSpaces = 32 - totalLabel.length - totalVal.length;
    bytes.addAll(boldOn);
    addLine(totalLabel + (' ' * (totalSpaces > 0 ? totalSpaces : 2)) + totalVal);
    bytes.addAll(boldOff);

    final receivedLabel = 'BAYAR:';
    final receivedVal = 'Rp ${_formatNumber(receivedAmount)}';
    final recSpaces = 32 - receivedLabel.length - receivedVal.length;
    addLine(receivedLabel + (' ' * (recSpaces > 0 ? recSpaces : 2)) + receivedVal);

    final changeLabel = 'KEMBALI:';
    final changeVal = 'Rp ${_formatNumber(change)}';
    final changeSpaces = 32 - changeLabel.length - changeVal.length;
    addLine(changeLabel + (' ' * (changeSpaces > 0 ? changeSpaces : 2)) + changeVal);

    final methodLabel = 'METODE:';
    final methodVal = paymentMethod.toUpperCase();
    final methodSpaces = 32 - methodLabel.length - methodVal.length;
    addLine(methodLabel + (' ' * (methodSpaces > 0 ? methodSpaces : 2)) + methodVal);

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
