import 'package:flutter/material.dart';

class AppColors {
  // Colores principales
  static const primary = Color(0xFF6C5CE7);
  static const primaryLight = Color(0xFF9F7AEA);
  static const secondary = Color(0xFF00CEC9);
  static const accent = Color(0xFFFF7675);
  
  // Estados
  static const success = Color(0xFF00B894);
  static const warning = Color(0xFFF39C12);
  static const danger = Color(0xFFE74C3C);
  static const info = Color(0xFF74B9FF);
  
  // Colores específicos (valores seguros)
  static const note = Color(0xFF6C5CE7);
  static const activeNote = Color(0xFF6C5CE7);
  
  // Tema oscuro
  static const bg = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const surfaceLight = Color(0xFF21262D);
  static const surfaceHover = Color(0xFF30363D);
  static const card = Color(0xFF161B22);
  static const textPrimary = Color(0xFFF0F6FC);
  static const textSecondary = Color(0xFFB1BAC4);
  static const textMuted = Color(0xFF7D8590);
  static const borderColor = Color(0xFF30363D);
  static const divider = Color(0xFF21262D);
  
  // Tema claro
  static const bgLight = Color(0xFFFAFBFC);
  static const surfaceLight2 = Color(0xFFFFFFFF);
  static const surfaceLight3 = Color(0xFFF8F9FA);
  static const cardLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF1F2937);
  static const textSecondaryLight = Color(0xFF6B7280);
  static const textMutedLight = Color(0xFF9CA3AF);
  static const borderColorLight = Color(0xFFE5E7EB);
  static const dividerLight = Color(0xFFE5E7EB);
  
  // Espaciado
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space48 = 48.0;
  
  // Radios
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 20.0;
}

class AppTheme {
  // Gradientes simplificados
  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5CE7), Color(0xFF9F7AEA)],
  );
  
  // Sombras simplificadas  
  static const shadowMd = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 6.0,
      offset: Offset(0, 2),
    ),
  ];
  
  static const shadowXl = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 25.0,
      offset: Offset(0, 10),
    ),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surfaceLight2,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
      ),
      scaffoldBackgroundColor: AppColors.bgLight,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.bg,
    );
  }
}
