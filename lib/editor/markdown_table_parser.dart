/// Representa una tabla Markdown parseada
class ParsedTable {
  final List<List<String>> headers;
  final List<List<String>> separators;
  final List<List<String>> rows;
  final int startIndex;
  final int endIndex;

  ParsedTable({
    required this.headers,
    required this.separators,
    required this.rows,
    required this.startIndex,
    required this.endIndex,
  });

  int get columnCount => headers.isNotEmpty ? headers.first.length : 0;
  int get rowCount => rows.length;
}

/// Utilidades para manipular tablas Markdown
class MarkdownTableParser {
  static const String _defaultCol = '   ';
  static const String _defaultSeparator = '---';

  /// Busca y parsea una tabla en el texto alrededor del cursor
  static ParsedTable? parseTableAt(String text, int cursorPos) {
    final lines = text.split('\n');
    int lineIndex = 0;
    int charCount = 0;

    // Encontrar línea del cursor
    for (int i = 0; i < lines.length; i++) {
      if (charCount + lines[i].length >= cursorPos) {
        lineIndex = i;
        break;
      }
      charCount += lines[i].length + 1; // +1 por el \n
    }

    // Buscar inicio de tabla (hacia arriba)
    int tableStart = lineIndex;
    while (tableStart > 0 && _isTableLine(lines[tableStart - 1])) {
      tableStart--;
    }

    // Buscar fin de tabla (hacia abajo)
    int tableEnd = lineIndex;
    while (tableEnd < lines.length - 1 && _isTableLine(lines[tableEnd + 1])) {
      tableEnd++;
    }

    // Verificar si estamos en una tabla válida
    if (!_isTableLine(lines[lineIndex])) return null;

    final tableLines = lines.sublist(tableStart, tableEnd + 1);
    if (tableLines.length < 2) return null; // Mínimo header + separator

    // Parsear header
    final headerCells = _parseTableRow(tableLines[0]);
    if (headerCells.isEmpty) return null;

    // Parsear separator
    final separatorCells = _parseTableRow(tableLines[1]);
    if (separatorCells.length != headerCells.length) return null;

    // Parsear filas de datos
    final dataRows = <List<String>>[];
    for (int i = 2; i < tableLines.length; i++) {
      final rowCells = _parseTableRow(tableLines[i]);
      if (rowCells.length == headerCells.length) {
        dataRows.add(rowCells);
      }
    }

    // Calcular posiciones en el texto original
    int startPos = 0;
    for (int i = 0; i < tableStart; i++) {
      startPos += lines[i].length + 1;
    }

    int endPos = startPos;
    for (int i = tableStart; i <= tableEnd; i++) {
      endPos += lines[i].length + 1;
    }
    endPos--; // Quitar el último \n

    return ParsedTable(
      headers: [headerCells],
      separators: [separatorCells],
      rows: dataRows,
      startIndex: startPos,
      endIndex: endPos,
    );
  }

  /// Verifica si una línea es parte de una tabla Markdown
  static bool _isTableLine(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('|') &&
        trimmed.endsWith('|') &&
        trimmed.contains('|');
  }

  /// Parsea una fila de tabla y devuelve las celdas
  static List<String> _parseTableRow(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) return [];

    // Remover | del inicio y final, luego dividir
    final content = trimmed.substring(1, trimmed.length - 1);
    return content.split('|').map((cell) => cell.trim()).toList();
  }

  /// Convierte una tabla parseada de vuelta a texto Markdown
  static String tableToMarkdown(ParsedTable table) {
    final lines = <String>[];

    // Header
    if (table.headers.isNotEmpty) {
      lines.add('| ${table.headers.first.join(' | ')} |');
    }

    // Separator
    if (table.separators.isNotEmpty) {
      lines.add('| ${table.separators.first.join(' | ')} |');
    }

    // Data rows
    for (final row in table.rows) {
      lines.add('| ${row.join(' | ')} |');
    }

    return lines.join('\n');
  }

  /// Añade una fila arriba de la posición especificada
  static ParsedTable addRowAbove(ParsedTable table, int rowIndex) {
    final newRow = List.generate(table.columnCount, (_) => _defaultCol);
    final newRows = List<List<String>>.from(table.rows);
    newRows.insert(rowIndex.clamp(0, newRows.length), newRow);

    return ParsedTable(
      headers: table.headers,
      separators: table.separators,
      rows: newRows,
      startIndex: table.startIndex,
      endIndex: table.endIndex,
    );
  }

  /// Añade una fila debajo de la posición especificada
  static ParsedTable addRowBelow(ParsedTable table, int rowIndex) {
    final newRow = List.generate(table.columnCount, (_) => _defaultCol);
    final newRows = List<List<String>>.from(table.rows);
    newRows.insert((rowIndex + 1).clamp(0, newRows.length), newRow);

    return ParsedTable(
      headers: table.headers,
      separators: table.separators,
      rows: newRows,
      startIndex: table.startIndex,
      endIndex: table.endIndex,
    );
  }

  /// Añade una columna a la izquierda de la posición especificada
  static ParsedTable addColumnLeft(ParsedTable table, int colIndex) {
    final safeIndex = colIndex.clamp(0, table.columnCount);

    // Actualizar headers
    final newHeaders = table.headers.map((row) {
      final newRow = List<String>.from(row);
      newRow.insert(safeIndex, _defaultCol);
      return newRow;
    }).toList();

    // Actualizar separators
    final newSeparators = table.separators.map((row) {
      final newRow = List<String>.from(row);
      newRow.insert(safeIndex, _defaultSeparator);
      return newRow;
    }).toList();

    // Actualizar data rows
    final newRows = table.rows.map((row) {
      final newRow = List<String>.from(row);
      newRow.insert(safeIndex, _defaultCol);
      return newRow;
    }).toList();

    return ParsedTable(
      headers: newHeaders,
      separators: newSeparators,
      rows: newRows,
      startIndex: table.startIndex,
      endIndex: table.endIndex,
    );
  }

  /// Añade una columna a la derecha de la posición especificada
  static ParsedTable addColumnRight(ParsedTable table, int colIndex) {
    final safeIndex = (colIndex + 1).clamp(0, table.columnCount);

    // Actualizar headers
    final newHeaders = table.headers.map((row) {
      final newRow = List<String>.from(row);
      newRow.insert(safeIndex, _defaultCol);
      return newRow;
    }).toList();

    // Actualizar separators
    final newSeparators = table.separators.map((row) {
      final newRow = List<String>.from(row);
      newRow.insert(safeIndex, _defaultSeparator);
      return newRow;
    }).toList();

    // Actualizar data rows
    final newRows = table.rows.map((row) {
      final newRow = List<String>.from(row);
      newRow.insert(safeIndex, _defaultCol);
      return newRow;
    }).toList();

    return ParsedTable(
      headers: newHeaders,
      separators: newSeparators,
      rows: newRows,
      startIndex: table.startIndex,
      endIndex: table.endIndex,
    );
  }

  /// Elimina una fila
  static ParsedTable? deleteRow(ParsedTable table, int rowIndex) {
    if (rowIndex < 0 || rowIndex >= table.rows.length) return table;
    if (table.rows.length <= 1) return null; // No eliminar la última fila

    final newRows = List<List<String>>.from(table.rows);
    newRows.removeAt(rowIndex);

    return ParsedTable(
      headers: table.headers,
      separators: table.separators,
      rows: newRows,
      startIndex: table.startIndex,
      endIndex: table.endIndex,
    );
  }

  /// Elimina una columna
  static ParsedTable? deleteColumn(ParsedTable table, int colIndex) {
    if (colIndex < 0 || colIndex >= table.columnCount) return table;
    if (table.columnCount <= 1) return null; // No eliminar la última columna

    // Actualizar headers
    final newHeaders = table.headers.map((row) {
      final newRow = List<String>.from(row);
      newRow.removeAt(colIndex);
      return newRow;
    }).toList();

    // Actualizar separators
    final newSeparators = table.separators.map((row) {
      final newRow = List<String>.from(row);
      newRow.removeAt(colIndex);
      return newRow;
    }).toList();

    // Actualizar data rows
    final newRows = table.rows.map((row) {
      final newRow = List<String>.from(row);
      if (colIndex < newRow.length) newRow.removeAt(colIndex);
      return newRow;
    }).toList();

    return ParsedTable(
      headers: newHeaders,
      separators: newSeparators,
      rows: newRows,
      startIndex: table.startIndex,
      endIndex: table.endIndex,
    );
  }

  /// Mueve una fila hacia arriba
  static ParsedTable moveRowUp(ParsedTable table, int rowIndex) {
    if (rowIndex <= 0 || rowIndex >= table.rows.length) return table;

    final newRows = List<List<String>>.from(table.rows);
    final temp = newRows[rowIndex];
    newRows[rowIndex] = newRows[rowIndex - 1];
    newRows[rowIndex - 1] = temp;

    return ParsedTable(
      headers: table.headers,
      separators: table.separators,
      rows: newRows,
      startIndex: table.startIndex,
      endIndex: table.endIndex,
    );
  }

  /// Mueve una fila hacia abajo
  static ParsedTable moveRowDown(ParsedTable table, int rowIndex) {
    if (rowIndex < 0 || rowIndex >= table.rows.length - 1) return table;

    final newRows = List<List<String>>.from(table.rows);
    final temp = newRows[rowIndex];
    newRows[rowIndex] = newRows[rowIndex + 1];
    newRows[rowIndex + 1] = temp;

    return ParsedTable(
      headers: table.headers,
      separators: table.separators,
      rows: newRows,
      startIndex: table.startIndex,
      endIndex: table.endIndex,
    );
  }

  /// Mueve una columna hacia la izquierda
  static ParsedTable moveColumnLeft(ParsedTable table, int colIndex) {
    if (colIndex <= 0 || colIndex >= table.columnCount) return table;

    // Función helper para mover columna en una lista de filas
    List<List<String>> moveColInRows(List<List<String>> rows) {
      return rows.map((row) {
        final newRow = List<String>.from(row);
        if (colIndex < newRow.length && colIndex - 1 < newRow.length) {
          final temp = newRow[colIndex];
          newRow[colIndex] = newRow[colIndex - 1];
          newRow[colIndex - 1] = temp;
        }
        return newRow;
      }).toList();
    }

    return ParsedTable(
      headers: moveColInRows(table.headers),
      separators: moveColInRows(table.separators),
      rows: moveColInRows(table.rows),
      startIndex: table.startIndex,
      endIndex: table.endIndex,
    );
  }

  /// Mueve una columna hacia la derecha
  static ParsedTable moveColumnRight(ParsedTable table, int colIndex) {
    if (colIndex < 0 || colIndex >= table.columnCount - 1) return table;

    // Función helper para mover columna en una lista de filas
    List<List<String>> moveColInRows(List<List<String>> rows) {
      return rows.map((row) {
        final newRow = List<String>.from(row);
        if (colIndex < newRow.length && colIndex + 1 < newRow.length) {
          final temp = newRow[colIndex];
          newRow[colIndex] = newRow[colIndex + 1];
          newRow[colIndex + 1] = temp;
        }
        return newRow;
      }).toList();
    }

    return ParsedTable(
      headers: moveColInRows(table.headers),
      separators: moveColInRows(table.separators),
      rows: moveColInRows(table.rows),
      startIndex: table.startIndex,
      endIndex: table.endIndex,
    );
  }
}
