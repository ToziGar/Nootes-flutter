import 'package:flutter/material.dart';

/// Sistema de diseño profesional para Nootes
class AppColors {
  // Paleta principal - Indigo moderno
  static const primary = Color(0xFF6366F1);
  static const primaryDark = Color(0xFF4F46E5);
  static const primaryLight = Color(0xFF818CF8);
  
  static const secondary = Color(0xFF8B5CF6);
  static const accent = Color(0xFF06B6D4);
  
  // Estados
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const recording = Color(0xFFEF4444);
  
  // === TEMA OSCURO ===
  // Superficies con profundidad
  static const bg = Color(0xFF0F0F17);
  static const surface = Color(0xFF1A1A27);
  static const surfaceLight = Color(0xFF242433);
  static const surfaceHover = Color(0xFF2E2E3F);
  static const card = Color(0xFF1E1E2E);
  static const panel = Color(0xFF1A1A27);
  
  // Editor
  static const editorBg = Color(0xFF15151F);
  static const previewBg = Color(0xFF1A1A24);
  
  // Texto jerárquico
  static const textPrimary = Color(0xFFE5E7EB);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted = Color(0xFF6B7280);
  
  // Elementos
  static const borderColor = Color(0xFF374151);
  static const divider = Color(0xFF374151);
  static const glass = Color.fromRGBO(255, 255, 255, 0.05);
  
  // === TEMA CLARO ===
  static const bgLight = Color(0xFFFAFAFA);
  static const surfaceLight2 = Color(0xFFFFFFFF);
  static const surfaceLight3 = Color(0xFFF5F5F5);
  static const surfaceHoverLight = Color(0xFFF0F0F0);
  static const cardLight = Color(0xFFFFFFFF);
  static const panelLight = Color(0xFFF8F9FA);
  
  static const editorBgLight = Color(0xFFFFFFFF);
  static const previewBgLight = Color(0xFFFAFAFA);
  
  static const textPrimaryLight = Color(0xFF1F2937);
  static const textSecondaryLight = Color(0xFF6B7280);
  static const textMutedLight = Color(0xFF9CA3AF);
  
  static const borderColorLight = Color(0xFFE5E7EB);
  static const dividerLight = Color(0xFFE5E7EB);
  static const glassLight = Color.fromRGBO(0, 0, 0, 0.02);
  
  // Estados de notas
  static const note = Color(0xFF06B6D4);
  static const folder = Color(0xFFF59E0B);
  static const subfolder = Color(0xFFFF9900);
  static const activeNote = Color.fromRGBO(99, 102, 241, 0.15);
  static const hover = Color.fromRGBO(255, 255, 255, 0.05);
  static const hoverLight = Color.fromRGBO(0, 0, 0, 0.05);
  static const searchHighlight = Color.fromRGBO(245, 158, 11, 0.25);
  static const matchCount = Color(0xFFEF4444);
  
  // Espaciado grid 8px
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space48 = 48.0;
  
  // Radios
  static const radiusXs = 6.0;
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 20.0;
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.bg,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      
      scaffoldBackgroundColor: AppColors.bg,
      
      // Tipografía profesional
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.5, height: 1.2),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.5),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.6),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
        
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted),
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: -0.2),
      ),
      
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          side: const BorderSide(color: AppColors.borderColor, width: 1),
        ),
      ),
      
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppColors.space16, vertical: AppColors.space16),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space24, vertical: AppColors.space16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space20, vertical: AppColors.space12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space16, vertical: AppColors.space12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderColor),
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space20, vertical: AppColors.space12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
        ),
      ),
      
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          hoverColor: AppColors.surfaceHover,
          padding: const EdgeInsets.all(AppColors.space12),
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
        ),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        hoverElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusLg)),
      ),
      
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: AppColors.space12, vertical: AppColors.space8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
      ),
      
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppColors.space16, vertical: AppColors.space8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
      ),
    );
  }
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.bgLight,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
      ),
      
      scaffoldBackgroundColor: AppColors.bgLight,
      
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight, letterSpacing: -0.5, height: 1.2),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight, letterSpacing: -0.5),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
        
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight),
        
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimaryLight, height: 1.6),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textPrimaryLight, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.5),
        
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimaryLight),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondaryLight),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMutedLight),
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight2,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight, letterSpacing: -0.2),
      ),
      
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          side: const BorderSide(color: AppColors.borderColorLight, width: 1),
        ),
      ),
      
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight3,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppColors.space16, vertical: AppColors.space16),
        hintStyle: const TextStyle(color: AppColors.textMutedLight),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondaryLight),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space24, vertical: AppColors.space16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space20, vertical: AppColors.space12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space16, vertical: AppColors.space12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryLight,
          side: const BorderSide(color: AppColors.borderColorLight),
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space20, vertical: AppColors.space12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
        ),
      ),
      
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondaryLight,
          hoverColor: AppColors.surfaceHoverLight,
          padding: const EdgeInsets.all(AppColors.space12),
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
        ),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        hoverElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusLg)),
      ),
      
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight3,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: const TextStyle(color: AppColors.textPrimaryLight, fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: AppColors.space12, vertical: AppColors.space8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
      ),
      
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppColors.space16, vertical: AppColors.space8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
      ),
    );
  }
  
  // Gradientes modernos
  static const gradientPrimary = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const gradientAccent = LinearGradient(
    colors: [AppColors.secondary, AppColors.accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Sombras profesionales
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> get shadowXl => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
}
