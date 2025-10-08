import 'package:flutter/material.dart';

/// Servicio para el plegado de código y secciones
class CodeFoldingService {
  static final CodeFoldingService _instance = CodeFoldingService._internal();
  factory CodeFoldingService() => _instance;
  CodeFoldingService._internal();

  final Map<String, FoldableRegion> _regions = {};
  final Set<String> _foldedRegions = {};
  TextEditingController? _controller;

  /// Obtiene las regiones plegables
  Map<String, FoldableRegion> get regions => Map.unmodifiable(_regions);

  /// Obtiene las regiones plegadas
  Set<String> get foldedRegions => Set.unmodifiable(_foldedRegions);

  /// Inicializa el servicio con un controlador
  void initialize(TextEditingController controller) {
    _controller = controller;
    _detectFoldableRegions();
  }

  /// Detecta automáticamente las regiones plegables
  void _detectFoldableRegions() {
    if (_controller == null) return;

    final text = _controller!.text;
    final lines = text.split('\n');
    _regions.clear();

    _detectMarkdownSections(lines);
    _detectCodeBlocks(lines);
    _detectLists(lines);
    _detectIndentedBlocks(lines);
    _detectCustomRegions(lines);
  }

  /// Detecta secciones de Markdown
  void _detectMarkdownSections(List<String> lines) {
    final Stack<FoldableRegion> stack = Stack();
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimLeft();
      
      // Detectar encabezados
      if (line.startsWith('#')) {
        final level = line.indexOf(' ');
        if (level > 0) {
          final headerLevel = level;
          final title = line.substring(level + 1).trim();
          
          // Cerrar encabezados de nivel igual o mayor
          while (stack.isNotEmpty && stack.last.level >= headerLevel) {
            final region = stack.removeLast();
            region.endLine = i - 1;
            if (region.endLine > region.startLine) {
              _regions[region.id] = region;
            }
          }
          
          // Crear nueva región
          final region = FoldableRegion(
            id: 'header_${i}_$headerLevel',
            type: FoldableType.markdownHeader,
            startLine: i,
            endLine: lines.length - 1,
            level: headerLevel,
            title: title,
            preview: _generatePreview(lines, i, Math.min(i + 3, lines.length)),
          );
          
          stack.add(region);
        }
      }
    }
    
    // Cerrar regiones restantes
    while (stack.isNotEmpty) {
      final region = stack.removeLast();
      if (region.endLine > region.startLine) {
        _regions[region.id] = region;
      }
    }
  }

  /// Detecta bloques de código
  void _detectCodeBlocks(List<String> lines) {
    bool inCodeBlock = false;
    int startLine = -1;
    String language = '';
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.startsWith('```')) {
        if (!inCodeBlock) {
          // Inicio de bloque de código
          inCodeBlock = true;
          startLine = i;
          language = line.length > 3 ? line.substring(3).trim() : 'code';
        } else {
          // Fin de bloque de código
          inCodeBlock = false;
          if (i > startLine + 1) {
            final region = FoldableRegion(
              id: 'code_${startLine}_$i',
              type: FoldableType.codeBlock,
              startLine: startLine,
              endLine: i,
              level: 1,
              title: language.isNotEmpty ? language : 'Código',
              preview: _generatePreview(lines, startLine + 1, Math.min(startLine + 4, i)),
            );
            _regions[region.id] = region;
          }
        }
      }
    }
  }

  /// Detecta listas
  void _detectLists(List<String> lines) {
    int? listStart;
    int lastIndent = -1;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      final indent = line.length - trimmed.length;
      
      // Detectar elementos de lista
      final isListItem = trimmed.startsWith('- ') || 
                        trimmed.startsWith('* ') || 
                        trimmed.startsWith('+ ') ||
                        RegExp(r'^\d+\. ').hasMatch(trimmed);
      
      if (isListItem) {
        if (listStart == null) {
          listStart = i;
          lastIndent = indent;
        } else if (indent <= lastIndent) {
          // Nueva lista o mismo nivel
          if (i - listStart > 2) {
            _createListRegion(lines, listStart, i - 1);
          }
          listStart = i;
          lastIndent = indent;
        }
      } else if (listStart != null && line.trim().isEmpty) {
        // Línea vacía en lista, continuar
        continue;
      } else if (listStart != null) {
        // Fin de lista
        if (i - listStart > 2) {
          _createListRegion(lines, listStart, i - 1);
        }
        listStart = null;
      }
    }
    
    // Lista hasta el final
    if (listStart != null && lines.length - listStart > 2) {
      _createListRegion(lines, listStart, lines.length - 1);
    }
  }

  /// Crea una región de lista
  void _createListRegion(List<String> lines, int start, int end) {
    final region = FoldableRegion(
      id: 'list_${start}_$end',
      type: FoldableType.list,
      startLine: start,
      endLine: end,
      level: 1,
      title: 'Lista (${end - start + 1} elementos)',
      preview: _generatePreview(lines, start, Math.min(start + 3, end + 1)),
    );
    _regions[region.id] = region;
  }

  /// Detecta bloques indentados
  void _detectIndentedBlocks(List<String> lines) {
    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      
      final baseIndent = line.length - line.trimLeft().length;
      int blockEnd = i;
      
      // Buscar líneas con mayor indentación
      for (int j = i + 1; j < lines.length; j++) {
        final nextLine = lines[j];
        if (nextLine.trim().isEmpty) continue;
        
        final nextIndent = nextLine.length - nextLine.trimLeft().length;
        if (nextIndent > baseIndent) {
          blockEnd = j;
        } else {
          break;
        }
      }
      
      // Crear región si hay suficientes líneas
      if (blockEnd - i >= 3) {
        final region = FoldableRegion(
          id: 'indent_${i}_$blockEnd',
          type: FoldableType.indentedBlock,
          startLine: i,
          endLine: blockEnd,
          level: baseIndent ~/ 2 + 1,
          title: 'Bloque indentado',
          preview: _generatePreview(lines, i + 1, Math.min(i + 4, blockEnd + 1)),
        );
        _regions[region.id] = region;
      }
    }
  }

  /// Detecta regiones personalizadas
  void _detectCustomRegions(List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Región personalizada con comentarios
      if (line.contains('// region ') || line.contains('/* region ')) {
        final regionName = _extractRegionName(line);
        if (regionName.isNotEmpty) {
          final endLine = _findRegionEnd(lines, i + 1, regionName);
          if (endLine > i) {
            final region = FoldableRegion(
              id: 'custom_${i}_$endLine',
              type: FoldableType.customRegion,
              startLine: i,
              endLine: endLine,
              level: 1,
              title: regionName,
              preview: _generatePreview(lines, i + 1, Math.min(i + 4, endLine)),
            );
            _regions[region.id] = region;
          }
        }
      }
    }
  }

  /// Extrae el nombre de una región personalizada
  String _extractRegionName(String line) {
    final match = RegExp(r'(?://|/\*)\s*region\s+(.+?)(?:\*/)?$').firstMatch(line);
    return match?.group(1)?.trim() ?? '';
  }

  /// Encuentra el final de una región personalizada
  int _findRegionEnd(List<String> lines, int start, String regionName) {
    for (int i = start; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('// endregion') || 
          line.contains('/* endregion') ||
          line.contains('// end region') ||
          line.contains('/* end region')) {
        return i;
      }
    }
    return -1;
  }

  /// Genera vista previa de una región
  String _generatePreview(List<String> lines, int start, int end) {
    final preview = <String>[];
    for (int i = start; i < end && i < lines.length && preview.length < 2; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        preview.add(line.length > 50 ? '${line.substring(0, 47)}...' : line);
      }
    }
    return preview.join(' | ');
  }

  /// Pliega una región
  bool foldRegion(String regionId) {
    if (!_regions.containsKey(regionId)) return false;
    
    _foldedRegions.add(regionId);
    return true;
  }

  /// Despliega una región
  bool unfoldRegion(String regionId) {
    return _foldedRegions.remove(regionId);
  }

  /// Alterna el estado de plegado de una región
  bool toggleRegion(String regionId) {
    if (_foldedRegions.contains(regionId)) {
      return unfoldRegion(regionId);
    } else {
      return foldRegion(regionId);
    }
  }

  /// Pliega todas las regiones
  void foldAll() {
    _foldedRegions.addAll(_regions.keys);
  }

  /// Despliega todas las regiones
  void unfoldAll() {
    _foldedRegions.clear();
  }

  /// Pliega por nivel
  void foldByLevel(int maxLevel) {
    for (final region in _regions.values) {
      if (region.level <= maxLevel) {
        _foldedRegions.add(region.id);
      }
    }
  }

  /// Pliega por tipo
  void foldByType(FoldableType type) {
    for (final region in _regions.values) {
      if (region.type == type) {
        _foldedRegions.add(region.id);
      }
    }
  }

  /// Verifica si una línea está en una región plegada
  bool isLineInFoldedRegion(int lineNumber) {
    for (final regionId in _foldedRegions) {
      final region = _regions[regionId];
      if (region != null && 
          lineNumber > region.startLine && 
          lineNumber <= region.endLine) {
        return true;
      }
    }
    return false;
  }

  /// Obtiene la región que contiene una línea
  FoldableRegion? getRegionForLine(int lineNumber) {
    for (final region in _regions.values) {
      if (lineNumber >= region.startLine && lineNumber <= region.endLine) {
        return region;
      }
    }
    return null;
  }

  /// Genera texto con regiones plegadas
  String getFoldedText() {
    if (_controller == null) return '';
    
    final text = _controller!.text;
    final lines = text.split('\n');
    final result = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      if (isLineInFoldedRegion(i)) {
        continue; // Omitir líneas en regiones plegadas
      }
      
      // Verificar si esta línea es el inicio de una región plegada
      final region = _getFoldedRegionStartingAt(i);
      if (region != null) {
        result.add('${lines[i]} ... [${region.title}]');
        i = region.endLine; // Saltar al final de la región
      } else {
        result.add(lines[i]);
      }
    }
    
    return result.join('\n');
  }

  /// Obtiene una región plegada que comienza en la línea especificada
  FoldableRegion? _getFoldedRegionStartingAt(int lineNumber) {
    for (final regionId in _foldedRegions) {
      final region = _regions[regionId];
      if (region != null && region.startLine == lineNumber) {
        return region;
      }
    }
    return null;
  }

  /// Actualiza las regiones después de cambios en el texto
  void updateRegions() {
    _detectFoldableRegions();
  }
}

/// Tipos de regiones plegables
enum FoldableType {
  markdownHeader,
  codeBlock,
  list,
  indentedBlock,
  customRegion,
}

/// Información sobre una región plegable
class FoldableRegion {
  final String id;
  final FoldableType type;
  final int startLine;
  int endLine;
  final int level;
  final String title;
  final String preview;

  FoldableRegion({
    required this.id,
    required this.type,
    required this.startLine,
    required this.endLine,
    required this.level,
    required this.title,
    required this.preview,
  });

  /// Número de líneas en la región
  int get lineCount => endLine - startLine + 1;

  /// Descripción del tipo
  String get typeDescription {
    switch (type) {
      case FoldableType.markdownHeader:
        return 'Encabezado';
      case FoldableType.codeBlock:
        return 'Código';
      case FoldableType.list:
        return 'Lista';
      case FoldableType.indentedBlock:
        return 'Bloque';
      case FoldableType.customRegion:
        return 'Región';
    }
  }

  @override
  String toString() {
    return 'FoldableRegion($id: $title [$startLine-$endLine])';
  }
}

/// Widget para mostrar controles de plegado
class CodeFoldingPanel extends StatefulWidget {
  final CodeFoldingService service;
  final Function(String) onToggleRegion;
  final VoidCallback? onClose;

  const CodeFoldingPanel({
    super.key,
    required this.service,
    required this.onToggleRegion,
    this.onClose,
  });

  @override
  State<CodeFoldingPanel> createState() => _CodeFoldingPanelState();
}

class _CodeFoldingPanelState extends State<CodeFoldingPanel> {
  FoldableType? _filterType;

  List<FoldableRegion> get _filteredRegions {
    final regions = widget.service.regions.values.toList();
    if (_filterType != null) {
      return regions.where((r) => r.type == _filterType).toList();
    }
    return regions;
  }

  @override
  Widget build(BuildContext context) {
    final regions = _filteredRegions;
    final theme = Theme.of(context);
    
    return Container(
      width: 300,
      height: 400,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            children: [
              Icon(Icons.unfold_less, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Plegado de Código',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
                iconSize: 20,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Controles globales
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  widget.service.foldAll();
                  setState(() {});
                },
                icon: const Icon(Icons.unfold_less, size: 16),
                label: const Text('Plegar Todo'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  widget.service.unfoldAll();
                  setState(() {});
                },
                icon: const Icon(Icons.unfold_more, size: 16),
                label: const Text('Desplegar'),
              ),
            ],
          ),
          
          // Filtros por tipo
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _filterType == null,
                  onSelected: (selected) {
                    setState(() {
                      _filterType = null;
                    });
                  },
                ),
                const SizedBox(width: 4),
                ...FoldableType.values.map((type) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: FilterChip(
                    label: Text(_getTypeLabel(type)),
                    selected: _filterType == type,
                    onSelected: (selected) {
                      setState(() {
                        _filterType = selected ? type : null;
                      });
                    },
                  ),
                )),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Lista de regiones
          Expanded(
            child: regions.isEmpty
                ? Center(
                    child: Text(
                      'No hay regiones plegables',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.disabledColor,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: regions.length,
                    itemBuilder: (context, index) {
                      final region = regions[index];
                      final isFolded = widget.service.foldedRegions.contains(region.id);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            isFolded ? Icons.unfold_more : Icons.unfold_less,
                            color: theme.primaryColor,
                            size: 20,
                          ),
                          title: Text(
                            region.title,
                            style: theme.textTheme.bodyMedium,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${region.typeDescription} • Líneas ${region.startLine + 1}-${region.endLine + 1}',
                                style: theme.textTheme.bodySmall,
                              ),
                              if (region.preview.isNotEmpty)
                                Text(
                                  region.preview,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: theme.disabledColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          onTap: () {
                            widget.service.toggleRegion(region.id);
                            widget.onToggleRegion(region.id);
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(FoldableType type) {
    switch (type) {
      case FoldableType.markdownHeader:
        return 'Encabezados';
      case FoldableType.codeBlock:
        return 'Código';
      case FoldableType.list:
        return 'Listas';
      case FoldableType.indentedBlock:
        return 'Bloques';
      case FoldableType.customRegion:
        return 'Regiones';
    }
  }
}

/// Implementación simple de Stack para uso interno
class Stack<T> {
  final List<T> _items = [];

  void add(T item) => _items.add(item);
  T removeLast() => _items.removeLast();
  T get last => _items.last;
  bool get isNotEmpty => _items.isNotEmpty;
  bool get isEmpty => _items.isEmpty;
}

/// Implementación simple de Math para uso interno
class Math {
  static int min(int a, int b) => a < b ? a : b;
  static int max(int a, int b) => a > b ? a : b;
}