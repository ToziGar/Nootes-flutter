import 'package:flutter/material.dart';

/// Servicio para búsqueda y reemplazo en el editor
class SearchReplaceService {
  static final SearchReplaceService _instance = SearchReplaceService._internal();
  factory SearchReplaceService() => _instance;
  SearchReplaceService._internal();

  final List<SearchMatch> _matches = [];
  int _currentMatchIndex = -1;
  String _lastSearchTerm = '';
  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _useRegex = false;
  TextEditingController? _controller;

  /// Obtiene las coincidencias actuales
  List<SearchMatch> get matches => _matches;

  /// Obtiene el índice de la coincidencia actual
  int get currentMatchIndex => _currentMatchIndex;

  /// Obtiene si hay coincidencias
  bool get hasMatches => _matches.isNotEmpty;

  /// Obtiene la coincidencia actual
  SearchMatch? get currentMatch {
    if (_currentMatchIndex >= 0 && _currentMatchIndex < _matches.length) {
      return _matches[_currentMatchIndex];
    }
    return null;
  }

  /// Inicializa el servicio con un controlador
  void initialize(TextEditingController controller) {
    _controller = controller;
  }

  /// Busca texto en el documento
  List<SearchMatch> search(String searchTerm, {
    bool caseSensitive = false,
    bool wholeWord = false,
    bool useRegex = false,
  }) {
    if (_controller == null || searchTerm.isEmpty) {
      _matches.clear();
      _currentMatchIndex = -1;
      return _matches;
    }

    _lastSearchTerm = searchTerm;
    _caseSensitive = caseSensitive;
    _wholeWord = wholeWord;
    _useRegex = useRegex;
    
    final text = _controller!.text;
    _matches.clear();
    _currentMatchIndex = -1;

    try {
      if (useRegex) {
        _searchWithRegex(text, searchTerm, caseSensitive);
      } else {
        _searchPlainText(text, searchTerm, caseSensitive, wholeWord);
      }
    } catch (e) {
      // Error en regex o búsqueda
      _matches.clear();
    }

    if (_matches.isNotEmpty) {
      _currentMatchIndex = 0;
    }

    return _matches;
  }

  /// Busca texto plano
  void _searchPlainText(String text, String searchTerm, bool caseSensitive, bool wholeWord) {
    String searchText = caseSensitive ? text : text.toLowerCase();
    String term = caseSensitive ? searchTerm : searchTerm.toLowerCase();
    
    int index = 0;
    while (index < searchText.length) {
      index = searchText.indexOf(term, index);
      if (index == -1) break;
      
      // Verificar si es palabra completa
      if (wholeWord) {
        final isWordStart = index == 0 || !_isWordCharacter(text[index - 1]);
        final isWordEnd = (index + term.length >= text.length) || 
                         !_isWordCharacter(text[index + term.length]);
        
        if (!isWordStart || !isWordEnd) {
          index++;
          continue;
        }
      }
      
      _matches.add(SearchMatch(
        start: index,
        end: index + searchTerm.length,
        text: text.substring(index, index + searchTerm.length),
        lineNumber: _getLineNumber(text, index),
        columnNumber: _getColumnNumber(text, index),
      ));
      
      index += searchTerm.length;
    }
  }

  /// Busca con expresiones regulares
  void _searchWithRegex(String text, String pattern, bool caseSensitive) {
    final regex = RegExp(pattern, caseSensitive: caseSensitive);
    
    final regexMatches = regex.allMatches(text);
    for (final match in regexMatches) {
      _matches.add(SearchMatch(
        start: match.start,
        end: match.end,
        text: match.group(0) ?? '',
        lineNumber: _getLineNumber(text, match.start),
        columnNumber: _getColumnNumber(text, match.start),
        groups: match.groups(List.generate(match.groupCount + 1, (i) => i)),
      ));
    }
  }

  /// Navega a la siguiente coincidencia
  bool goToNext() {
    if (_matches.isEmpty) return false;
    
    _currentMatchIndex = (_currentMatchIndex + 1) % _matches.length;
    _scrollToCurrentMatch();
    return true;
  }

  /// Navega a la coincidencia anterior
  bool goToPrevious() {
    if (_matches.isEmpty) return false;
    
    _currentMatchIndex = (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    _scrollToCurrentMatch();
    return true;
  }

  /// Navega a una coincidencia específica
  bool goToMatch(int index) {
    if (index < 0 || index >= _matches.length) return false;
    
    _currentMatchIndex = index;
    _scrollToCurrentMatch();
    return true;
  }

  /// Reemplaza la coincidencia actual
  bool replaceCurrent(String replacement) {
    if (_controller == null || currentMatch == null) return false;
    
    final match = currentMatch!;
    final text = _controller!.text;
    
    // Aplicar reemplazo
    final newText = text.substring(0, match.start) + 
                   replacement + 
                   text.substring(match.end);
    
    _controller!.text = newText;
    
    // Actualizar posiciones de las coincidencias restantes
    final lengthDiff = replacement.length - (match.end - match.start);
    _matches.removeAt(_currentMatchIndex);
    
    for (int i = _currentMatchIndex; i < _matches.length; i++) {
      final m = _matches[i];
      _matches[i] = SearchMatch(
        start: m.start + lengthDiff,
        end: m.end + lengthDiff,
        text: m.text,
        lineNumber: m.lineNumber,
        columnNumber: m.columnNumber,
        groups: m.groups,
      );
    }
    
    // Ajustar índice actual
    if (_currentMatchIndex >= _matches.length && _matches.isNotEmpty) {
      _currentMatchIndex = _matches.length - 1;
    } else if (_matches.isEmpty) {
      _currentMatchIndex = -1;
    }
    
    return true;
  }

  /// Reemplaza todas las coincidencias
  int replaceAll(String replacement) {
    if (_controller == null || _matches.isEmpty) return 0;
    
    final text = _controller!.text;
    String newText = text;
    int replacements = 0;
    
    // Reemplazar de atrás hacia adelante para no afectar las posiciones
    for (int i = _matches.length - 1; i >= 0; i--) {
      final match = _matches[i];
      newText = newText.substring(0, match.start) + 
               replacement + 
               newText.substring(match.end);
      replacements++;
    }
    
    _controller!.text = newText;
    _matches.clear();
    _currentMatchIndex = -1;
    
    return replacements;
  }

  /// Busca y reemplaza en una sola operación
  int findAndReplaceAll(String searchTerm, String replacement, {
    bool caseSensitive = false,
    bool wholeWord = false,
    bool useRegex = false,
  }) {
    search(searchTerm, 
           caseSensitive: caseSensitive,
           wholeWord: wholeWord,
           useRegex: useRegex);
    return replaceAll(replacement);
  }

  /// Obtiene estadísticas de la búsqueda
  SearchStats getSearchStats() {
    return SearchStats(
      totalMatches: _matches.length,
      currentMatch: _currentMatchIndex + 1,
      searchTerm: _lastSearchTerm,
      caseSensitive: _caseSensitive,
      wholeWord: _wholeWord,
      useRegex: _useRegex,
    );
  }

  /// Limpia los resultados de búsqueda
  void clearSearch() {
    _matches.clear();
    _currentMatchIndex = -1;
    _lastSearchTerm = '';
  }

  /// Resalta las coincidencias en el texto
  TextSpan highlightMatches(String text, TextStyle defaultStyle, TextStyle highlightStyle) {
    if (_matches.isEmpty) {
      return TextSpan(text: text, style: defaultStyle);
    }
    
    final spans = <TextSpan>[];
    int lastEnd = 0;
    
    for (int i = 0; i < _matches.length; i++) {
      final match = _matches[i];
      
      // Agregar texto antes de la coincidencia
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: defaultStyle,
        ));
      }
      
      // Agregar coincidencia resaltada
      final isCurrentMatch = i == _currentMatchIndex;
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: isCurrentMatch 
            ? highlightStyle.copyWith(backgroundColor: Colors.orange)
            : highlightStyle,
      ));
      
      lastEnd = match.end;
    }
    
    // Agregar texto restante
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: defaultStyle,
      ));
    }
    
    return TextSpan(children: spans);
  }

  /// Verifica si un carácter es parte de una palabra
  bool _isWordCharacter(String char) {
    return RegExp(r'[a-zA-Z0-9_]').hasMatch(char);
  }

  /// Obtiene el número de línea de una posición
  int _getLineNumber(String text, int position) {
    return text.substring(0, position).split('\n').length;
  }

  /// Obtiene el número de columna de una posición
  int _getColumnNumber(String text, int position) {
    final beforePosition = text.substring(0, position);
    final lastNewlineIndex = beforePosition.lastIndexOf('\n');
    return position - lastNewlineIndex;
  }

  /// Hace scroll hacia la coincidencia actual
  void _scrollToCurrentMatch() {
    if (_controller == null || currentMatch == null) return;
    
    final match = currentMatch!;
    _controller!.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
  }
}

/// Información sobre una coincidencia de búsqueda
class SearchMatch {
  final int start;
  final int end;
  final String text;
  final int lineNumber;
  final int columnNumber;
  final List<String?>? groups; // Para regex con grupos

  const SearchMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.lineNumber,
    required this.columnNumber,
    this.groups,
  });

  @override
  String toString() {
    return 'SearchMatch("$text" at $lineNumber:$columnNumber [$start-$end])';
  }
}

/// Estadísticas de búsqueda
class SearchStats {
  final int totalMatches;
  final int currentMatch;
  final String searchTerm;
  final bool caseSensitive;
  final bool wholeWord;
  final bool useRegex;

  const SearchStats({
    required this.totalMatches,
    required this.currentMatch,
    required this.searchTerm,
    required this.caseSensitive,
    required this.wholeWord,
    required this.useRegex,
  });

  String get statusText {
    if (totalMatches == 0) {
      return 'Sin coincidencias';
    }
    return '$currentMatch de $totalMatches';
  }
}

/// Widget de interfaz para búsqueda y reemplazo
class SearchReplacePanel extends StatefulWidget {
  final SearchReplaceService service;
  final Function(String) onSearch;
  final Function(String) onReplace;
  final VoidCallback? onClose;

  const SearchReplacePanel({
    super.key,
    required this.service,
    required this.onSearch,
    required this.onReplace,
    this.onClose,
  });

  @override
  State<SearchReplacePanel> createState() => _SearchReplacePanelState();
}

class _SearchReplacePanelState extends State<SearchReplacePanel> {
  final _searchController = TextEditingController();
  final _replaceController = TextEditingController();
  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _useRegex = false;
  bool _showReplace = false;

  @override
  void dispose() {
    _searchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  void _performSearch() {
    widget.service.search(
      _searchController.text,
      caseSensitive: _caseSensitive,
      wholeWord: _wholeWord,
      useRegex: _useRegex,
    );
    widget.onSearch(_searchController.text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.service.getSearchStats();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de búsqueda
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stats.statusText,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (_) => _performSearch(),
                  onSubmitted: (_) => widget.service.goToNext(),
                ),
              ),
              IconButton(
                onPressed: widget.service.hasMatches ? () {
                  widget.service.goToPrevious();
                  setState(() {});
                } : null,
                icon: const Icon(Icons.keyboard_arrow_up),
                tooltip: 'Anterior',
              ),
              IconButton(
                onPressed: widget.service.hasMatches ? () {
                  widget.service.goToNext();
                  setState(() {});
                } : null,
                icon: const Icon(Icons.keyboard_arrow_down),
                tooltip: 'Siguiente',
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showReplace = !_showReplace;
                  });
                },
                icon: Icon(_showReplace ? Icons.find_replace : Icons.find_in_page),
                tooltip: _showReplace ? 'Solo buscar' : 'Buscar y reemplazar',
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
              ),
            ],
          ),
          
          // Opciones de búsqueda
          Row(
            children: [
              Checkbox(
                value: _caseSensitive,
                onChanged: (value) {
                  setState(() {
                    _caseSensitive = value ?? false;
                    _performSearch();
                  });
                },
              ),
              const Text('Aa'),
              const SizedBox(width: 16),
              Checkbox(
                value: _wholeWord,
                onChanged: (value) {
                  setState(() {
                    _wholeWord = value ?? false;
                    _performSearch();
                  });
                },
              ),
              const Text('Ab'),
              const SizedBox(width: 16),
              Checkbox(
                value: _useRegex,
                onChanged: (value) {
                  setState(() {
                    _useRegex = value ?? false;
                    _performSearch();
                  });
                },
              ),
              const Text('.*'),
            ],
          ),
          
          // Barra de reemplazo
          if (_showReplace) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replaceController,
                    decoration: const InputDecoration(
                      hintText: 'Reemplazar con...',
                      prefixIcon: Icon(Icons.find_replace),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.service.hasMatches ? () {
                    widget.service.replaceCurrent(_replaceController.text);
                    widget.onReplace(_replaceController.text);
                    setState(() {});
                  } : null,
                  icon: const Icon(Icons.find_replace),
                  tooltip: 'Reemplazar',
                ),
                IconButton(
                  onPressed: widget.service.hasMatches ? () {
                    final count = widget.service.replaceAll(_replaceController.text);
                    widget.onReplace(_replaceController.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$count reemplazos realizados')),
                    );
                    setState(() {});
                  } : null,
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Reemplazar todo',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}