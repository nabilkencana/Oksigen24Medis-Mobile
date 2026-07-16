import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppColors
// Global color palette for Oksigen24 Medis – medical oxygen POS & management.
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Primary
  static const Color primary      = Color(0xFF0055FF);
  static const Color primaryLight = Color(0xFFE6EEFF);

  // Backgrounds & surfaces
  static const Color background = Color(0xFFF4F6F9);
  static const Color surface    = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary   = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF777777);

  // Border
  static const Color border = Color(0xFFE0E0E0);

  // Semantic – success
  static const Color success      = Color(0xFF10B981);
  static const Color successLight = Color(0xFFE6F4EA);

  // Semantic – warning
  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3D6);

  // Semantic – error
  static const Color error      = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFCE8E6);
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTextStyles
// All styles use GoogleFonts.inter (geometric sans-serif).
// kpiNumber & priceText use tabular figures for stable column widths.
// ─────────────────────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  // ── Headings ──────────────────────────────────────────────────────────────
  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // ── Body ──────────────────────────────────────────────────────────────────
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  // ── Numeric / financial ──────────────────────────────────────────────────
  /// KPI dashboard numbers – tabular figures prevent layout shifts on update.
  static TextStyle get kpiNumber => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Inline price display – bold primary blue, tabular for list alignment.
  static TextStyle get priceText => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// AppThemeData
// Exposes a Material 3 ThemeData wired to AppColors & AppTextStyles.
// ─────────────────────────────────────────────────────────────────────────────
class AppThemeData {
  AppThemeData._();

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      // ── Scaffold ──────────────────────────────────────────────────────────
      scaffoldBackgroundColor: AppColors.background,

      // ── Color scheme ──────────────────────────────────────────────────────
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        onPrimary: AppColors.surface,
        primaryContainer: AppColors.primaryLight,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        outline: AppColors.border,
        error: AppColors.error,
        onError: AppColors.surface,
      ),

      // ── AppBar – white surface, zero elevation ─────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h3,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      // ── Text theme – full Inter seed + named style overrides ──────────
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge:  AppTextStyles.h1,
        displayMedium: AppTextStyles.h2,
        displaySmall:  AppTextStyles.h3,
        headlineLarge:  AppTextStyles.h1,
        headlineMedium: AppTextStyles.h2,
        headlineSmall:  AppTextStyles.h3,
        titleLarge:  AppTextStyles.h3,
        titleMedium: AppTextStyles.bodyLarge,
        titleSmall:  AppTextStyles.bodyMedium,
        bodyLarge:   AppTextStyles.bodyLarge,
        bodyMedium:  AppTextStyles.bodyMedium,
        bodySmall:   AppTextStyles.caption,
        labelLarge:  AppTextStyles.bodyLarge,
        labelMedium: AppTextStyles.bodyMedium,
        labelSmall:  AppTextStyles.caption,
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Elevated button ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          elevation: 0,
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // ── Outlined button ───────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // ── Text button ───────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // ── Input decoration ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle:  AppTextStyles.bodyMedium,
        labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // ── Bottom navigation bar ─────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: AppTextStyles.caption,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
