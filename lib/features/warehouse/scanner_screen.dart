import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oksigen24medis_mobile2/core/state/warehouse_provider.dart';
import 'package:oksigen24medis_mobile2/features/warehouse/stock_detail_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  AnimationController? _animationController;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  void _initAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController!.repeat(reverse: true);
  }

  bool _isAccessoryAsset(String serial, String size) {
    final s = serial.toUpperCase();
    final sz = size.toUpperCase();
    return s.startsWith('REG-') || s.startsWith('TRL-') || s.startsWith('ACC-') || sz == 'PCS';
  }

  void _processCode(String code) {
    if (code.trim().isEmpty) return;

    final provider = Provider.of<WarehouseProvider>(context, listen: false);

    // 1. Search in products (by SKU or name)
    final prod = provider.products.firstWhere(
      (p) => p['sku']?.toString().toLowerCase() == code.trim().toLowerCase() ||
             p['name']?.toString().toLowerCase() == code.trim().toLowerCase(),
      orElse: () => null,
    );

    if (prod != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan Berhasil: ${prod['name']}'),
          backgroundColor: const Color(0xFF00A67E),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => StockDetailScreen(
            title: prod['name'] ?? 'Produk',
            sku: prod['sku'] ?? 'SKU',
            total: prod['currentStock'] ?? 0,
            tersedia: prod['currentStock'] ?? 0,
            kosong: 0,
            disewa: 0,
            vendor: 0,
            maintenance: 0,
            isProduct: true,
          ),
        ),
      );
      return;
    }

    // 2. Search in cylinders (by Serial Number)
    final cyl = provider.cylinders.firstWhere(
      (c) => c['serialNumber']?.toString().toLowerCase() == code.trim().toLowerCase(),
      orElse: () => null,
    );

    if (cyl != null) {
      final isAcc = _isAccessoryAsset(cyl['serialNumber']?.toString() ?? '', cyl['size']?.toString() ?? '');

      String title;
      String sku;
      int total;
      int tersedia;
      int kosong;
      int disewa;
      int vendor;
      int maintenance;

      if (isAcc) {
        final otName = cyl['oxygenType']?['name'] ?? 'Aksesoris Sewa';
        title = otName;
        sku = 'SKU: RNT-ACC';

        final list = provider.rentableAccessories.where((c) => (c['oxygenType']?['name'] ?? 'Aksesoris Sewa') == otName).toList();
        total = list.length;
        tersedia = list.where((i) => i['status'] == 'AVAILABLE').length;
        disewa = list.where((i) => i['status'] == 'RENTED').length;
        maintenance = list.where((i) => i['status'] == 'MAINTENANCE').length;
        kosong = 0;
        vendor = 0;
      } else {
        final otName = cyl['oxygenType']?['name'] ?? 'Oksigen Medis';
        final size = cyl['size'] ?? '1m3';
        title = '$otName ($size)';
        sku = 'SKU: CYL-$size';

        final list = provider.actualCylinders.where((c) {
          final cOt = c['oxygenType']?['name'] ?? 'Oksigen Medis';
          final cSize = c['size'] ?? '1m3';
          return cOt == otName && cSize == size;
        }).toList();

        total = list.length;
        tersedia = list.where((i) => i['status'] == 'AVAILABLE').length;
        kosong = list.where((i) => i['status'] == 'EMPTY').length;
        disewa = list.where((i) => i['status'] == 'RENTED').length;
        vendor = list.where((i) => i['status'] == 'AT_VENDOR').length;
        maintenance = list.where((i) => i['status'] == 'MAINTENANCE').length;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan Berhasil: ${cyl['serialNumber']} ($title)'),
          backgroundColor: const Color(0xFF00A67E),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => StockDetailScreen(
            title: title,
            sku: sku,
            total: total,
            tersedia: tersedia,
            kosong: kosong,
            disewa: disewa,
            vendor: vendor,
            maintenance: maintenance,
            isProduct: false,
          ),
        ),
      );
      return;
    }

    // If not found
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SKU / Serial Number tidak terdaftar di sistem'),
        backgroundColor: Color(0xFFEF4444),
      ),
    );

    // Cooldown before scanning again
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _inputController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_animationController == null) {
      _initAnimation();
    }
    final provider = Provider.of<WarehouseProvider>(context);

    // Get sample items for quick simulation selection
    final List<String> sampleCodes = [];
    if (provider.products.isNotEmpty) {
      final sampleProd = provider.products.first;
      if (sampleProd['sku'] != null) sampleCodes.add(sampleProd['sku'].toString());
    }
    
    // Add some cylinder serial numbers
    final cyls = provider.cylinders.take(4).toList();
    for (var c in cyls) {
      if (c['serialNumber'] != null) {
        sampleCodes.add(c['serialNumber'].toString());
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Scan Barcode / QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // 1. Full Screen Camera View
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (BarcodeCapture capture) {
                if (_isProcessing) return;
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null && code.isNotEmpty) {
                    setState(() {
                      _isProcessing = true;
                    });
                    _processCode(code);
                    break;
                  }
                }
              },
            ),
          ),

          // 2. Dark Overlay with Cutout hole in the center
          Positioned.fill(
            child: ClipPath(
              clipper: ScannerOverlayClipper(),
              child: Container(
                color: Colors.black.withOpacity(0.65),
              ),
            ),
          ),

          // 3. Scanner Target Box & Animated Laser
          Center(
            child: SizedBox(
              width: 250,
              height: 250,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _animation ?? const AlwaysStoppedAnimation(0.5),
                    builder: (context, child) {
                      final animValue = _animation?.value ?? 0.5;
                      final topOffset = animValue * (250 - 4 - 3) + 2;
                      return Positioned(
                        top: topOffset,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 5. Instruction text placed above scanner box
          Positioned(
            top: MediaQuery.of(context).size.height * 0.22,
            left: 24,
            right: 24,
            child: const Text(
              'Arahkan kamera ke barcode SKU atau QR Code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),

          // 6. Flashlight button under scanner box
          Positioned(
            top: (MediaQuery.of(context).size.height + 250) / 2 + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: IconButton(
                  icon: const Icon(Icons.flashlight_on, color: Colors.white, size: 24),
                  onPressed: () {
                    _scannerController.toggleTorch();
                  },
                ),
              ),
            ),
          ),

          // 7. Manual Input card at the bottom
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Input Manual / Cari Barang',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Masukkan SKU / S/N...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            fillColor: const Color(0xFF2A2A2A),
                            filled: true,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (val) => _processCode(val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0055FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _processCode(_inputController.text),
                        child: const Text('Cari', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    const cutoutWidth = 250.0;
    const cutoutHeight = 250.0;
    final left = (size.width - cutoutWidth) / 2;
    final top = (size.height - cutoutHeight) / 2;
    
    final cutoutPath = Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, cutoutWidth, cutoutHeight),
        const Radius.circular(16),
      ),
    );
    
    return Path.combine(PathOperation.difference, path, cutoutPath);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
