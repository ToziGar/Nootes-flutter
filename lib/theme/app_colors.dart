import 'package:flutter/material.dart';
import 'color_utils.dart';

/// Paleta de colores moderna y mejorada de la aplicación
class AppColors {
  // === COLORES PRIMARIOS MODERNOS ===
  
  // Azul moderno con gradiente
  static const Color primary = Color(0xFF6C5CE7);        // Púrpura vibrante
  static const Color primaryDark = Color(0xFF5A4FCF);    // Púrpura oscuro
  static const Color primaryLight = Color(0xFF8B7FF8);   // Púrpura claro
  
  // Acentos complementarios
  static const Color secondary = Color(0xFF00CEC9);      // Turquesa moderno
  static const Color secondaryLight = Color(0xFF55E6E1); // Turquesa claro
  static const Color accent = Color(0xFFFF7675);         // Rosa coral
  static const Color success = Color(0xFF00B894);        // Verde éxito
  static const Color warning = Color(0xFFF39C12);        // Naranja advertencia
  static const Color error = Color(0xFFE74C3C);          // Rojo error
  static const Color info = Color(0xFF74B9FF);           // Azul información

  // === GRADIENTES MODERNOS ===
  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5CE7), Color(0xFF74B9FF)],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00CEC9), Color(0xFF55E6E1)],
  );

  // === TEMA CLARO MEJORADO ===
  
  static const Color background = Color(0xFFFAFBFC);     // Blanco cálido
  static const Color surface = Color(0xFFFFFFFF);       // Blanco puro
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF2D3436);     // Negro suave
  static const Color onBackground = Color(0xFF2D3436);

  // === TEMA OSCURO MEJORADO ===
  
  static const Color darkBackground = Color(0xFF0D1117);     // Negro azulado
  static const Color darkSurface = Color(0xFF161B22);       // Gris oscuro
  static const Color darkOnPrimary = Color(0xFFFFFFFF);
  static const Color darkOnSecondary = Color(0xFFFFFFFF);
  static const Color darkOnSurface = Color(0xFFF0F6FC);     // Blanco suave
  static const Color darkOnBackground = Color(0xFFF0F6FC);

  // === COLORES DEL EDITOR MEJORADOS ===
  
  static const Color editorBackground = Color(0xFFFAFBFC);   // Fondo suave
  static const Color editorForeground = Color(0xFF2D3436);   // Texto principal
  static const Color editorLineNumber = Color(0xFF95A5A6);   // Números de línea
  static const Color editorSelection = Color(0xFF6C5CE7);    // Selección
  static const Color editorCursor = Color(0xFF6C5CE7);       // Cursor
  
  // Editor modo oscuro
  static const Color darkEditorBackground = Color(0xFF0D1117);
  static const Color darkEditorForeground = Color(0xFFF0F6FC);
  static const Color darkEditorLineNumber = Color(0xFF7D8590);
  static const Color darkEditorSelection = Color(0xFF264F78);
  static const Color darkEditorCursor = Color(0xFF8B7FF8);

  // === COLORES PARA CATEGORÍAS ===
  
  static const List<Color> categoryColors = [
    Color(0xFF6C5CE7),  // Púrpura
    Color(0xFF00CEC9),  // Turquesa
    Color(0xFFFF7675),  // Rosa coral
    Color(0xFF74B9FF),  // Azul
    Color(0xFF00B894),  // Verde
    Color(0xFFF39C12),  // Naranja
    Color(0xFFE84393),  // Rosa
    Color(0xFF0984E3),  // Azul oscuro
  ];

  // === SHADOWS Y EFECTOS ===
  
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x10000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];
  
  static const List<BoxShadow> mediumShadow = [
    BoxShadow(
      color: Color(0x15000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
  
  static const List<BoxShadow> glowShadow = [
    BoxShadow(
      color: Color(0x306C5CE7),
      blurRadius: 20,
      offset: Offset(0, 0),
    ),
  ];

  /// Obtiene un color de categoría por índice
  static Color getCategoryColor(int index) {
    return categoryColors[index % categoryColors.length];
  }

  /// Obtiene el color primario con opacidad
  static Color primaryWithOpacity(double opacity) {
    return primary.withOpacityCompat(opacity);
  }

  /// Obtiene el color secundario con opacidad
  static Color secondaryWithOpacity(double opacity) {
    return secondary.withOpacityCompat(opacity);
  }

  /// Obtiene los colores del editor según el tema
  static EditorColors getEditorColors(ThemeMode themeMode, Brightness brightness) {
    final isDark = themeMode == ThemeMode.dark || 
                   (themeMode == ThemeMode.system && brightness == Brightness.dark);
    
    return EditorColors(
      background: isDark ? darkEditorBackground : editorBackground,
      foreground: isDark ? darkEditorForeground : editorForeground,
      lineNumber: isDark ? darkEditorLineNumber : editorLineNumber,
      selection: isDark ? darkEditorSelection : editorSelection,
      cursor: isDark ? darkEditorCursor : editorCursor,
    );
  }
}

/// Colores específicos del editor
class EditorColors {
  final Color background;
  final Color foreground;
  final Color lineNumber;
  final Color selection;
  final Color cursor;

  const EditorColors({
    required this.background,
    required this.foreground,
    required this.lineNumber,
    required this.selection,
    required this.cursor,
  });
}