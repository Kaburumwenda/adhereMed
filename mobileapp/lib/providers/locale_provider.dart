import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _load();
  }

  static const _key = 'app_locale';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) {
      // If the saved locale is no longer supported, clear it
      final supported = AppLocales.supported.map((l) => l.code).toSet();
      if (supported.contains(code)) {
        state = Locale(code);
      } else {
        await prefs.remove(_key);
      }
    }
  }

  Future<void> set(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }

  Future<void> clear() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

/// All supported locales with their display names (in native script).
class AppLocales {
  static const supported = [
    _LocaleInfo('en', 'English', '🇬🇧'),
    _LocaleInfo('ar', 'العربية', '🇸🇦'),
    _LocaleInfo('fr', 'Français', '🇫🇷'),
    _LocaleInfo('hi', 'हिंदी', '🇮🇳'),
    _LocaleInfo('zh', '中文 (简体)', '🇨🇳'),
    _LocaleInfo('es', 'Español', '🇪🇸'),
    _LocaleInfo('am', 'አማርኛ', '🇪🇹'),
    _LocaleInfo('de', 'Deutsch', '🇩🇪'),
    _LocaleInfo('pt', 'Português', '🇧🇷'),
  ];
}

class _LocaleInfo {
  const _LocaleInfo(this.code, this.name, this.flag);
  final String code;
  final String name;
  final String flag;
}
