import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

export 'theme_provider.dart';

const _seed = Color(0xFF0D9488); // teal-600

class AppTheme {
  static ThemeData light() {
    final base = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light);
    final cs = base.copyWith(
      primary: const Color(0xFF0D9488),
      secondary: const Color(0xFF6366F1),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF1E293B),
      onSurfaceVariant: const Color(0xFF64748B),
      outline: const Color(0xFFE2E8F0),
      outlineVariant: const Color(0xFFE2E8F0),
      error: const Color(0xFFEF4444),
    );
    return _build(cs).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    );
  }

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);
    final cs = base.copyWith(
      primary: const Color(0xFF2DD4BF),
      secondary: const Color(0xFF818CF8),
      surface: const Color(0xFF2D2D2D),
      surfaceContainerHighest: const Color(0xFF383838),
      onSurface: const Color(0xFFE4E4E4),
      onSurfaceVariant: const Color(0xFF9E9E9E),
      outline: const Color(0xFF3D3D3D),
      outlineVariant: const Color(0xFF3D3D3D),
      error: const Color(0xFFF87171),
    );
    return _build(cs).copyWith(
      scaffoldBackgroundColor: const Color(0xFF202020),
    );
  }

  static ThemeData _build(ColorScheme cs) {
    final txt = GoogleFonts.interTextTheme(
      cs.brightness == Brightness.light ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: txt,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: cs.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
