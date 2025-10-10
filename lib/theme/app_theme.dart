import 'package:flutter/material.dart';

/// Sistema de diseño profesional y moderno para Nootes
class AppColors {
  // === PALETA PRINCIPAL RENOVADA ===
  static const primary = Color(0xFF4C6EF5);        // Azul aurora
  static const primaryDark = Color(0xFF364FC7);    // Azul profundo
  static const primaryLight = Color(0xFF91A7FF);   // Azul lavanda

  static const secondary = Color(0xFF2FD6C6);      // Turquesa vibrante
  static const accent = Color(0xFFFF8A65);         // Coral melocotón

  // === ESTADOS CON COLORES MODERNOS ===
  static const success = Color(0xFF2ECC71);        // Verde éxito
  static const warning = Color(0xFFF4B947);        // Oro cálido
  static const danger = Color(0xFFFF6B6B);         // Rojo fresco
  static const recording = Color(0xFFFF6B6B);      // Grabación
  static const info = Color(0xFF5AC8FA);           // Azul información

  // === TEMA OSCURO MEJORADO ===
  static const bg = Color(0xFFFAFAFA);             // Fondo blanco grisáceo muy suave
  static const surface = Color(0xFFF8F9FA);        // Superficie principal - blanco grisáceo
  static const surfaceLight = Color(0xFFFFFFFF);   // Superficie elevada - blanco puro
  static const surfaceHover = Color(0xFFF1F3F4);   // Hover state - gris muy claro
  static const card = Color(0xFFFFFFFF);           // Cards - blanco puro
  static const panel = Color(0xFFF8F9FA);          // Paneles - blanco grisáceo
  static const surfaceOverlay = Color(0x4025367B); // Overlay translúcido
  static const darkOnSecondary = Color(0xFF042F2F);

  // Editor tema claro
  static const editorBg = Color(0xFFFFFFFF);       // Fondo editor - blanco puro
  static const previewBg = Color(0xFFF8F9FA);      // Vista previa - blanco grisáceo

  // Texto optimizado para tema claro
  static const textPrimary = Color(0xFF1A202C);    // Texto principal - negro suave
  static const textSecondary = Color(0xFF4A5568);  // Texto secundario - gris oscuro
  static const textMuted = Color(0xFF718096);      // Texto apagado - gris medio

  // Elementos UI
  static const borderColor = Color(0xFFE2E8F0);    // Bordes - gris muy claro
  static const divider = Color(0xFF1E2743);        // Divisores
  static const glass = Color.fromRGBO(76, 110, 245, 0.12); // Efecto vidrio

  // === TEMA CLARO RENOVADO ===
  static const bgLight = Color(0xFFF5F7FF);        // Fondo principal claro
  static const surfaceLight2 = Color(0xFFFFFFFF);  // Superficie blanca
  static const surfaceLight3 = Color(0xFFF0F4FF);  // Superficie azulada
  static const surfaceHoverLight = Color(0xFFE4EBFF); // Hover claro
  static const cardLight = Color(0xFFFFFFFF);      // Cards claros
  static const panelLight = Color(0xFFF5F7FF);     // Paneles claros
  static const surfaceTint = Color(0xFFE7ECFF);    // Tinte suave

  static const editorBgLight = Color(0xFFF7F9FF);  // Editor claro
  static const previewBgLight = Color(0xFFF6F8FF);

  static const textPrimaryLight = Color(0xFF1F2540);
  static const textSecondaryLight = Color(0xFF4B5563);
  static const textMutedLight = Color(0xFF7A8699);

  static const borderColorLight = Color(0xFFD9E2FF);
  static const dividerLight = Color(0xFFE2E8FF);
  static const glassLight = Color.fromRGBO(76, 110, 245, 0.06);

  // Estados de notas
  static const note = Color(0xFF2FD6C6);
  static const folder = Color(0xFFF4B947);
  static const subfolder = Color(0xFFFF8A65);
  static const activeNote = Color.fromRGBO(76, 110, 245, 0.16);
  static const hover = Color.fromRGBO(255, 255, 255, 0.08);
  static const hoverLight = Color.fromRGBO(76, 110, 245, 0.08);
  static const searchHighlight = Color.fromRGBO(255, 152, 120, 0.28);
  static const matchCount = Color(0xFFEF476F);

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
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        surface: AppColors.surface,
        surfaceTint: AppColors.primary,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),

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

      iconTheme: const IconThemeData(color: AppColors.textSecondary),

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
        shadowColor: Colors.black.withValues(alpha: 0.35),
        surfaceTintColor: AppColors.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
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
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space24, vertical: AppColors.space16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusLg)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.darkOnSecondary,
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space20, vertical: AppColors.space12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
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
        elevation: 8,
        hoverElevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusLg)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        disabledColor: AppColors.surfaceOverlay,
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: AppColors.textSecondary),
        padding: const EdgeInsets.symmetric(horizontal: AppColors.space12, vertical: AppColors.space8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
        side: const BorderSide(color: AppColors.borderColor, width: 1),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppColors.space16, vertical: AppColors.space8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
        tileColor: Colors.transparent,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.14),
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.primary.withValues(alpha: 0.16),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusLg)),
        selectedIconTheme: const IconThemeData(color: Colors.white, size: 24),
        unselectedIconTheme: const IconThemeData(color: AppColors.textMuted, size: 22),
        selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        unselectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textMuted),
        labelType: NavigationRailLabelType.all,
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textSecondary;
          return IconThemeData(color: color, size: states.contains(WidgetState.selected) ? 24 : 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textMuted;
          return TextStyle(fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500, color: color);
        }),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(AppColors.radiusXl),
            bottomRight: Radius.circular(AppColors.radiusXl),
          ),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusXl)),
        ),
        elevation: 16,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppColors.radiusXl)),
        ),
        titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        contentTextStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusLg)),
        insetPadding: const EdgeInsets.symmetric(horizontal: AppColors.space24, vertical: AppColors.space16),
      ),

      tabBarTheme: const TabBarThemeData(
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(borderSide: BorderSide(width: 3, color: Colors.white)),
      ),

      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.all(Colors.white),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.borderColor;
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.surfaceLight;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.borderColor;
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textMuted;
        }),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.borderColor;
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.surfaceLight;
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.6);
          }
          return AppColors.surfaceLight;
        }),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgLight,
      canvasColor: AppColors.bgLight,
      splashFactory: InkSparkle.splashFactory,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        surface: AppColors.surfaceLight2,
        surfaceTint: AppColors.surfaceTint,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Color(0xFF042F2F),
        onTertiary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight, letterSpacing: -0.6, height: 1.2),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight, letterSpacing: -0.5),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),

        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),

        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight),

        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimaryLight, height: 1.6),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textPrimaryLight, height: 1.6),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.5),

        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondaryLight),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMutedLight),
      ),

      iconTheme: const IconThemeData(color: AppColors.textSecondaryLight),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight2,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight, letterSpacing: -0.2),
      ),

      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
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
        fillColor: AppColors.surfaceLight2,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppColors.space16, vertical: AppColors.space16),
        hintStyle: const TextStyle(color: AppColors.textMutedLight),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.borderColorLight, width: 1),
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.borderColorLight, width: 1),
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondaryLight),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space24, vertical: AppColors.space16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusLg)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppColors.space20, vertical: AppColors.space12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusLg)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
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
        elevation: 10,
        hoverElevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusLg)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight3,
        selectedColor: AppColors.primary.withValues(alpha: 0.16),
        disabledColor: AppColors.surfaceTint,
        labelStyle: const TextStyle(color: AppColors.textPrimaryLight, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: AppColors.textSecondaryLight),
        padding: const EdgeInsets.symmetric(horizontal: AppColors.space12, vertical: AppColors.space8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
        side: const BorderSide(color: AppColors.borderColorLight, width: 1),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppColors.space16, vertical: AppColors.space8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
        tileColor: Colors.transparent,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.12),
        iconColor: AppColors.textSecondaryLight,
        textColor: AppColors.textPrimaryLight,
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusLg)),
        selectedIconTheme: const IconThemeData(color: AppColors.primary, size: 24),
        unselectedIconTheme: const IconThemeData(color: AppColors.textMutedLight, size: 22),
        selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
        unselectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textMutedLight),
        labelType: NavigationRailLabelType.all,
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: AppColors.surfaceLight2,
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textSecondaryLight;
          return IconThemeData(color: color, size: states.contains(WidgetState.selected) ? 24 : 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textMutedLight;
          return TextStyle(fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500, color: color);
        }),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surfaceLight2,
        surfaceTintColor: AppColors.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(AppColors.radiusXl),
            bottomRight: Radius.circular(AppColors.radiusXl),
          ),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight2,
        surfaceTintColor: AppColors.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusXl)),
        ),
        elevation: 16,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight2,
        surfaceTintColor: AppColors.surfaceTint,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppColors.radiusXl)),
        ),
        titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
        contentTextStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondaryLight, height: 1.6),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusLg)),
        insetPadding: const EdgeInsets.symmetric(horizontal: AppColors.space24, vertical: AppColors.space16),
      ),

      tabBarTheme: const TabBarThemeData(
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMutedLight,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(borderSide: BorderSide(width: 3, color: AppColors.primary)),
      ),

      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.all(Colors.white),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.borderColorLight;
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.surfaceLight3;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.borderColorLight;
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textMutedLight;
        }),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.borderColorLight;
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.textMutedLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.surfaceLight3;
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.55);
          }
          return AppColors.surfaceLight3;
        }),
      ),
    );
  }

  // Gradientes y sombras
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
