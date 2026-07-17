import 'dart:async';
import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart'; // Aktifkan jika diperlukan

class SplashScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;

  const SplashScreen({
    super.key,
    required this.onInitializationComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();

    // Selesaikan splash screen setelah 2.5 detik
    Timer(const Duration(milliseconds: 2500), () {
      widget.onInitializationComplete();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0055FF); 
    const Color textDark = Color(0xFF111827); 
    const Color textGrey = Color(0xFF6B7280); 

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Color(0xFFF3F4F6), 
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Lingkaran dekoratif latar belakang
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryBlue.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryBlue.withOpacity(0.03),
                ),
              ),
            ),
            
            // Konten Utama
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // GANTI ICON DENGAN GAMBAR LOGO
                  Hero(
                    tag: 'app_logo', // Opsional: bagus jika ada animasi transisi ke halaman login
                    child: Image.asset(
                      'assets/images/logo-removebg-preview.png',
                      width: 300, // Sesuaikan ukurannya di sini
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                  
                  // App Title
                  const Text(
                    'Oksigen Medis 24 Jam',
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.w800, 
                      color: textDark, 
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Tagline
                  const Text(
                    'POS & Cylinder Management System',
                    style: TextStyle(
                      fontSize: 13,
                      color: textGrey, 
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Spinner
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.0,
                      color: primaryBlue, 
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom footer versioning
            const Positioned(
              bottom: 32,
              child: Column(
                children: [
                  Text(
                    'Oksigen Medis 24 Jam',
                    style: TextStyle(
                      color: textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'v2.4.1 (Stable Build)',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF), 
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}