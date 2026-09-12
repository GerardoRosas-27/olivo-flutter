import 'package:flutter/material.dart';

class OlivoColors {
  static const bg = Color(0xFFFBF7F0);
  static const fg = Color(0xFF2C2A26);
  static const muted = Color(0xFF7A7468);
  static const subtle = Color(0xFF9A9286);
  static const surface = Color(0xFFFFFCF7);
  static const border = Color(0xFFE5DDD0);
  static const olive = Color(0xFF5C6B3A);
  static const primary = Color(0xFF4A5A2E);
  static const primaryFg = Color(0xFFFBF7F0);
  static const danger = Color(0xFF8B3A2F);
  static const warn = Color(0xFF9A6B2D);
}

ThemeData buildOlivoTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: OlivoColors.primary,
      onPrimary: OlivoColors.primaryFg,
      surface: OlivoColors.surface,
      onSurface: OlivoColors.fg,
      error: OlivoColors.danger,
    ),
    scaffoldBackgroundColor: OlivoColors.bg,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: OlivoColors.bg,
      foregroundColor: OlivoColors.fg,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: OlivoColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: OlivoColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OlivoColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OlivoColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OlivoColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OlivoColors.olive, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: OlivoColors.primary,
        foregroundColor: OlivoColors.primaryFg,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: OlivoColors.fg,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: OlivoColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
