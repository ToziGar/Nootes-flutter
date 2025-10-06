import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF1F1F2B);
  static const panel = Color(0xFF262633);
  static const glass = Color.fromRGBO(255, 255, 255, 0.04);
  static const card = Color(0xFF2C2C3B);
  static const editorBg = Color(0xFF1A1A24);
  static const previewBg = Color.fromRGBO(255, 255, 255, 0.02);
  static const textPrimary = Color(0xFFE1E1E6);
  static const textMuted = Color(0xFF8C8C9E);
  static const accent = Color(0xFF8257E5);
  static const note = Color(0xFF30A5BF);
  static const folder = Color(0xFFE6D72A);
  static const subfolder = Color(0xFFFF9900);
  static const activeNote = Color.fromRGBO(130, 87, 229, 0.25);
  static const searchHighlight = Color.fromRGBO(230, 215, 42, 0.3);
  static const matchCount = Color(0xFFF75A68);
  static const danger = Color(0xFFF75A68);
  static const success = Color(0xFF00B37E);
  static const hover = Color.fromRGBO(255, 255, 255, 0.07);
  static const recording = Color(0xFFF75A68);
  static const borderColor = Color.fromRGBO(255, 255, 255, 0.08);
}

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      primary: AppColors.accent,
      surface: AppColors.panel,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.card,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: AppColors.panel,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: base.dividerTheme.copyWith(color: AppColors.borderColor),
      cardTheme: base.cardTheme.copyWith(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        elevation: 2,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: AppColors.glass,
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.9), width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderColor),
          backgroundColor: AppColors.glass,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
    );
  }
}
