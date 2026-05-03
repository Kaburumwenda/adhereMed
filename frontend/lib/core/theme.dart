import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── Theme identifiers ───
enum AppThemeMode { light, dark, ocean, sunset }

// ─── Color palette definition ───
class AppColorPalette {
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color error;
  final Color success;
  final Color warning;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color divider;
  final Brightness brightness;

  const AppColorPalette({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.error,
    required this.success,
    required this.warning,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.divider,
    required this.brightness,
  });
}

// ─── 4 palettes ───
const _lightPalette = AppColorPalette(
  primary: Color(0xFF0D9488),
  primaryLight: Color(0xFF5EEAD4),
  primaryDark: Color(0xFF0F766E),
  secondary: Color(0xFF6366F1),
  background: Color(0xFFF8FAFC),
  surface: Colors.white,
  error: Color(0xFFEF4444),
  success: Color(0xFF22C55E),
  warning: Color(0xFFF59E0B),
  textPrimary: Color(0xFF1E293B),
  textSecondary: Color(0xFF64748B),
  border: Color(0xFFE2E8F0),
  divider: Color(0xFFF1F5F9),
  brightness: Brightness.light,
);

const _darkPalette = AppColorPalette(
  primary: Color(0xFF2DD4BF),
  primaryLight: Color(0xFF5EEAD4),
  primaryDark: Color(0xFF14B8A6),
  secondary: Color(0xFF818CF8),
  background: Color(0xFF0F172A),
  surface: Color(0xFF1E293B),
  error: Color(0xFFF87171),
  success: Color(0xFF4ADE80),
  warning: Color(0xFFFBBF24),
  textPrimary: Color(0xFFF1F5F9),
  textSecondary: Color(0xFF94A3B8),
  border: Color(0xFF334155),
  divider: Color(0xFF1E293B),
  brightness: Brightness.dark,
);

const _oceanPalette = AppColorPalette(
  primary: Color(0xFF0284C7),
  primaryLight: Color(0xFF7DD3FC),
  primaryDark: Color(0xFF0369A1),
  secondary: Color(0xFF8B5CF6),
  background: Color(0xFFF0F9FF),
  surface: Colors.white,
  error: Color(0xFFEF4444),
  success: Color(0xFF059669),
  warning: Color(0xFFF59E0B),
  textPrimary: Color(0xFF0C4A6E),
  textSecondary: Color(0xFF64748B),
  border: Color(0xFFBAE6FD),
  divider: Color(0xFFE0F2FE),
  brightness: Brightness.light,
);

const _sunsetPalette = AppColorPalette(
  primary: Color(0xFFDB2777),
  primaryLight: Color(0xFFF9A8D4),
  primaryDark: Color(0xFFBE185D),
  secondary: Color(0xFFF97316),
  background: Color(0xFFFFF1F2),
  surface: Colors.white,
  error: Color(0xFFDC2626),
  success: Color(0xFF16A34A),
  warning: Color(0xFFEAB308),
  textPrimary: Color(0xFF1C1917),
  textSecondary: Color(0xFF78716C),
  border: Color(0xFFFECDD3),
  divider: Color(0xFFFFE4E6),
  brightness: Brightness.light,
);

AppColorPalette _paletteFor(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return _lightPalette;
    case AppThemeMode.dark:
      return _darkPalette;
    case AppThemeMode.ocean:
      return _oceanPalette;
    case AppThemeMode.sunset:
      return _sunsetPalette;
  }
}

// ─── Mutable AppColors that all existing code references ───
class AppColors {
  AppColors._();

  static AppColorPalette _p = _darkPalette;

  static void _apply(AppColorPalette palette) => _p = palette;

  static Color get primary => _p.primary;
  static Color get primaryLight => _p.primaryLight;
  static Color get primaryDark => _p.primaryDark;
  static Color get secondary => _p.secondary;
  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get error => _p.error;
  static Color get success => _p.success;
  static Color get warning => _p.warning;
  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get border => _p.border;
  static Color get divider => _p.divider;
}

// ─── Theme provider ───
const _themeStorageKey = 'app_theme_mode';
const _storage = FlutterSecureStorage();

final appThemeModeProvider =
    StateNotifierProvider<AppThemeModeNotifier, AppThemeMode>(
        (ref) => AppThemeModeNotifier());

class AppThemeModeNotifier extends StateNotifier<AppThemeMode> {
  AppThemeModeNotifier() : super(AppThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _themeStorageKey);
    if (saved != null) {
      final mode = AppThemeMode.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => AppThemeMode.dark);
      state = mode;
      AppColors._apply(_paletteFor(mode));
    } else {
      AppColors._apply(_paletteFor(AppThemeMode.dark));
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    AppColors._apply(_paletteFor(mode));
    await _storage.write(key: _themeStorageKey, value: mode.name);
  }
}

// ─── ThemeData builder ───
class AppTheme {
  AppTheme._();

  static ThemeData buildTheme(AppThemeMode mode) {
    final p = _paletteFor(mode);
    AppColors._apply(p);

    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorSchemeSeed: p.primary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      textTheme: GoogleFonts.interTextTheme(
          p.brightness == Brightness.dark
              ? ThemeData.dark().textTheme
              : base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: BorderSide(color: p.primary),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Legacy accessor — returns the current light theme.
  static ThemeData get light => buildTheme(AppThemeMode.light);
}
