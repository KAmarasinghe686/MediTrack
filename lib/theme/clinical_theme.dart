import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Palette ────────────────────────────────────────────────────────────────

abstract final class ClinicalPalette {
  // ── Light palette (Health Connect) ──
  static const navy       = Color(0xFF173F5F);
  static const teal       = Color(0xFF14B8A6);
  static const tealSoft   = Color(0xFFD7F5F0);
  static const canvas     = Color(0xFFF8F8F3);
  static const surface    = Colors.white;
  static const outline    = Color(0xFFE2E8F0);
  static const ink        = Color(0xFF1E293B);
  static const muted      = Color(0xFF64748B);
  static const success    = Color(0xFF10B981);
  static const danger     = Color(0xFFEF4444);

  // ── Dark palette ──
  static const darkCanvas    = Color(0xFF1E2E40); // Medium blue instead of pitch black
  static const darkSurface   = Color(0xFF25374D);
  static const darkCard      = Color(0xFF2C3E55);
  static const darkOutline   = Color(0xFF3F546E);
  static const darkInk       = Color(0xFFF8FAFC);
  static const darkMuted     = Color(0xFF94A3B8);
  static const darkTeal      = Color(0xFF5EEAD4);
}

// ─── Theme Manager (singleton ChangeNotifier) ───────────────────────────────

class ThemeManager extends ChangeNotifier {
  ThemeManager._();
  static final ThemeManager instance = ThemeManager._();

  static const _key = 'theme_mode';
  static const _textScaleKey = 'text_scale';
  static const _languageKey = 'app_language';
  ThemeMode _mode = ThemeMode.light;
  double _textScale = 1.0;
  String _languageCode = 'en';
  ThemeMode get mode => _mode;
  double get textScale => _textScale;
  String get languageCode => _languageCode;

  bool get isDark => _mode == ThemeMode.dark;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'dark') {
      _mode = ThemeMode.dark;
    } else {
      _mode = ThemeMode.light;
    }
    _textScale = prefs.getDouble(_textScaleKey) ?? 1.0;
    final storedLanguage = prefs.getString(_languageKey);
    _languageCode = const {'en', 'si', 'ta'}.contains(storedLanguage)
        ? storedLanguage!
        : 'en';
    notifyListeners();
  }

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isDark ? 'dark' : 'light');
  }

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isDark ? 'dark' : 'light');
  }

  Future<void> setTextScale(double value) async {
    _textScale = value.clamp(0.9, 1.4).toDouble();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, _textScale);
  }

  Future<void> setLanguage(String languageCode) async {
    if (!const {'en', 'si', 'ta'}.contains(languageCode)) return;
    _languageCode = languageCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, _languageCode);
  }
}

// ─── Theme Definitions ──────────────────────────────────────────────────────

abstract final class ClinicalTheme {
  // ════════════════════════════════════════════════════════════════════════════
  //  LIGHT
  // ════════════════════════════════════════════════════════════════════════════
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: ClinicalPalette.teal,
      onPrimary: Colors.white,
      secondary: ClinicalPalette.navy,
      onSecondary: Colors.white,
      surface: ClinicalPalette.surface,
      onSurface: ClinicalPalette.ink,
      outline: ClinicalPalette.outline,
    );

    final underlineBorder = UnderlineInputBorder(
      borderSide: const BorderSide(color: ClinicalPalette.outline, width: 1.5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ClinicalPalette.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: ClinicalPalette.canvas,
        foregroundColor: ClinicalPalette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ClinicalPalette.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: ClinicalPalette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ClinicalPalette.outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ClinicalPalette.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(44, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999), // Pill shape
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ClinicalPalette.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999), // Pill shape
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 15),
        border: underlineBorder,
        enabledBorder: underlineBorder,
        focusedBorder: underlineBorder.copyWith(
          borderSide: const BorderSide(color: ClinicalPalette.teal, width: 2),
        ),
        errorBorder: underlineBorder.copyWith(
          borderSide: const BorderSide(color: ClinicalPalette.danger),
        ),
        labelStyle: const TextStyle(color: ClinicalPalette.muted, fontSize: 14, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: ClinicalPalette.muted, fontSize: 14),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ClinicalPalette.ink,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: ClinicalPalette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ClinicalPalette.tealSoft,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? ClinicalPalette.navy
                : ClinicalPalette.muted,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  DARK
  // ════════════════════════════════════════════════════════════════════════════
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: ClinicalPalette.darkTeal,
      onPrimary: Colors.white,
      secondary: ClinicalPalette.darkTeal,
      onSecondary: Colors.white,
      tertiary: Color(0xFF4CAF7D),
      onTertiary: Colors.white,
      error: Color(0xFFEF5350),
      onError: Colors.white,
      surface: ClinicalPalette.darkSurface,
      onSurface: ClinicalPalette.darkInk,
      outline: ClinicalPalette.darkOutline,
    );

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ClinicalPalette.darkOutline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: ClinicalPalette.darkCanvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: ClinicalPalette.darkSurface,
        foregroundColor: ClinicalPalette.darkInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ClinicalPalette.darkInk,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: ClinicalPalette.darkCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: ClinicalPalette.darkOutline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ClinicalPalette.darkTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ClinicalPalette.darkCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(
              color: ClinicalPalette.darkTeal, width: 1.5),
        ),
        errorBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: Color(0xFFEF5350)),
        ),
        labelStyle: const TextStyle(color: ClinicalPalette.darkMuted),
        hintStyle: const TextStyle(color: ClinicalPalette.darkMuted),
      ),
      dividerTheme: const DividerThemeData(
        color: ClinicalPalette.darkOutline,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ClinicalPalette.darkCard,
        contentTextStyle: const TextStyle(color: ClinicalPalette.darkInk),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: ClinicalPalette.darkOutline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: ClinicalPalette.darkSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ClinicalPalette.darkTeal.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? ClinicalPalette.darkTeal
                : ClinicalPalette.darkMuted,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
