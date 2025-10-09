import 'package:flutter/material.dart';
import 'markdown_table_parser.dart';

typedef InsertPattern = void Function(String left, [String right]);
typedef InsertLine = void Function(String linePrefix);
typedef InsertBlock = void Function(String blockPrefix, [String blockSuffix]);

class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({
    super.key,
    required this.onWrapSelection,
    required this.onInsertAtLineStart,
    required this.onInsertBlock,
    required this.onToggleSplit,
    required this.isSplit,
    this.onPickImage,
    this.onPickWiki,
    this.showSplitToggle = true,
    this.readOnly = false,
    this.controller,
  });

  final InsertPattern onWrapSelection;
  final InsertLine onInsertAtLineStart;
  final InsertBlock onInsertBlock;
  final VoidCallback onToggleSplit;
  final bool isSplit;
  final Future<String?> Function(BuildContext context)? onPickImage;
  final Future<String?> Function(BuildContext context)? onPickWiki;
  final bool showSplitToggle;
  final bool readOnly;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
        _btn(context, Icons.format_bold, 'Negrita', () => onWrapSelection('**', '**')),
        _btn(context, Icons.format_italic, 'Itálica', () => onWrapSelection('*', '*')),
        _btn(context, Icons.code, 'Código', () => onWrapSelection('`', '`')),
        _btn(context, Icons.code_off, 'Bloque código', () => onInsertBlock('```\n', '\n```')),
        _btn(context, Icons.format_quote, 'Cita', () => onInsertAtLineStart('> ')),
        _btn(context, Icons.format_list_bulleted, 'Lista', () => onInsertAtLineStart('- ')),
        _btn(context, Icons.format_list_numbered, 'Lista num.', () => onInsertAtLineStart('1. ')),
        _btn(context, Icons.checklist, 'Tareas', () => onInsertAtLineStart('- [ ] ')),
        _btn(context, Icons.horizontal_rule, 'Separador', () => onInsertBlock('\n---\n')),
        _btn(context, Icons.link, 'Enlace', () => onInsertBlock('[', '](https://)')),
        _btn(context, Icons.image, 'Imagen', () async {
          if (onPickImage != null) {
            final url = await onPickImage!(context);
            if (url != null && url.isNotEmpty) {
              onInsertBlock('![', ']($url)');
            }
          } else {
            onInsertBlock('![', '](https://)');
          }
        }),
        _btn(context, Icons.bookmarks, 'Enlace interno', () async {
          if (onPickWiki != null) {
            final title = await onPickWiki!(context);
            if (title != null && title.isNotEmpty) {
              onInsertBlock('[[', '$title]]');
            }
          }
        }),
        const SizedBox(width: 8),
        _headerMenu(context),
        const SizedBox(width: 8),
        _btn(context, Icons.table_chart, 'Tabla', () => _insertTable(context)),
        _btn(context, Icons.table_rows, 'Añadir fila debajo', () => _addRowBelow(context)),
        _btn(context, Icons.keyboard_arrow_up, 'Añadir fila arriba', () => _addRowAbove(context)),
        _btn(context, Icons.view_column, 'Añadir columna derecha', () => _addColumnRight(context)),
        _btn(context, Icons.keyboard_arrow_left, 'Añadir columna izquierda', () => _addColumnLeft(context)),
        _btn(context, Icons.delete_outline, 'Eliminar fila', () => _deleteRow(context)),
        const SizedBox(width: 8),
        if (showSplitToggle)
          IconButton(
            tooltip: isSplit ? 'Vista editor' : 'Vista dividida',
            onPressed: onToggleSplit,
            icon: Icon(isSplit ? Icons.view_compact_alt_rounded : Icons.vertical_split_rounded),
          ),
        ],
        ),
      );
  }

  Widget _btn(BuildContext context, IconData icon, String tip, VoidCallback? onPressed) {
    final isEnabled = !readOnly && onPressed != null;
    return IconButton(
      onPressed: isEnabled ? onPressed : null,
      tooltip: tip,
      icon: Icon(
        icon, 
        color: isEnabled 
          ? Theme.of(context).iconTheme.color 
          : Theme.of(context).disabledColor,
      ),
      style: IconButton.styleFrom(
        backgroundColor: isEnabled 
          ? Theme.of(context).cardColor.withValues(alpha: 0.5)
          : Colors.transparent,
        foregroundColor: isEnabled 
          ? Theme.of(context).iconTheme.color 
          : Theme.of(context).disabledColor,
      ),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }

  Widget _headerMenu(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Encabezado',
      icon: const Icon(Icons.title),
      onSelected: (level) {
        final hashes = '#' * level;
        onInsertAtLineStart('$hashes ');
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 1, child: Text('H1')),
        PopupMenuItem(value: 2, child: Text('H2')),
        PopupMenuItem(value: 3, child: Text('H3')),
        PopupMenuItem(value: 4, child: Text('H4')),
        PopupMenuItem(value: 5, child: Text('H5')),
        PopupMenuItem(value: 6, child: Text('H6')),
      ],
    );
  }

  void _insertTable(BuildContext context) async {
    final dims = await showDialog<(int, int)>(
      context: context,
      builder: (context) {
        int rows = 3;
        int cols = 3;
        return AlertDialog(
          title: const Text('Insertar tabla'),
          content: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Filas'),
                    Slider(
                      value: rows.toDouble(),
                      onChanged: (v) => rows = v.round(),
                      divisions: 7,
                      min: 2,
                      max: 9,
                      label: rows.toString(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Columnas'),
                    Slider(
                      value: cols.toDouble(),
                      onChanged: (v) => cols = v.round(),
                      divisions: 7,
                      min: 2,
                      max: 9,
                      label: cols.toString(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, (rows, cols)), child: const Text('Insertar')),
          ],
        );
      },
    );
    if (dims == null) return;
    final rows = dims.$1;
    final cols = dims.$2;
    final header = List.generate(cols, (i) => 'Col ${i + 1}').join(' | ');
    final separator = List.generate(cols, (i) => '---').join(' | ');
    final body = List.generate(rows - 1, (_) => List.generate(cols, (i) => ' ').join(' | ')).join('\n');
    final table = '| $header |\n| $separator |\n$body\n';
    onInsertBlock(table);
  }

  // === Table manipulation methods ===
  void _addRowBelow(BuildContext context) => _manipulateTable(context, 'addRowBelow');
  void _addRowAbove(BuildContext context) => _manipulateTable(context, 'addRowAbove');
  void _addColumnRight(BuildContext context) => _manipulateTable(context, 'addColumnRight');
  void _addColumnLeft(BuildContext context) => _manipulateTable(context, 'addColumnLeft');
  void _deleteRow(BuildContext context) => _manipulateTable(context, 'deleteRow');

  void _manipulateTable(BuildContext context, String operation) {
    if (controller == null) return;
    
    final text = controller!.text;
    final cursor = controller!.selection.baseOffset;
    final table = MarkdownTableParser.parseTableAt(text, cursor);
    
    if (table == null) {
      // No hay tabla en el cursor, insertar mensaje
      onInsertBlock('<!-- No hay tabla en el cursor -->');
      return;
    }

    ParsedTable? newTable;
    final estimatedRow = 0; // Para simplificar, usar fila 0
    final estimatedCol = 0; // Para simplificar, usar columna 0

    switch (operation) {
      case 'addRowBelow':
        newTable = MarkdownTableParser.addRowBelow(table, estimatedRow);
        break;
      case 'addRowAbove':
        newTable = MarkdownTableParser.addRowAbove(table, estimatedRow);
        break;
      case 'addColumnRight':
        newTable = MarkdownTableParser.addColumnRight(table, estimatedCol);
        break;
      case 'addColumnLeft':
        newTable = MarkdownTableParser.addColumnLeft(table, estimatedCol);
        break;
      case 'deleteRow':
        newTable = MarkdownTableParser.deleteRow(table, estimatedRow);
        break;
    }

    if (newTable != null) {
      final newTableText = MarkdownTableParser.tableToMarkdown(newTable);
      final beforeTable = text.substring(0, table.startIndex);
      final afterTable = text.substring(table.endIndex + 1);
      final newText = beforeTable + newTableText + afterTable;
      
      controller!.value = controller!.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: table.startIndex + newTableText.length ~/ 2),
      );
    }
  }
}
