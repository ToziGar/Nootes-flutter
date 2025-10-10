import 'package:flutter/material.dart';
import 'color_utils.dart';

/// Paleta de colores moderna y mejorada de la aplicación
class AppColors {
  // === COLORES PRIMARIOS MODERNOS ===
  
  // Azul aurora (paleta consistente con AppTheme)
  static const Color primary = Color(0xFF4C6EF5);        // Azul aurora
  static const Color primaryDark = Color(0xFF364FC7);    // Azul profundo
  static const Color primaryLight = Color(0xFF91A7FF);   // Azul lavanda

  // Acentos complementarios luminosos
  static const Color secondary = Color(0xFF2FD6C6);      // Turquesa vibrante
  static const Color secondaryLight = Color(0xFF70E7D9); // Turquesa claro
  static const Color accent = Color(0xFFFF8A65);         // Coral melocotón
  static const Color success = Color(0xFF2ECC71);        // Verde éxito
  static const Color warning = Color(0xFFF4B947);        // Oro cálido
  static const Color error = Color(0xFFFF6B6B);          // Rojo fresco
  static const Color info = Color(0xFF5AC8FA);           // Azul cielo

  // === GRADIENTES MODERNOS ===
  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6379FF), Color(0xFF4C6EF5), Color(0xFF38D9A9)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF7F9FF), Color(0xFFEFF3FF), Color(0xFFF9FEFF)],
  );

  // === TEMA CLARO MEJORADO ===
  
  static const Color background = Color(0xFFF5F7FF);     // Azul hielo cálido
  static const Color surface = Color(0xFFFFFFFF);        // Blanco puro
  static const Color surfaceMuted = Color(0xFFF0F4FF);   // Blanco azulado
  static const Color surfaceElevated = Color(0xFFFFFFFF); // Superficie elevada
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color.fromARGB(255, 197, 197, 197);
  static const Color onSurface = Color.fromARGB(255, 163, 163, 163);      // Carbón suave
  static const Color onBackground = Color.fromARGB(255, 181, 181, 181);

  // === TEMA OSCURO MEJORADO ===
  
  static const Color darkBackground = Color(0xFF0F172A);     // Azul noche
  static const Color darkSurface = Color(0xFFF8F9FA);        // Blanco grisáceo suave
  static const Color darkSurfaceMuted = Color(0xFF1F2A44);   // Superficie elevada
  static const Color darkSurfaceOverlay = Color(0x4025367B); // Overlay translúcido
  static const Color darkOnPrimary = Color(0xFFFFFFFF);
  static const Color darkOnSecondary = Color(0xFF042F2F);
  static const Color darkOnSurface = Color(0xFFE3E8FF);      // Blanco suave
  static const Color darkOnBackground = Color(0xFFE4E9FF);

  // === COLORES DEL EDITOR MEJORADOS ===
  
  static const Color editorBackground = Color(0xFFF7F9FF);   // Fondo suave
  static const Color editorForeground = Color(0xFF1F2937);   // Texto principal
  static const Color editorLineNumber = Color(0xFF9AA5B1);   // Números de línea
  static const Color editorSelection = Color(0xFF4C6EF5);    // Selección
  static const Color editorCursor = Color(0xFF4C6EF5);       // Cursor
  
  // Editor modo oscuro
  static const Color darkEditorBackground = Color(0xFF101C34);
  static const Color darkEditorForeground = Color(0xFFE3E8FF);
  static const Color darkEditorLineNumber = Color(0xFF7683A6);
  static const Color darkEditorSelection = Color(0xFF2C3F91);
  static const Color darkEditorCursor = Color(0xFF91A7FF);

  // === COLORES PARA CATEGORÍAS ===
  
  static const List<Color> categoryColors = [
  Color(0xFF4C6EF5),  // Azul aurora
  Color(0xFF2FD6C6),  // Turquesa vibrante
  Color(0xFFFF8A65),  // Coral melocotón
  Color(0xFF5AC8FA),  // Azul cielo
  Color(0xFF2ECC71),  // Verde esmeralda
  Color(0xFFF4B947),  // Oro cálido
  Color(0xFFFF99BB),  // Rosa pastel
  Color(0xFF4361EE),  // Azul índigo
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