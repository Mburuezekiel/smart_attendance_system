// lib/core/theme/theme_controller.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ThemeController — singleton that persists + exposes the current ThemeMode
// ─────────────────────────────────────────────────────────────────────────────

class ThemeController {
  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal();

  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static const _prefsKey = 'theme_mode';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    themeMode.value = switch (saved) {
      'light'  => ThemeMode.light,
      'dark'   => ThemeMode.dark,
      _        => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, switch (mode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    });
  }

  bool get isDark   => themeMode.value == ThemeMode.dark;
  bool get isLight  => themeMode.value == ThemeMode.light;
  bool get isSystem => themeMode.value == ThemeMode.system;
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTheme — call AppTheme.light / AppTheme.dark in your MaterialApp
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  // ── Shared palette ──────────────────────────────────────────────────────────
  static const _green      = Color(0xFF2E7D32);
  static const _greenMid   = Color(0xFF43A047);
  static const _greenLight = Color(0xFFE8F5E9);

  // ─────────────────────────────────────────────────────────────────────────
  // LIGHT
  // ─────────────────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _green,
      brightness: Brightness.light,
      primary: _green,
      secondary: _greenMid,
      surface: Colors.white,
      background: const Color(0xFFF4F6F8),
    ),
    scaffoldBackgroundColor: const Color(0xFFF4F6F8),
    appBarTheme: const AppBarTheme(
      backgroundColor: _green,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _green),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _green,
        side: const BorderSide(color: _green),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _green, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 2)),
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIconColor: Colors.grey.shade500,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade100, thickness: 1, space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _green,
      linearTrackColor: Color(0xFFE0E0E0),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? Colors.white : Colors.white),
      trackColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? _green : Colors.grey.shade300),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1B1B1B),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
    ),
    textTheme: _textTheme(isDark: false),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // DARK
  // ─────────────────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _green,
      brightness: Brightness.dark,
      primary: _greenMid,
      secondary: _green,
      surface: const Color(0xFF1E1E1E),
      background: const Color(0xFF121212),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1A1A1A),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _greenMid,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _greenMid),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _greenMid,
        side: const BorderSide(color: _greenMid),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF333333), width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _greenMid, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2)),
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
      prefixIconColor: Colors.white38,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A2A2A), thickness: 1, space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _greenMid,
      linearTrackColor: Color(0xFF2A2A2A),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith(
          (s) => Colors.white),
      trackColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected)
              ? _greenMid
              : const Color(0xFF444444)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF2A2A2A),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1A1A1A),
    ),
    textTheme: _textTheme(isDark: true),
  );

  // ── Shared text theme ───────────────────────────────────────────────────────
  static TextTheme _textTheme({required bool isDark}) {
    final base = isDark ? Colors.white : const Color(0xFF1B1B1B);
    final muted = isDark ? Colors.white54 : Colors.grey.shade600;
    return TextTheme(
      displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: base),
      displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: base),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: base),
      headlineMedium:TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: base),
      titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: base),
      titleMedium:   TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: base),
      bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: base),
      bodyMedium:    TextStyle(fontSize: 13, color: muted),
      bodySmall:     TextStyle(fontSize: 11, color: muted),
      labelLarge:    TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: base),
    );
  }
}