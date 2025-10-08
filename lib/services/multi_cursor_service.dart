import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Servicio para gestionar múltiples cursores en el editor
class MultiCursorService {
  static final MultiCursorService _instance = MultiCursorService._internal();
  factory MultiCursorService() => _instance;
  MultiCursorService._internal();

  final List<TextSelection> _cursors = [];
  bool _isMultiCursorMode = false;
  TextEditingController? _controller;

  /// Obtiene si está en modo multi-cursor
  bool get isMultiCursorMode => _isMultiCursorMode;

  /// Obtiene la lista de cursores
  List<TextSelection> get cursors => _cursors;

  /// Inicializa el servicio con un controlador
  void initialize(TextEditingController controller) {
    _controller = controller;
  }

  /// Activa/desactiva el modo multi-cursor
  void toggleMultiCursorMode() {
    _isMultiCursorMode = !_isMultiCursorMode;
    if (!_isMultiCursorMode) {
      _cursors.clear();
    }
  }

  /// Agrega un cursor en la posición especificada
  void addCursor(int position) {
    if (!_isMultiCursorMode) return;
    
    final selection = TextSelection.collapsed(offset: position);
    if (!_cursors.any((cursor) => cursor.start == position)) {
      _cursors.add(selection);
    }
  }

  /// Agrega cursores en todas las ocurrencias de una palabra
  void addCursorsForWord(String word) {
    if (_controller == null || word.isEmpty) return;
    
    _cursors.clear();
    final text = _controller!.text;
    int index = 0;
    
    while (index < text.length) {
      index = text.indexOf(word, index);
      if (index == -1) break;
      
      _cursors.add(TextSelection(
        baseOffset: index,
        extentOffset: index + word.length,
      ));
      index += word.length;
    }
    
    _isMultiCursorMode = _cursors.isNotEmpty;
  }

  /// Agrega cursores en líneas seleccionadas
  void addCursorsToSelectedLines() {
    if (_controller == null) return;
    
    final text = _controller!.text;
    final selection = _controller!.selection;
    final lines = text.split('\n');
    
    _cursors.clear();
    
    int currentIndex = 0;
    int startLine = 0;
    int endLine = 0;
    
    // Encontrar líneas que contienen la selección
    for (int i = 0; i < lines.length; i++) {
      final lineStart = currentIndex;
      final lineEnd = currentIndex + lines[i].length;
      
      if (selection.start >= lineStart && selection.start <= lineEnd) {
        startLine = i;
      }
      if (selection.end >= lineStart && selection.end <= lineEnd) {
        endLine = i;
      }
      
      currentIndex = lineEnd + 1; // +1 para el \n
    }
    
    // Agregar cursor al final de cada línea
    currentIndex = 0;
    for (int i = 0; i < lines.length; i++) {
      if (i >= startLine && i <= endLine) {
        final lineEnd = currentIndex + lines[i].length;
        _cursors.add(TextSelection.collapsed(offset: lineEnd));
      }
      currentIndex += lines[i].length + 1;
    }
    
    _isMultiCursorMode = _cursors.isNotEmpty;
  }

  /// Inserta texto en todas las posiciones de cursor
  void insertTextAtAllCursors(String text) {
    if (_controller == null || _cursors.isEmpty) return;
    
    // Ordenar cursores por posición (de mayor a menor para no afectar las posiciones)
    _cursors.sort((a, b) => b.start.compareTo(a.start));
    
    String newText = _controller!.text;
    
    for (final cursor in _cursors) {
      if (cursor.start <= newText.length) {
        newText = newText.substring(0, cursor.start) + 
                 text + 
                 newText.substring(cursor.end);
      }
    }
    
    _controller!.text = newText;
    
    // Actualizar posiciones de cursores
    int offset = text.length;
    for (int i = _cursors.length - 1; i >= 0; i--) {
      final oldPosition = _cursors[i].start;
      _cursors[i] = TextSelection.collapsed(offset: oldPosition + offset);
      offset += text.length;
    }
  }

  /// Elimina el carácter anterior en todas las posiciones de cursor
  void backspaceAtAllCursors() {
    if (_controller == null || _cursors.isEmpty) return;
    
    // Ordenar cursores por posición (de mayor a menor)
    _cursors.sort((a, b) => b.start.compareTo(a.start));
    
    String newText = _controller!.text;
    
    for (final cursor in _cursors) {
      if (cursor.start > 0 && cursor.start <= newText.length) {
        newText = newText.substring(0, cursor.start - 1) + 
                 newText.substring(cursor.end);
      }
    }
    
    _controller!.text = newText;
    
    // Actualizar posiciones de cursores
    for (int i = _cursors.length - 1; i >= 0; i--) {
      final oldPosition = _cursors[i].start;
      if (oldPosition > 0) {
        _cursors[i] = TextSelection.collapsed(offset: oldPosition - 1);
      }
    }
  }

  /// Selecciona texto en todas las posiciones de cursor
  void selectAtAllCursors(int startOffset, int endOffset) {
    if (_controller == null || _cursors.isEmpty) return;
    
    for (int i = 0; i < _cursors.length; i++) {
      final cursor = _cursors[i];
      final newStart = (cursor.start + startOffset).clamp(0, _controller!.text.length);
      final newEnd = (cursor.start + endOffset).clamp(0, _controller!.text.length);
      
      _cursors[i] = TextSelection(
        baseOffset: newStart,
        extentOffset: newEnd,
      );
    }
  }

  /// Mueve todos los cursores en una dirección
  void moveAllCursors(int offset) {
    if (_controller == null || _cursors.isEmpty) return;
    
    for (int i = 0; i < _cursors.length; i++) {
      final cursor = _cursors[i];
      final newPosition = (cursor.start + offset).clamp(0, _controller!.text.length);
      _cursors[i] = TextSelection.collapsed(offset: newPosition);
    }
  }

  /// Elimina un cursor específico
  void removeCursor(int index) {
    if (index >= 0 && index < _cursors.length) {
      _cursors.removeAt(index);
      if (_cursors.isEmpty) {
        _isMultiCursorMode = false;
      }
    }
  }

  /// Limpia todos los cursores
  void clearCursors() {
    _cursors.clear();
    _isMultiCursorMode = false;
  }

  /// Maneja eventos de teclado para multi-cursor
  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (!_isMultiCursorMode || _cursors.isEmpty) {
      return KeyEventResult.ignored;
    }
    
    if (event is KeyDownEvent) {
      // Escape para salir del modo multi-cursor
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        clearCursors();
        return KeyEventResult.handled;
      }
      
      // Ctrl+A para seleccionar todas las ocurrencias
      if (event.logicalKey == LogicalKeyboardKey.keyA && 
          (HardwareKeyboard.instance.isControlPressed)) {
        // Implementar selección de todas las ocurrencias
        return KeyEventResult.handled;
      }
      
      // Teclas de movimiento
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        moveAllCursors(-1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        moveAllCursors(1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        backspaceAtAllCursors();
        return KeyEventResult.handled;
      }
      
      // Caracteres normales
      if (event.character != null && event.character!.isNotEmpty) {
        insertTextAtAllCursors(event.character!);
        return KeyEventResult.handled;
      }
    }
    
    return KeyEventResult.ignored;
  }

  /// Obtiene el texto seleccionado en todos los cursores
  List<String> getSelectedTexts() {
    if (_controller == null) return [];
    
    final text = _controller!.text;
    return _cursors.map((cursor) {
      if (cursor.start < text.length && cursor.end <= text.length) {
        return text.substring(cursor.start, cursor.end);
      }
      return '';
    }).toList();
  }

  /// Reemplaza el texto seleccionado en todos los cursores
  void replaceSelectedTexts(List<String> replacements) {
    if (_controller == null || _cursors.isEmpty || replacements.isEmpty) return;
    
    // Ordenar cursores por posición (de mayor a menor)
    final indexedCursors = <MapEntry<int, TextSelection>>[];
    for (int i = 0; i < _cursors.length; i++) {
      indexedCursors.add(MapEntry(i, _cursors[i]));
    }
    indexedCursors.sort((a, b) => b.value.start.compareTo(a.value.start));
    
    String newText = _controller!.text;
    
    for (final entry in indexedCursors) {
      final cursor = entry.value;
      final replacementIndex = entry.key % replacements.length;
      final replacement = replacements[replacementIndex];
      
      if (cursor.start <= newText.length && cursor.end <= newText.length) {
        newText = newText.substring(0, cursor.start) + 
                 replacement + 
                 newText.substring(cursor.end);
      }
    }
    
    _controller!.text = newText;
  }

  /// Duplica las líneas que contienen cursores
  void duplicateLines() {
    if (_controller == null || _cursors.isEmpty) return;
    
    final text = _controller!.text;
    final lines = text.split('\n');
    final linesToDuplicate = <int>{};
    
    // Encontrar qué líneas contienen cursores
    int currentIndex = 0;
    for (int i = 0; i < lines.length; i++) {
      final lineStart = currentIndex;
      final lineEnd = currentIndex + lines[i].length;
      
      for (final cursor in _cursors) {
        if (cursor.start >= lineStart && cursor.start <= lineEnd) {
          linesToDuplicate.add(i);
          break;
        }
      }
      
      currentIndex = lineEnd + 1;
    }
    
    // Duplicar líneas (de mayor a menor índice)
    final sortedLines = linesToDuplicate.toList()..sort((a, b) => b.compareTo(a));
    for (final lineIndex in sortedLines) {
      if (lineIndex < lines.length) {
        lines.insert(lineIndex + 1, lines[lineIndex]);
      }
    }
    
    _controller!.text = lines.join('\n');
  }
}

/// Widget para visualizar múltiples cursores
class MultiCursorOverlay extends StatelessWidget {
  final List<TextSelection> cursors;
  final TextStyle textStyle;
  final double lineHeight;
  final EdgeInsets padding;

  const MultiCursorOverlay({
    super.key,
    required this.cursors,
    required this.textStyle,
    required this.lineHeight,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: cursors.map((cursor) {
        return Positioned(
          left: padding.left + _getXPosition(cursor.start),
          top: padding.top + _getYPosition(cursor.start),
          child: Container(
            width: 2,
            height: lineHeight,
            color: Theme.of(context).primaryColor,
          ),
        );
      }).toList(),
    );
  }

  double _getXPosition(int offset) {
    // Calcular posición X basada en el offset
    // Esta es una aproximación simple, en un editor real necesitarías
    // medición precisa del texto
    return offset * (textStyle.fontSize ?? 16) * 0.6;
  }

  double _getYPosition(int offset) {
    // Calcular posición Y basada en el número de línea
    // Esta es una aproximación simple
    return 0; // Implementar cálculo real basado en líneas
  }
}