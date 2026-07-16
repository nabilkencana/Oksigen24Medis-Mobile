import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class TransactionScannerScreen extends StatefulWidget {
  const TransactionScannerScreen({super.key});

  @override
  State<TransactionScannerScreen> createState() => _TransactionScannerScreenState();
}

class _TransactionScannerScreenState extends State<TransactionScannerScreen> with SingleTickerProviderStateMixin {
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

  void _submitCode(String code) {
    if (code.trim().isEmpty) return;
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });
    Navigator.of(context).pop(code.trim());
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
                    _submitCode(code);
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
                          onSubmitted: (val) => _submitCode(val),
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
                        onPressed: () => _submitCode(_inputController.text),
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
