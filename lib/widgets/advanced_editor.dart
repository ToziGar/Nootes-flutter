import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auto_complete_service.dart';
import '../services/syntax_highlight_service.dart';
import '../services/multi_cursor_service.dart' as multi_cursor;
import '../services/bracket_matching_service.dart' as bracket;
import '../services/search_replace_service.dart' as search;
import '../services/code_folding_service.dart' as folding;
import '../services/smart_indentation_service.dart' as indentation;
import '../services/command_palette_service.dart' as commands;
import '../services/zen_mode_service.dart' as zen;
import '../theme/app_colors.dart';
import '../theme/color_utils.dart';

/// Widget de editor avanzado con funciones profesionales
class AdvancedEditor extends StatefulWidget {
  final String initialText;
  final Function(String) onTextChanged;
  final bool syntaxHighlighting;
  final bool autoComplete;
  final bool showLineNumbers;
  final bool showMinimap;
  final bool wordWrap;
  final double fontSize;
  final ThemeMode themeMode;

  const AdvancedEditor({
    super.key,
    required this.initialText,
    required this.onTextChanged,
    this.syntaxHighlighting = true,
    this.autoComplete = true,
    this.showLineNumbers = true,
    this.showMinimap = false,
    this.wordWrap = true,
    this.fontSize = 16.0,
    this.themeMode = ThemeMode.system,
  });

  @override
  State<AdvancedEditor> createState() => _AdvancedEditorState();
}

class _AdvancedEditorState extends State<AdvancedEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late ScrollController _editorScrollController;
  late ScrollController _lineNumbersScrollController;
  late ScrollController _minimapScrollController;
  
  final AutoCompleteService _autoCompleteService = AutoCompleteService();
  final SyntaxHighlightService _syntaxService = SyntaxHighlightService();
  
  List<AutoCompleteSuggestion> _suggestions = [];
  List<CodeSnippet> _snippets = [];
  bool _showSuggestions = false;
  bool _showSnippets = false;
  int _selectedSuggestionIndex = 0;
  String _currentWord = '';
  int _currentWordStart = 0;
  
  // Estado del editor
  int _currentLine = 1;
  int _currentColumn = 1;
  int _totalLines = 1;
  bool _isCtrlPressed = false;

  // Servicios adicionales del editor ultra-avanzado
  late final multi_cursor.MultiCursorService _multiCursorService;
  late final bracket.BracketMatchingService _bracketService;
  late final search.SearchReplaceService _searchService;
  late final folding.CodeFoldingService _foldingService;
  late final indentation.SmartIndentationService _indentationService;
  late final commands.CommandPaletteService _commandService;
  late final zen.ZenModeService _zenService;

  // Estados para funcionalidades avanzadas
  bool _showSearchPanel = false;
  bool _isInZenMode = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    _editorScrollController = ScrollController();
    _lineNumbersScrollController = ScrollController();
    _minimapScrollController = ScrollController();

    // Mantener sincronizado el scroll de los números de línea con el editor
    _editorScrollController.addListener(() {
      if (!_lineNumbersScrollController.hasClients) return;
      final offset = _editorScrollController.offset;
      // Intentar mantener los scrolls alineados, ignorando desbordes
      try {
        _lineNumbersScrollController.jumpTo(
          offset.clamp(
            0.0,
            (_lineNumbersScrollController.position.maxScrollExtent),
          ),
        );
      } catch (_) {
        // En algunos casos (cambio de tamaño), la posición todavía no está lista
      }
    });
    
    // Inicializar servicios básicos
    _autoCompleteService.initialize();
    
    // Inicializar servicios ultra-avanzados
    _multiCursorService = multi_cursor.MultiCursorService();
    _bracketService = bracket.BracketMatchingService();
    _searchService = search.SearchReplaceService();
    _foldingService = folding.CodeFoldingService();
    _indentationService = indentation.SmartIndentationService();
    _commandService = commands.CommandPaletteService();
    _zenService = zen.ZenModeService();
    
    // Configurar servicios
    _multiCursorService.initialize(_controller);
    _bracketService.initialize(_controller);
    _searchService.initialize(_controller);
    _foldingService.initialize(_controller);
    _indentationService.initialize(_controller);
    _commandService.initialize();
    
    _controller.addListener(_onTextChanged);
    _updateStats();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _editorScrollController.dispose();
    _lineNumbersScrollController.dispose();
    _minimapScrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    widget.onTextChanged(text);
    _updateStats();
    
    if (widget.autoComplete) {
      _handleAutoComplete();
    }
  }

  void _updateStats() {
    final text = _controller.text;
    final lines = text.split('\n');
    final selection = _controller.selection;
    
    setState(() {
      _totalLines = lines.length;
      
      if (selection.isValid) {
        int line = 1;
        int column = 1;
        
        for (int i = 0; i < selection.start && i < text.length; i++) {
          if (text[i] == '\n') {
            line++;
            column = 1;
          } else {
            column++;
          }
        }
        
        _currentLine = line;
        _currentColumn = column;
      }
    });
  }

  void _handleAutoComplete() async {
    final selection = _controller.selection;
    if (!selection.isValid) return;
    
    final text = _controller.text;
    final cursorPos = selection.start;
    
    // Encontrar la palabra actual
    int wordStart = cursorPos;
    while (wordStart > 0 && text[wordStart - 1] != ' ' && text[wordStart - 1] != '\n') {
      wordStart--;
    }
    
    int wordEnd = cursorPos;
    while (wordEnd < text.length && text[wordEnd] != ' ' && text[wordEnd] != '\n') {
      wordEnd++;
    }
    
    final currentWord = text.substring(wordStart, cursorPos);
    
    if (currentWord.length >= 2) {
      final suggestions = await _autoCompleteService.getSuggestions(currentWord, _controller.selection.start);
      final snippets = _autoCompleteService.getCodeSnippets(currentWord);
      
      setState(() {
        _currentWord = currentWord;
        _currentWordStart = wordStart;
        _suggestions = suggestions;
        _snippets = snippets;
        _showSuggestions = suggestions.isNotEmpty;
        _showSnippets = snippets.isNotEmpty;
        _selectedSuggestionIndex = 0;
      });
    } else {
      setState(() {
        _showSuggestions = false;
        _showSnippets = false;
      });
    }
  }

  void _applySuggestion(String suggestion) {
    final text = _controller.text;
    final newText = text.substring(0, _currentWordStart) + 
                   suggestion + 
                   text.substring(_currentWordStart + _currentWord.length);
    
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: _currentWordStart + suggestion.length,
    );
    
    setState(() {
      _showSuggestions = false;
      _showSnippets = false;
    });
    
    _autoCompleteService.addUserWord(suggestion);
  }

  void _applySnippet(CodeSnippet snippet) {
    final text = _controller.text;
    String template = snippet.template;
    
    // Procesar variables del snippet (simple implementación)
    template = template.replaceAll(RegExp(r'\$\{\d+:([^}]*)\}'), r'$1');
    template = template.replaceAll(RegExp(r'\$\d+'), '');
    
    final newText = text.substring(0, _currentWordStart) + 
                   template + 
                   text.substring(_currentWordStart + _currentWord.length);
    
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: _currentWordStart + template.length,
    );
    
    setState(() {
      _showSuggestions = false;
      _showSnippets = false;
    });
  }

  Widget _buildSuggestionsPanel() {
    if (!_showSuggestions && !_showSnippets) return const SizedBox.shrink();
    
    return Positioned(
      left: 50,
      top: 100,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 300,
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacityCompat(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showSuggestions) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Sugerencias',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      final isSelected = index == _selectedSuggestionIndex;
                      
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        leading: Icon(
                          suggestion.icon,
                          color: suggestion.color,
                          size: 16,
                        ),
                        title: Text(
                          suggestion.text,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: suggestion.frequency > 1
                            ? Text(
                                'Usada ${suggestion.frequency} veces',
                                style: const TextStyle(fontSize: 10),
                              )
                            : null,
                        onTap: () => _applySuggestion(suggestion.text),
                      );
                    },
                  ),
                ),
              ],
              if (_showSnippets) ...[
                if (_showSuggestions) const Divider(),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Snippets',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _snippets.length,
                    itemBuilder: (context, index) {
                      final snippet = _snippets[index];
                      
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.code,
                          color: Colors.orange,
                          size: 16,
                        ),
                        title: Text(
                          snippet.trigger,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          snippet.description,
                          style: const TextStyle(fontSize: 10),
                        ),
                        onTap: () => _applySnippet(snippet),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineNumbers() {
    if (!widget.showLineNumbers) return const SizedBox.shrink();
    
    return Container(
      width: 50,
      color: Theme.of(context).scaffoldBackgroundColor.withOpacityCompat(0.5),
      child: ListView.builder(
        controller: _lineNumbersScrollController,
        itemCount: _totalLines,
        itemBuilder: (context, index) {
          final lineNumber = index + 1;
          final isCurrentLine = lineNumber == _currentLine;
          
          return Container(
            height: widget.fontSize * 1.5,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 8),
            color: isCurrentLine ? AppColors.primary.withOpacityCompat(0.1) : null,
            child: Text(
              lineNumber.toString(),
              style: TextStyle(
                fontSize: widget.fontSize * 0.8,
                color: isCurrentLine 
                    ? AppColors.primary
                    : Theme.of(context).textTheme.bodySmall?.color?.withOpacityCompat(0.6),
                fontFamily: 'monospace',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMinimap() {
    if (!widget.showMinimap) return const SizedBox.shrink();
    
    return Container(
      width: 100,
      color: Theme.of(context).scaffoldBackgroundColor.withOpacityCompat(0.8),
      child: SingleChildScrollView(
        controller: _minimapScrollController,
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Text(
            _controller.text,
            style: TextStyle(
              fontSize: 4,
              fontFamily: 'monospace',
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacityCompat(0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Ln $_currentLine, Col $_currentColumn',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Líneas: $_totalLines',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text(
            'Caracteres: ${_controller.text.length}',
            style: const TextStyle(fontSize: 12),
          ),
          const Spacer(),
          if (widget.syntaxHighlighting)
            const Icon(
              Icons.palette,
              size: 16,
              color: Colors.green,
            ),
          if (widget.autoComplete) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Colors.blue,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Expanded(
      child: Row(
        children: [
          if (widget.showLineNumbers) _buildLineNumbers(),
          Expanded(
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: widget.syntaxHighlighting
                      ? _buildSyntaxHighlightedEditor()
                      : _buildPlainEditor(),
                ),
                _buildSuggestionsPanel(),
              ],
            ),
          ),
          if (widget.showMinimap) _buildMinimap(),
        ],
      ),
    );
  }

  Widget _buildSyntaxHighlightedEditor() {
    final theme = widget.themeMode == ThemeMode.dark
        ? SyntaxTheme.darkTheme()
        : SyntaxTheme.defaultTheme();
    
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      scrollController: _editorScrollController,
      maxLines: null,
      expands: true,
      style: TextStyle(
        fontSize: widget.fontSize,
        fontFamily: 'monospace',
        height: 1.5,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (text) => _onTextChanged(),
      onTap: () => _updateStats(),
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
        // Construir texto con resaltado de sintaxis
        final highlightedText = _syntaxService.highlightText(_controller.text, theme: theme);
        
        return RichText(
          text: highlightedText,
        );
      },
    );
  }

  Widget _buildPlainEditor() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      scrollController: _editorScrollController,
      maxLines: null,
      expands: true,
      style: TextStyle(
        fontSize: widget.fontSize,
        fontFamily: 'monospace',
        height: 1.5,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (text) => _onTextChanged(),
      onTap: () => _updateStats(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          // Manejar atajos de teclado ultra-avanzados
          if (_handleKeyboardShortcuts(event)) {
            return;
          }
          
          // Manejar atajos de teclado básicos
          if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
              event.logicalKey == LogicalKeyboardKey.controlRight) {
            _isCtrlPressed = true;
          }
          
          // Ctrl + Espacio para autocompletado
          if (_isCtrlPressed && event.logicalKey == LogicalKeyboardKey.space) {
            _handleAutoComplete();
          }
          
          // Escape para cerrar sugerencias
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() {
              _showSuggestions = false;
              _showSnippets = false;
            });
          }
          
          // Navegación en sugerencias
          if (_showSuggestions) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              setState(() {
                _selectedSuggestionIndex = 
                    (_selectedSuggestionIndex + 1) % _suggestions.length;
              });
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              setState(() {
                _selectedSuggestionIndex = 
                    (_selectedSuggestionIndex - 1 + _suggestions.length) % _suggestions.length;
              });
            } else if (event.logicalKey == LogicalKeyboardKey.enter) {
              if (_selectedSuggestionIndex < _suggestions.length) {
                _applySuggestion(_suggestions[_selectedSuggestionIndex].text);
              }
            }
          }
        } else if (event is KeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
              event.logicalKey == LogicalKeyboardKey.controlRight) {
            _isCtrlPressed = false;
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            _buildEditor(),
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  // Funcionalidades ultra-avanzadas
  bool _handleKeyboardShortcuts(KeyEvent event) {
    if (event is KeyDownEvent && HardwareKeyboard.instance.isControlPressed) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyF:
          // Abrir búsqueda
          setState(() {
            _showSearchPanel = !_showSearchPanel;
          });
          return true;
        case LogicalKeyboardKey.keyH:
          // Buscar y reemplazar
          setState(() {
            _showSearchPanel = true;
          });
          return true;
        case LogicalKeyboardKey.keyP:
          if (HardwareKeyboard.instance.isShiftPressed) {
            // Paleta de comandos
            _showCommandPalette();
            return true;
          }
          break;
        case LogicalKeyboardKey.keyD:
          // Cursores múltiples
          _multiCursorService.addCursor(_controller.selection.start);
          return true;
        case LogicalKeyboardKey.keyG:
          // Ir a línea
          _showGoToLineDialog();
          return true;
      }
    }
    
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
      // Modo Zen con F11
      _toggleZenMode();
      return true;
    }
    
    return false;
  }

  void _toggleZenMode() {
    setState(() {
      _isInZenMode = !_isInZenMode;
    });
    if (_isInZenMode) {
      _zenService.enterZenMode(_buildMainEditor());
    } else {
      _zenService.exitZenMode();
    }
  }

  Widget _buildMainEditor() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        style: TextStyle(
          fontSize: widget.fontSize,
          fontFamily: 'monospace',
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }

  void _showCommandPalette() {
    showDialog(
      context: context,
      builder: (context) => commands.CommandPalette(
        service: _commandService,
        onCommandExecuted: (commandId) {
          // Ejecutar comando
          _commandService.executeCommand(commandId);
        },
      ),
    );
  }

  void _showGoToLineDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Ir a línea'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Número de línea',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (value) {
              final lineNumber = int.tryParse(value);
              if (lineNumber != null && lineNumber > 0) {
                _goToLine(lineNumber);
              }
              Navigator.of(context).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final lineNumber = int.tryParse(controller.text);
                if (lineNumber != null && lineNumber > 0) {
                  _goToLine(lineNumber);
                }
                Navigator.of(context).pop();
              },
              child: const Text('Ir'),
            ),
          ],
        );
      },
    );
  }

  void _goToLine(int lineNumber) {
    final lines = _controller.text.split('\n');
    if (lineNumber <= lines.length) {
      int position = 0;
      for (int i = 0; i < lineNumber - 1; i++) {
        position += lines[i].length + 1; // +1 for newline
      }
      _controller.selection = TextSelection.collapsed(offset: position);
      setState(() {
        _currentLine = lineNumber;
      });
    }
  }
}