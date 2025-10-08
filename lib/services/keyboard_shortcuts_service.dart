import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Servicio para manejar shortcuts de teclado
class KeyboardShortcutsService {
  /// Crear LogicalKeySet para Ctrl+F (búsqueda)
  static LogicalKeySet get search => LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyF,
  );
  
  /// Crear LogicalKeySet para Ctrl+N (nueva nota)
  static LogicalKeySet get newNote => LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyN,
  );
  
  /// Crear LogicalKeySet para Ctrl+S (guardar)
  static LogicalKeySet get save => LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyS,
  );
  
  /// Crear LogicalKeySet para Ctrl+K (búsqueda avanzada)
  static LogicalKeySet get advancedSearch => LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyK,
  );
  
  /// Crear LogicalKeySet para Ctrl+B (toggle sidebar)
  static LogicalKeySet get toggleSidebar => LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyB,
  );
  
  /// Crear LogicalKeySet para Ctrl+Shift+F (modo focus)
  static LogicalKeySet get focusMode => LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.keyF,
  );
  
  /// Crear LogicalKeySet para Ctrl+/ (toggle modo compacto)
  static LogicalKeySet get toggleCompactMode => LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.slash,
  );
  
  /// Escape para cerrar diálogos
  static LogicalKeySet get escape => LogicalKeySet(
    LogicalKeyboardKey.escape,
  );
  
  /// Crear mapa de shortcuts con sus acciones
  static Map<ShortcutActivator, Intent> getShortcuts() {
    return {
      search: const SearchIntent(),
      newNote: const NewNoteIntent(),
      save: const SaveIntent(),
      advancedSearch: const AdvancedSearchIntent(),
      toggleSidebar: const ToggleSidebarIntent(),
      focusMode: const FocusModeIntent(),
      toggleCompactMode: const ToggleCompactModeIntent(),
    };
  }
  
  /// Obtener descripción de un shortcut para mostrar en UI
  static String getShortcutLabel(String action) {
    switch (action) {
      case 'search':
        return 'Ctrl+F';
      case 'newNote':
        return 'Ctrl+N';
      case 'save':
        return 'Ctrl+S';
      case 'advancedSearch':
        return 'Ctrl+K';
      case 'toggleSidebar':
        return 'Ctrl+B';
      case 'focusMode':
        return 'Ctrl+Shift+F';
      case 'toggleCompactMode':
        return 'Ctrl+/';
      case 'escape':
        return 'Esc';
      default:
        return '';
    }
  }
}

// Intents para los shortcuts
class SearchIntent extends Intent {
  const SearchIntent();
}

class NewNoteIntent extends Intent {
  const NewNoteIntent();
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class AdvancedSearchIntent extends Intent {
  const AdvancedSearchIntent();
}

class ToggleSidebarIntent extends Intent {
  const ToggleSidebarIntent();
}

class FocusModeIntent extends Intent {
  const FocusModeIntent();
}

class ToggleCompactModeIntent extends Intent {
  const ToggleCompactModeIntent();
}
