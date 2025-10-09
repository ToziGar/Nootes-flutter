import 'package:flutter/material.dart';

/// Servicio para indentación automática e inteligente
class SmartIndentationService {
  static final SmartIndentationService _instance = SmartIndentationService._internal();
  factory SmartIndentationService() => _instance;
  SmartIndentationService._internal();

  TextEditingController? _controller;
  IndentationConfig _config = IndentationConfig();
  
  /// Configuración de indentación
  IndentationConfig get config => _config;

  /// Inicializa el servicio con un controlador
  void initialize(TextEditingController controller) {
    _controller = controller;
  }

  /// Actualiza la configuración
  void updateConfig(IndentationConfig config) {
    _config = config;
  }

  /// Maneja la inserción de nueva línea con indentación automática
  void handleNewLine() {
    if (_controller == null) return;

    final text = _controller!.text;
    final selection = _controller!.selection;
    
    if (!selection.isValid || selection.start != selection.end) return;

    final cursorPosition = selection.start;
    
    // Calcular nueva indentación
    final newIndent = _calculateNewIndentation(text, cursorPosition);
    
    // Insertar nueva línea con indentación
    final beforeCursor = text.substring(0, cursorPosition);
    final afterCursor = text.substring(cursorPosition);
    
    final newText = beforeCursor + '\n' + newIndent + afterCursor;
    final newCursorPosition = cursorPosition + 1 + newIndent.length;
    
    _controller!.text = newText;
    _controller!.selection = TextSelection.collapsed(offset: newCursorPosition);
  }

  /// Calcula la indentación para una nueva línea
  String _calculateNewIndentation(String text, int cursorPosition) {
    final lines = text.substring(0, cursorPosition).split('\n');
    if (lines.isEmpty) return '';
    
    final currentLine = lines.last;
    final currentIndent = _getIndentation(currentLine);
    final trimmedLine = currentLine.trim();
    
    // Detectar tipo de contenido
    final contentType = _detectContentType(text, cursorPosition);
    
    switch (contentType) {
      case ContentType.markdown:
        return _calculateMarkdownIndentation(currentLine, trimmedLine, currentIndent);
      case ContentType.code:
        return _calculateCodeIndentation(currentLine, trimmedLine, currentIndent);
      case ContentType.list:
        return _calculateListIndentation(currentLine, trimmedLine, currentIndent);
      case ContentType.json:
        return _calculateJsonIndentation(text, cursorPosition, currentIndent);
      case ContentType.yaml:
        return _calculateYamlIndentation(currentLine, trimmedLine, currentIndent);
      default:
        return _calculateDefaultIndentation(currentLine, trimmedLine, currentIndent);
    }
  }

  /// Detecta el tipo de contenido
  ContentType _detectContentType(String text, int cursorPosition) {
    final beforeCursor = text.substring(0, cursorPosition);
    final lines = beforeCursor.split('\n');
    
    // Buscar indicadores de tipo de contenido
    for (int i = lines.length - 1; i >= Math.max(0, lines.length - 10); i--) {
      final line = lines[i].trim();
      
      // Código entre ```
      if (line.startsWith('```')) {
        return ContentType.code;
      }
      
      // JSON
      if (line.contains('{') || line.contains('[') || line.contains('"')) {
        final jsonPattern = RegExp(r'[\{\[\"]');
        if (jsonPattern.hasMatch(line)) {
          return ContentType.json;
        }
      }
      
      // YAML
      if (line.contains(':') && !line.contains('http')) {
        return ContentType.yaml;
      }
      
      // Lista
      if (line.startsWith('- ') || line.startsWith('* ') || line.startsWith('+ ') ||
          RegExp(r'^\d+\. ').hasMatch(line)) {
        return ContentType.list;
      }
      
      // Encabezado Markdown
      if (line.startsWith('#')) {
        return ContentType.markdown;
      }
    }
    
    return ContentType.text;
  }

  /// Calcula indentación para Markdown
  String _calculateMarkdownIndentation(String currentLine, String trimmedLine, String currentIndent) {
    // Encabezados - sin indentación adicional
    if (trimmedLine.startsWith('#')) {
      return '';
    }
    
    // Bloques de código - mantener indentación
    if (trimmedLine.startsWith('```')) {
      return currentIndent;
    }
    
    // Citas - mantener indentación
    if (trimmedLine.startsWith('>')) {
      return currentIndent;
    }
    
    return currentIndent;
  }

  /// Calcula indentación para código
  String _calculateCodeIndentation(String currentLine, String trimmedLine, String currentIndent) {
    String newIndent = currentIndent;
    
    // Aumentar indentación después de llaves/corchetes de apertura
    if (trimmedLine.endsWith('{') || 
        trimmedLine.endsWith('[') ||
        trimmedLine.endsWith('(')) {
      newIndent += _config.indentString;
    }
    
    // Aumentar indentación después de dos puntos (Python, etc.)
    if (trimmedLine.endsWith(':')) {
      newIndent += _config.indentString;
    }
    
    // Aumentar indentación para bloques if, for, while, etc.
    final blockKeywords = ['if', 'for', 'while', 'function', 'def', 'class'];
    for (final keyword in blockKeywords) {
      if (trimmedLine.startsWith(keyword + ' ') || 
          trimmedLine.startsWith(keyword + '(')) {
        newIndent += _config.indentString;
        break;
      }
    }
    
    return newIndent;
  }

  /// Calcula indentación para listas
  String _calculateListIndentation(String currentLine, String trimmedLine, String currentIndent) {
    // Lista con guión
    if (trimmedLine.startsWith('- ')) {
      return currentIndent;
    }
    
    // Lista con asterisco
    if (trimmedLine.startsWith('* ')) {
      return currentIndent;
    }
    
    // Lista numerada
    final numberedMatch = RegExp(r'^(\d+)\. ').firstMatch(trimmedLine);
    if (numberedMatch != null) {
      return currentIndent;
    }
    
    // Sub-elemento de lista - aumentar indentación
    if (currentIndent.isNotEmpty) {
      return currentIndent + _config.indentString;
    }
    
    return currentIndent;
  }

  /// Calcula indentación para JSON
  String _calculateJsonIndentation(String text, int cursorPosition, String currentIndent) {
    final beforeCursor = text.substring(0, cursorPosition);
    final lines = beforeCursor.split('\n');
    final currentLine = lines.last.trim();
    
    String newIndent = currentIndent;
    
    // Después de llaves/corchetes de apertura
    if (currentLine.endsWith('{') || currentLine.endsWith('[')) {
      newIndent += _config.indentString;
    }
    
    // Después de coma en objeto/array
    if (currentLine.endsWith(',')) {
      // Mantener la misma indentación
    }
    
    return newIndent;
  }

  /// Calcula indentación para YAML
  String _calculateYamlIndentation(String currentLine, String trimmedLine, String currentIndent) {
    // Después de dos puntos - aumentar indentación
    if (trimmedLine.endsWith(':')) {
      return currentIndent + _config.indentString;
    }
    
    // Lista YAML
    if (trimmedLine.startsWith('- ')) {
      return currentIndent;
    }
    
    return currentIndent;
  }

  /// Calcula indentación por defecto
  String _calculateDefaultIndentation(String currentLine, String trimmedLine, String currentIndent) {
    return currentIndent;
  }

  /// Extrae la indentación de una línea
  String _getIndentation(String line) {
    final match = RegExp(r'^(\s*)').firstMatch(line);
    return match?.group(1) ?? '';
  }

  /// Indenta el texto seleccionado
  void indentSelection() {
    if (_controller == null) return;

    final text = _controller!.text;
    final selection = _controller!.selection;
    
    if (!selection.isValid) return;

    final startLine = _getLineNumber(text, selection.start);
    final endLine = _getLineNumber(text, selection.end);
    
    final lines = text.split('\n');
    final newLines = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      if (i >= startLine && i <= endLine) {
        newLines.add(_config.indentString + lines[i]);
      } else {
        newLines.add(lines[i]);
      }
    }
    
    final newText = newLines.join('\n');
    final indentLength = _config.indentString.length;
    final linesIndented = endLine - startLine + 1;
    
    _controller!.text = newText;
    _controller!.selection = TextSelection(
      baseOffset: selection.start + indentLength,
      extentOffset: selection.end + (indentLength * linesIndented),
    );
  }

  /// Des-indenta el texto seleccionado
  void unindentSelection() {
    if (_controller == null) return;

    final text = _controller!.text;
    final selection = _controller!.selection;
    
    if (!selection.isValid) return;

    final startLine = _getLineNumber(text, selection.start);
    final endLine = _getLineNumber(text, selection.end);
    
    final lines = text.split('\n');
    final newLines = <String>[];
    int totalRemoved = 0;
    
    for (int i = 0; i < lines.length; i++) {
      if (i >= startLine && i <= endLine) {
        final line = lines[i];
        if (line.startsWith(_config.indentString)) {
          newLines.add(line.substring(_config.indentString.length));
          totalRemoved += _config.indentString.length;
        } else if (line.startsWith('\t')) {
          newLines.add(line.substring(1));
          totalRemoved += 1;
        } else {
          newLines.add(line);
        }
      } else {
        newLines.add(lines[i]);
      }
    }
    
    final newText = newLines.join('\n');
    
    _controller!.text = newText;
    _controller!.selection = TextSelection(
      baseOffset: Math.max(0, selection.start - _config.indentString.length),
      extentOffset: Math.max(0, selection.end - totalRemoved),
    );
  }

  /// Formatea automáticamente todo el documento
  void autoFormat() {
    if (_controller == null) return;

    final text = _controller!.text;
    final lines = text.split('\n');
    final newLines = <String>[];
    
    ContentType currentType = ContentType.text;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      
      if (trimmedLine.isEmpty) {
        newLines.add('');
        continue;
      }
      
      // Detectar cambios de tipo de contenido
      currentType = _detectContentType(lines.take(i + 1).join('\n'), 0);
      
      // Calcular indentación apropiada
      final appropriateIndent = _calculateAppropriateIndent(
        lines.take(i).toList(),
        line,
        currentType,
      );
      
      newLines.add(appropriateIndent + trimmedLine);
    }
    
    _controller!.text = newLines.join('\n');
  }

  /// Calcula la indentación apropiada para una línea
  String _calculateAppropriateIndent(List<String> previousLines, String currentLine, ContentType type) {
    if (previousLines.isEmpty) return '';
    
    final trimmedLine = currentLine.trim();
    String baseIndent = '';
    
    // Buscar líneas previas no vacías para determinar contexto
    for (int i = previousLines.length - 1; i >= 0; i--) {
      final prevLine = previousLines[i];
      if (prevLine.trim().isNotEmpty) {
        baseIndent = _getIndentation(prevLine);
        
        // Ajustar basado en el contenido de la línea anterior
        final prevTrimmed = prevLine.trim();
        
        if (type == ContentType.code) {
          if (prevTrimmed.endsWith('{') || prevTrimmed.endsWith('[')) {
            baseIndent += _config.indentString;
          }
        } else if (type == ContentType.json) {
          if (prevTrimmed.endsWith('{') || prevTrimmed.endsWith('[')) {
            baseIndent += _config.indentString;
          }
        }
        
        break;
      }
    }
    
    // Ajustar para la línea actual
    if (type == ContentType.code) {
      if (trimmedLine.startsWith('}') || trimmedLine.startsWith(']')) {
        final indentLength = _config.indentString.length;
        if (baseIndent.length >= indentLength) {
          baseIndent = baseIndent.substring(0, baseIndent.length - indentLength);
        }
      }
    }
    
    return baseIndent;
  }

  /// Obtiene el número de línea para una posición
  int _getLineNumber(String text, int position) {
    return text.substring(0, position).split('\n').length - 1;
  }

  /// Convierte tabs a espacios
  void convertTabsToSpaces() {
    if (_controller == null) return;

    final text = _controller!.text;
    final newText = text.replaceAll('\t', _config.indentString);
    
    _controller!.text = newText;
  }

  /// Convierte espacios a tabs
  void convertSpacesToTabs() {
    if (_controller == null) return;

    final text = _controller!.text;
    final pattern = RegExp(r'^( {' + _config.tabSize.toString() + r'})+', multiLine: true);
    
    final newText = text.replaceAllMapped(pattern, (match) {
      final spaces = match.group(0) ?? '';
      final tabCount = spaces.length ~/ _config.tabSize;
      return '\t' * tabCount;
    });
    
    _controller!.text = newText;
  }

  /// Limpia espacios en blanco al final de las líneas
  void trimTrailingWhitespace() {
    if (_controller == null) return;

    final text = _controller!.text;
    final lines = text.split('\n');
    final trimmedLines = lines.map((line) => line.trimRight()).toList();
    
    _controller!.text = trimmedLines.join('\n');
  }
}

/// Configuración de indentación
class IndentationConfig {
  final bool useSpaces;
  final int tabSize;
  final bool autoIndent;
  final bool smartIndent;
  final bool detectIndentation;

  IndentationConfig({
    this.useSpaces = true,
    this.tabSize = 2,
    this.autoIndent = true,
    this.smartIndent = true,
    this.detectIndentation = true,
  });

  /// Obtiene la cadena de indentación
  String get indentString => useSpaces ? ' ' * tabSize : '\t';

  IndentationConfig copyWith({
    bool? useSpaces,
    int? tabSize,
    bool? autoIndent,
    bool? smartIndent,
    bool? detectIndentation,
  }) {
    return IndentationConfig(
      useSpaces: useSpaces ?? this.useSpaces,
      tabSize: tabSize ?? this.tabSize,
      autoIndent: autoIndent ?? this.autoIndent,
      smartIndent: smartIndent ?? this.smartIndent,
      detectIndentation: detectIndentation ?? this.detectIndentation,
    );
  }
}

/// Tipos de contenido para indentación
enum ContentType {
  text,
  markdown,
  code,
  json,
  yaml,
  list,
}

/// Widget para configurar la indentación
class IndentationSettingsDialog extends StatefulWidget {
  final IndentationConfig config;
  final Function(IndentationConfig) onConfigChanged;

  const IndentationSettingsDialog({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  State<IndentationSettingsDialog> createState() => _IndentationSettingsDialogState();
}

class _IndentationSettingsDialogState extends State<IndentationSettingsDialog> {
  late IndentationConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configuración de Indentación'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Usar espacios'),
              subtitle: const Text('Usar espacios en lugar de tabs'),
              value: _config.useSpaces,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(useSpaces: value);
                });
              },
            ),
            
            ListTile(
              title: const Text('Tamaño de tab'),
              subtitle: Slider(
                value: _config.tabSize.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                label: _config.tabSize.toString(),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(tabSize: value.round());
                  });
                },
              ),
            ),
            
            SwitchListTile(
              title: const Text('Auto-indentación'),
              subtitle: const Text('Indentar automáticamente nuevas líneas'),
              value: _config.autoIndent,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(autoIndent: value);
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Indentación inteligente'),
              subtitle: const Text('Indentación basada en el contexto'),
              value: _config.smartIndent,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(smartIndent: value);
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Detectar indentación'),
              subtitle: const Text('Detectar automáticamente el estilo'),
              value: _config.detectIndentation,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(detectIndentation: value);
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfigChanged(_config);
            Navigator.of(context).pop();
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Implementación simple de Math para uso interno
class Math {
  static int max(int a, int b) => a > b ? a : b;
  static int min(int a, int b) => a < b ? a : b;
}