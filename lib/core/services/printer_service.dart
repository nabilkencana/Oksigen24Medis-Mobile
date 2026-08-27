import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as android_bt;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ios_ble;
import 'package:image/image.dart' as img;
import 'package:oksigen24medis_mobile2/features/payment/receipt_item.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PrinterConnectionStatus {
  disconnected,
  connecting,
  connected,
  printing,
  error,
}

class AppPrinterDevice {
  final String name;
  final String address;
  final dynamic nativeDevice;
  final bool isBle;

  AppPrinterDevice({
    required this.name,
    required this.address,
    required this.nativeDevice,
    this.isBle = false,
  });

  // Backward compatibility getters
  String get macAdress => address;
  String get macAddress => address;
}

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final android_bt.BlueThermalPrinter _androidBt =
      android_bt.BlueThermalPrinter.instance;

  // iOS BLE state
  ios_ble.BluetoothDevice? _bleConnectedDevice;
  ios_ble.BluetoothCharacteristic? _bleWriteCharacteristic;

  PrinterConnectionStatus _status = PrinterConnectionStatus.disconnected;
  List<AppPrinterDevice> _devices = [];
  AppPrinterDevice? _selectedDevice;

  PrinterConnectionStatus get status => _status;
  List<AppPrinterDevice> get devices => List.unmodifiable(_devices);
  AppPrinterDevice? get selectedDevice => _selectedDevice;
  bool get isConnectedSync => _status == PrinterConnectionStatus.connected;

  Future<bool> checkAndRequestPermissions() async {
    try {
      final bluetoothStatus = await Permission.bluetooth.request();
      final connectStatus = await Permission.bluetoothConnect.request();
      final scanStatus = await Permission.bluetoothScan.request();
      final locationStatus = await Permission.location.request();
      return (bluetoothStatus.isGranted || connectStatus.isGranted) &&
          (scanStatus.isGranted || locationStatus.isGranted);
    } catch (_) {
      return true;
    }
  }

  // Get list of paired / available bluetooth devices
  Future<List<AppPrinterDevice>> getBluetoothDevices() async {
    try {
      await checkAndRequestPermissions();

      if (Platform.isAndroid) {
        final rawDevices = await _androidBt.getBondedDevices();
        _devices = rawDevices
            .map((d) => AppPrinterDevice(
                  name: (d.name != null && d.name!.isNotEmpty)
                      ? d.name!
                      : "Bluetooth Printer",
                  address: d.address ?? "",
                  nativeDevice: d,
                  isBle: false,
                ))
            .toList();
        return _devices;
      } else if (Platform.isIOS) {
        // iOS BLE Scanning via FlutterBluePlus (dukungan printer Rongta / RPP02N / Eppos / POS)
        final results = <AppPrinterDevice>[];

        // 1. Cek printer yang sudah terhubung di iOS Bluetooth system settings
        try {
          final systemDevs = await ios_ble.FlutterBluePlus.systemDevices([]);
          for (final d in systemDevs) {
            final devName = d.platformName.isNotEmpty
                ? d.platformName
                : (d.advName.isNotEmpty ? d.advName : "Bluetooth Printer");
            final devId = d.remoteId.str;
            if (!results.any((e) => e.address == devId)) {
              results.add(AppPrinterDevice(
                name: devName,
                address: devId,
                nativeDevice: d,
                isBle: true,
              ));
            }
          }
        } catch (_) {}

        // 2. Lakukan scanning aktif BLE selama 4 detik
        if (!ios_ble.FlutterBluePlus.isScanningNow) {
          await ios_ble.FlutterBluePlus.startScan(
            timeout: const Duration(seconds: 4),
          );
        }

        final scanSubscription =
            ios_ble.FlutterBluePlus.scanResults.listen((scans) {
          for (final r in scans) {
            final devName = r.device.platformName.isNotEmpty
                ? r.device.platformName
                : (r.advertisementData.advName.isNotEmpty
                    ? r.advertisementData.advName
                    : "Bluetooth Printer");

            final devId = r.device.remoteId.str;
            if (devName.isNotEmpty &&
                !results.any((element) => element.address == devId)) {
              results.add(AppPrinterDevice(
                name: devName,
                address: devId,
                nativeDevice: r.device,
                isBle: true,
              ));
            }
          }
        });

        await Future.delayed(const Duration(seconds: 4));
        try {
          await ios_ble.FlutterBluePlus.stopScan();
        } catch (_) {}
        await scanSubscription.cancel();

        _devices = results;
        return _devices;
      }
      return [];
    } catch (e) {
      debugPrint('[PrinterService] getBluetoothDevices error: $e');
      return [];
    }
  }

  // Connect to a device by AppPrinterDevice or String address
  Future<bool> connect(dynamic deviceOrAddress) async {
    _status = PrinterConnectionStatus.connecting;
    try {
      AppPrinterDevice? targetDevice;

      if (deviceOrAddress is AppPrinterDevice) {
        targetDevice = deviceOrAddress;
      } else if (deviceOrAddress is String) {
        final found = _devices.where((d) => d.address == deviceOrAddress);
        if (found.isNotEmpty) {
          targetDevice = found.first;
        } else if (Platform.isAndroid) {
          targetDevice = AppPrinterDevice(
            name: 'Bluetooth Printer',
            address: deviceOrAddress,
            nativeDevice: android_bt.BluetoothDevice('Bluetooth Printer', deviceOrAddress),
            isBle: false,
          );
        } else if (Platform.isIOS) {
          final bleDev = ios_ble.BluetoothDevice.fromId(deviceOrAddress);
          targetDevice = AppPrinterDevice(
            name: bleDev.platformName.isNotEmpty ? bleDev.platformName : 'Bluetooth Printer',
            address: deviceOrAddress,
            nativeDevice: bleDev,
            isBle: true,
          );
        }
      }

      if (targetDevice == null) {
        _status = PrinterConnectionStatus.disconnected;
        return false;
      }

      if (Platform.isAndroid && !targetDevice.isBle) {
        final androidDevice =
            targetDevice.nativeDevice as android_bt.BluetoothDevice;
        final isCurrentlyConnected = await _androidBt.isConnected ?? false;
        if (isCurrentlyConnected) {
          try {
            await _androidBt.disconnect();
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (_) {}
        }

        final dynamic result = await _androidBt.connect(androidDevice);
        final isNowConnected = await _androidBt.isConnected ?? false;
        if (result == true || isNowConnected) {
          _selectedDevice = targetDevice;
          _status = PrinterConnectionStatus.connected;
          return true;
        }
      } else {
        // iOS BLE Connection & GATT Characteristic Discovery
        final bleDev = targetDevice.nativeDevice as ios_ble.BluetoothDevice;
        await bleDev.connect(timeout: const Duration(seconds: 8));

        final services = await bleDev.discoverServices();
        ios_ble.BluetoothCharacteristic? targetChar;

        for (final service in services) {
          for (final char in service.characteristics) {
            if (char.properties.write ||
                char.properties.writeWithoutResponse) {
              targetChar = char;
              break;
            }
          }
          if (targetChar != null) break;
        }

        if (targetChar != null) {
          _bleConnectedDevice = bleDev;
          _bleWriteCharacteristic = targetChar;
          _selectedDevice = targetDevice;
          _status = PrinterConnectionStatus.connected;
          return true;
        } else {
          await bleDev.disconnect();
        }
      }

      _status = PrinterConnectionStatus.disconnected;
      return false;
    } catch (e) {
      debugPrint('[PrinterService] connect error: $e');
      _status = PrinterConnectionStatus.error;
      return false;
    }
  }

  // Check connection status
  Future<bool> isConnected() async {
    try {
      if (Platform.isAndroid) {
        final conn = await _androidBt.isConnected ?? false;
        if (conn) _status = PrinterConnectionStatus.connected;
        return conn;
      } else if (Platform.isIOS) {
        final isConn = _bleConnectedDevice != null &&
            _bleWriteCharacteristic != null &&
            _status == PrinterConnectionStatus.connected;
        return isConn;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Disconnect from printer
  Future<void> disconnect() async {
    try {
      if (Platform.isAndroid &&
          _selectedDevice != null &&
          !_selectedDevice!.isBle) {
        await _androidBt.disconnect();
      } else if (_bleConnectedDevice != null) {
        await _bleConnectedDevice!.disconnect();
        _bleConnectedDevice = null;
        _bleWriteCharacteristic = null;
      }
    } catch (_) {}
    _selectedDevice = null;
    _status = PrinterConnectionStatus.disconnected;
  }

  // Kirim raw bytes ESC/POS dengan chunking khusus untuk BLE iOS
  Future<bool> printRawBytes(List<int> bytes) async {
    final connected = await isConnected();
    if (!connected) return false;

    _status = PrinterConnectionStatus.printing;
    try {
      if (Platform.isAndroid &&
          _selectedDevice != null &&
          !_selectedDevice!.isBle) {
        await _androidBt.writeBytes(Uint8List.fromList(bytes));
      } else if (_bleWriteCharacteristic != null) {
        final useAck = _bleWriteCharacteristic!.properties.write;
        const chunkSize = 20;
        final uint8 = Uint8List.fromList(bytes);

        for (int i = 0; i < uint8.length; i += chunkSize) {
          final end = (i + chunkSize < uint8.length) ? i + chunkSize : uint8.length;
          final chunk = uint8.sublist(i, end);

          if (useAck) {
            await _bleWriteCharacteristic!.write(chunk, withoutResponse: false);
          } else {
            await _bleWriteCharacteristic!.write(chunk, withoutResponse: true);
            await Future.delayed(const Duration(milliseconds: 20));
          }
        }
      }

      _status = PrinterConnectionStatus.connected;
      return true;
    } catch (e) {
      debugPrint('[PrinterService] printRawBytes error: $e');
      _status = PrinterConnectionStatus.connected;
      return false;
    }
  }

  // Cetak struk berbasis gambar dengan slicing pita 48px & Laplacian sharpening (dari eppos_both)
  Future<bool> printReceiptImage(Uint8List imageBytes) async {
    final connected = await isConnected();
    if (!connected) return false;

    _status = PrinterConnectionStatus.printing;
    try {
      if (Platform.isAndroid &&
          _selectedDevice != null &&
          !_selectedDevice!.isBle) {
        final escPosBytes =
            await compute(_computeEscPos, _EscPosInput(imageBytes, 384));
        if (escPosBytes.isEmpty) {
          _status = PrinterConnectionStatus.connected;
          return false;
        }
        await _androidBt.writeBytes(escPosBytes);
      } else if (_bleWriteCharacteristic != null) {
        final bands =
            await compute(_buildIosBands, _EscPosInput(imageBytes, 384));
        if (bands.isEmpty) {
          _status = PrinterConnectionStatus.connected;
          return false;
        }

        final useAck = _bleWriteCharacteristic!.properties.write;
        const chunkSize = 20;

        for (int bandIdx = 0; bandIdx < bands.length; bandIdx++) {
          final band = bands[bandIdx];

          for (int i = 0; i < band.length; i += chunkSize) {
            final end =
                (i + chunkSize < band.length) ? i + chunkSize : band.length;
            final chunk = band.sublist(i, end);

            if (useAck) {
              await _bleWriteCharacteristic!.write(chunk, withoutResponse: false);
            } else {
              await _bleWriteCharacteristic!.write(chunk, withoutResponse: true);
              await Future.delayed(const Duration(milliseconds: 30));
            }
          }

          // Jeda 200ms antar pita untuk memproses & cetak di printer BLE
          if (bandIdx < bands.length - 1) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }
      }

      _status = PrinterConnectionStatus.connected;
      return true;
    } catch (e) {
      debugPrint('[PrinterService] printReceiptImage error: $e');
      _status = PrinterConnectionStatus.connected;
      return false;
    }
  }

  // Load, resize, and rasterize logo.png to monochrome bytes
  Future<List<int>> _getLogoBytes() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      final Uint8List bytes = data.buffer.asUint8List();
      final img.Image? originalImage = img.decodePng(bytes);
      if (originalImage == null) return [];

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
    final shopAddress = prefs.getString('receipt_shop_address') ??
        'Dusun Sembon, Sembon, Karangrejo\nTulungagung, Jawa Timur\nHP: 085866972209 / 085733930575';
    List<String> shopAddressLines = shopAddress.split('\n');

    shopAddressLines = shopAddressLines.map((line) {
      if (line.contains('085866972209') || line.contains('085733930575')) {
        return line
            .replaceAll('Telp:', 'HP:')
            .replaceAll('Telpon:', 'HP:')
            .replaceAll('Telephone:', 'HP:');
      }
      return line;
    }).toList();

    final hasPhone = shopAddressLines.any((line) =>
        line.contains('085866972209') || line.contains('085733930575'));
    if (!hasPhone) {
      shopAddressLines.add('HP: 085866972209 / 085733930575');
    }
    final footer =
        prefs.getString('receipt_footer') ?? 'Terima Kasih atas\nKepercayaan Anda';
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

    // Begin receipt layout (58mm printer - 32 characters wide)
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
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    addLine('No. Nota : $invoiceNo');
    addLine('Kasir    : $cashierName');
    addLine('Pelanggan: $customerName');
    addLine('Tanggal  : $dateStr');
    addLine('--------------------------------');

    // Print items
    for (var item in receiptItems) {
      addLine(item.name);
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

    return await printRawBytes(bytes);
  }

  String _formatNumber(int val) {
    return val.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

class _EscPosInput {
  final Uint8List bytes;
  final int printerWidth;
  const _EscPosInput(this.bytes, this.printerWidth);
}

// ── Android: encode seluruh gambar ke 1 ESC/POS payload ─────────────────────
Uint8List _computeEscPos(_EscPosInput input) {
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) return Uint8List(0);

  final resized = img.copyResize(
    decoded,
    width: input.printerWidth,
    height: -1,
    interpolation: img.Interpolation.average,
  );

  final gray = img.grayscale(resized);
  final w = gray.width;
  final h = gray.height;

  final raw = List<int>.generate(w * h, (idx) {
    return gray.getPixel(idx % w, idx ~/ w).r.toInt();
  });

  final sharp = List<int>.generate(w * h, (idx) {
    final x = idx % w;
    final y = idx ~/ w;
    if (x == 0 || x == w - 1 || y == 0 || y == h - 1) return raw[idx];
    return (5 * raw[idx] -
            raw[idx - 1] -
            raw[idx + 1] -
            raw[idx - w] -
            raw[idx + w])
        .clamp(0, 255);
  });

  final bytesPerRow = (w + 7) ~/ 8;
  final pixelRows = Uint8List(bytesPerRow * h);

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (sharp[y * w + x] < 128) {
        pixelRows[y * bytesPerRow + (x ~/ 8)] |= (0x80 >> (x % 8));
      }
    }
  }

  final out = BytesBuilder();
  out.add([0x1B, 0x40]); // ESC @
  out.add([0x1B, 0x33, 0x00]); // ESC 3 0
  out.add([0x1B, 0x61, 0x01]); // ESC a 1

  final xL = bytesPerRow & 0xFF;
  final xH = (bytesPerRow >> 8) & 0xFF;
  final yL = h & 0xFF;
  final yH = (h >> 8) & 0xFF;
  out.add([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);
  out.add(pixelRows);

  out.add([0x0A, 0x0A, 0x0A, 0x0A]);
  out.add([0x1D, 0x56, 0x01]);

  return out.toBytes();
}

// ── iOS BLE: encode gambar ke List pita ESC/POS 48px ────────────────────────
List<Uint8List> _buildIosBands(_EscPosInput input) {
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) return [];

  final resized = img.copyResize(
    decoded,
    width: input.printerWidth,
    height: -1,
    interpolation: img.Interpolation.average,
  );

  final gray = img.grayscale(resized);
  final w = gray.width;
  final totalH = gray.height;

  final raw = List<int>.generate(w * totalH, (idx) {
    return gray.getPixel(idx % w, idx ~/ w).r.toInt();
  });

  final sharp = List<int>.generate(w * totalH, (idx) {
    final x = idx % w;
    final y = idx ~/ w;
    if (x == 0 || x == w - 1 || y == 0 || y == totalH - 1) return raw[idx];
    return (5 * raw[idx] -
            raw[idx - 1] -
            raw[idx + 1] -
            raw[idx - w] -
            raw[idx + w])
        .clamp(0, 255);
  });

  final bytesPerRow = (w + 7) ~/ 8;
  final xL = bytesPerRow & 0xFF;
  final xH = (bytesPerRow >> 8) & 0xFF;

  final List<Uint8List> result = [];

  final initBuilder = BytesBuilder();
  initBuilder.add([0x1B, 0x40]); // ESC @
  initBuilder.add([0x1B, 0x33, 0x00]); // ESC 3 0
  initBuilder.add([0x1B, 0x61, 0x01]); // ESC a 1
  result.add(initBuilder.toBytes());

  const int bandH = 48;

  for (int startY = 0; startY < totalH; startY += bandH) {
    final currentH = (startY + bandH <= totalH) ? bandH : (totalH - startY);
    final pixelRows = Uint8List(bytesPerRow * currentH);

    for (int y = 0; y < currentH; y++) {
      for (int x = 0; x < w; x++) {
        if (sharp[(startY + y) * w + x] < 128) {
          pixelRows[y * bytesPerRow + (x ~/ 8)] |= (0x80 >> (x % 8));
        }
      }
    }

    final yL = currentH & 0xFF;
    final yH = (currentH >> 8) & 0xFF;
    final bandBuilder = BytesBuilder();
    bandBuilder.add([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);
    bandBuilder.add(pixelRows);
    result.add(bandBuilder.toBytes());
  }

  final tailBuilder = BytesBuilder();
  tailBuilder.add([0x0A, 0x0A, 0x0A, 0x0A]);
  tailBuilder.add([0x1D, 0x56, 0x01]);
  result.add(tailBuilder.toBytes());

  return result;
}
