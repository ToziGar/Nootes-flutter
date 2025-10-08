import 'package:flutter/material.dart';

/// Servicio para matching de brackets y paréntesis
class BracketMatchingService {
  static final BracketMatchingService _instance = BracketMatchingService._internal();
  factory BracketMatchingService() => _instance;
  BracketMatchingService._internal();

  static const Map<String, String> _openingBrackets = {
    '(': ')',
    '[': ']',
    '{': '}',
    '<': '>',
    '"': '"',
    "'": "'",
    '`': '`',
  };

  static const Map<String, String> _closingBrackets = {
    ')': '(',
    ']': '[',
    '}': '{',
    '>': '<',
    '"': '"',
    "'": "'",
    '`': '`',
  };

  /// Encuentra el bracket que hace match con el bracket en la posición dada
  BracketMatch? findMatchingBracket(String text, int position) {
    if (position < 0 || position >= text.length) return null;

    final char = text[position];
    
    // Verificar si es un bracket de apertura
    if (_openingBrackets.containsKey(char)) {
      final closingChar = _openingBrackets[char]!;
      final matchPosition = _findClosingBracket(text, position, char, closingChar);
      if (matchPosition != -1) {
        return BracketMatch(
          openPosition: position,
          closePosition: matchPosition,
          openChar: char,
          closeChar: closingChar,
          isValid: true,
        );
      }
    }
    
    // Verificar si es un bracket de cierre
    if (_closingBrackets.containsKey(char)) {
      final openingChar = _closingBrackets[char]!;
      final matchPosition = _findOpeningBracket(text, position, openingChar, char);
      if (matchPosition != -1) {
        return BracketMatch(
          openPosition: matchPosition,
          closePosition: position,
          openChar: openingChar,
          closeChar: char,
          isValid: true,
        );
      }
    }

    return null;
  }

  /// Encuentra todos los brackets no balanceados en el texto
  List<BracketError> findUnbalancedBrackets(String text) {
    final errors = <BracketError>[];
    final stack = <BracketInfo>[];
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      
      if (_openingBrackets.containsKey(char)) {
        // Bracket de apertura
        stack.add(BracketInfo(
          position: i,
          char: char,
          expectedClosing: _openingBrackets[char]!,
        ));
      } else if (_closingBrackets.containsKey(char)) {
        // Bracket de cierre
        if (stack.isEmpty) {
          // Bracket de cierre sin apertura
          errors.add(BracketError(
            position: i,
            char: char,
            type: BracketErrorType.unmatchedClosing,
            message: 'Bracket de cierre "$char" sin apertura correspondiente',
          ));
        } else {
          final lastOpening = stack.last;
          if (lastOpening.expectedClosing == char) {
            // Match correcto
            stack.removeLast();
          } else {
            // Mismatch
            errors.add(BracketError(
              position: i,
              char: char,
              type: BracketErrorType.mismatch,
              message: 'Se esperaba "${lastOpening.expectedClosing}" pero se encontró "$char"',
              relatedPosition: lastOpening.position,
            ));
            stack.removeLast();
          }
        }
      }
    }
    
    // Brackets de apertura sin cierre
    for (final unclosed in stack) {
      errors.add(BracketError(
        position: unclosed.position,
        char: unclosed.char,
        type: BracketErrorType.unmatchedOpening,
        message: 'Bracket de apertura "${unclosed.char}" sin cierre correspondiente',
      ));
    }
    
    return errors;
  }

  /// Encuentra brackets que rodean la posición del cursor
  List<BracketMatch> findSurroundingBrackets(String text, int cursorPosition) {
    final matches = <BracketMatch>[];
    
    // Buscar hacia atrás para encontrar brackets de apertura
    for (int i = cursorPosition - 1; i >= 0; i--) {
      final char = text[i];
      if (_openingBrackets.containsKey(char)) {
        final match = findMatchingBracket(text, i);
        if (match != null && match.closePosition > cursorPosition) {
          matches.add(match);
        }
      }
    }
    
    return matches;
  }

  /// Inserta brackets de cierre automáticamente
  String autoCloseBrackets(String text, int position, String insertedChar) {
    if (_openingBrackets.containsKey(insertedChar)) {
      final closingChar = _openingBrackets[insertedChar]!;
      
      // Verificar si ya hay un bracket de cierre
      if (position < text.length && text[position] == closingChar) {
        return text; // Ya existe, no insertar
      }
      
      // Insertar bracket de cierre
      return text.substring(0, position) + 
             closingChar + 
             text.substring(position);
    }
    
    return text;
  }

  /// Elimina brackets emparejados cuando se borra un bracket de apertura
  String autoDeleteBrackets(String text, int position) {
    if (position > 0 && position < text.length) {
      final prevChar = text[position - 1];
      final nextChar = text[position];
      
      if (_openingBrackets.containsKey(prevChar) && 
          _openingBrackets[prevChar] == nextChar) {
        // Eliminar ambos brackets
        return text.substring(0, position - 1) + text.substring(position + 1);
      }
    }
    
    return text;
  }

  /// Selecciona el contenido dentro de brackets
  TextSelection? selectInsideBrackets(String text, int cursorPosition) {
    final surrounding = findSurroundingBrackets(text, cursorPosition);
    
    if (surrounding.isNotEmpty) {
      final innermost = surrounding.last; // El más interno
      return TextSelection(
        baseOffset: innermost.openPosition + 1,
        extentOffset: innermost.closePosition,
      );
    }
    
    return null;
  }

  /// Optional initialize hook for editor compatibility (no-op)
  /// Some editor components call `initialize(controller)` on services.
  /// Keep this here to avoid breaking callers; it can be expanded later.
  void initialize([TextEditingController? controller]) {}

  /// Encuentra el bracket de cierre correspondiente
  int _findClosingBracket(String text, int startPos, String openChar, String closeChar) {
    int count = 1;
    bool inString = false;
    String stringChar = '';
    
    for (int i = startPos + 1; i < text.length; i++) {
      final char = text[i];
      
      // Manejar strings para evitar brackets dentro de strings
      if ((char == '"' || char == "'" || char == '`') && !inString) {
        inString = true;
        stringChar = char;
        continue;
      } else if (char == stringChar && inString && 
                 (i == 0 || text[i - 1] != '\\')) {
        inString = false;
        stringChar = '';
        continue;
      }
      
      if (!inString) {
        if (char == openChar) {
          count++;
        } else if (char == closeChar) {
          count--;
          if (count == 0) {
            return i;
          }
        }
      }
    }
    
    return -1; // No se encontró
  }

  /// Encuentra el bracket de apertura correspondiente
  int _findOpeningBracket(String text, int startPos, String openChar, String closeChar) {
    int count = 1;
    bool inString = false;
    String stringChar = '';
    
    for (int i = startPos - 1; i >= 0; i--) {
      final char = text[i];
      
      // Manejar strings
      if ((char == '"' || char == "'" || char == '`') && !inString) {
        // Verificar si no está escapado
        if (i == 0 || text[i - 1] != '\\') {
          inString = true;
          stringChar = char;
          continue;
        }
      } else if (char == stringChar && inString) {
        inString = false;
        stringChar = '';
        continue;
      }
      
      if (!inString) {
        if (char == closeChar) {
          count++;
        } else if (char == openChar) {
          count--;
          if (count == 0) {
            return i;
          }
        }
      }
    }
    
    return -1; // No se encontró
  }

  /// Obtiene el color para resaltar brackets
  Color getBracketHighlightColor(BuildContext context, {bool isError = false}) {
    if (isError) {
      return Theme.of(context).colorScheme.error;
    }
    return Theme.of(context).primaryColor.withOpacity(0.3);
  }

  /// Verifica si un carácter es un bracket
  bool isBracket(String char) {
    return _openingBrackets.containsKey(char) || _closingBrackets.containsKey(char);
  }
}

/// Información sobre un bracket match
class BracketMatch {
  final int openPosition;
  final int closePosition;
  final String openChar;
  final String closeChar;
  final bool isValid;

  const BracketMatch({
    required this.openPosition,
    required this.closePosition,
    required this.openChar,
    required this.closeChar,
    required this.isValid,
  });

  @override
  String toString() {
    return 'BracketMatch($openChar at $openPosition -> $closeChar at $closePosition)';
  }
}

/// Información sobre un bracket en el stack
class BracketInfo {
  final int position;
  final String char;
  final String expectedClosing;

  const BracketInfo({
    required this.position,
    required this.char,
    required this.expectedClosing,
  });
}

/// Error de bracket no balanceado
class BracketError {
  final int position;
  final String char;
  final BracketErrorType type;
  final String message;
  final int? relatedPosition;

  const BracketError({
    required this.position,
    required this.char,
    required this.type,
    required this.message,
    this.relatedPosition,
  });

  @override
  String toString() {
    return 'BracketError($type: $message at $position)';
  }
}

/// Tipos de errores de brackets
enum BracketErrorType {
  unmatchedOpening,
  unmatchedClosing,
  mismatch,
}

/// Widget para mostrar highlights de brackets
class BracketHighlightOverlay extends StatelessWidget {
  final List<BracketMatch> matches;
  final List<BracketError> errors;
  final TextStyle textStyle;
  final double lineHeight;
  final EdgeInsets padding;

  const BracketHighlightOverlay({
    super.key,
    required this.matches,
    required this.errors,
    required this.textStyle,
    required this.lineHeight,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Highlights para matches válidos
        ...matches.map((match) => Stack(
          children: [
            _buildHighlight(context, match.openPosition, false),
            _buildHighlight(context, match.closePosition, false),
          ],
        )),
        // Highlights para errores
        ...errors.map((error) => _buildHighlight(context, error.position, true)),
      ],
    );
  }

  Widget _buildHighlight(BuildContext context, int position, bool isError) {
    return Positioned(
      left: padding.left + _getXPosition(position),
      top: padding.top + _getYPosition(position),
      child: Container(
        width: (textStyle.fontSize ?? 16) * 0.6,
        height: lineHeight,
        decoration: BoxDecoration(
          color: isError 
              ? Theme.of(context).colorScheme.error.withOpacity(0.3)
              : Theme.of(context).primaryColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  double _getXPosition(int offset) {
    // Aproximación simple - en un editor real necesitarías medición precisa
    return offset * (textStyle.fontSize ?? 16) * 0.6;
  }

  double _getYPosition(int offset) {
    // Aproximación simple - calcular basado en líneas
    return 0; // Implementar cálculo real
  }
}