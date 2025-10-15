
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import '../services/auth_service.dart';
import '../services/editor_config_service.dart';

// Keyboard shortcut intents (top-level)
class BoldEditorIntent extends Intent {
  const BoldEditorIntent();
}
class ItalicEditorIntent extends Intent {
  const ItalicEditorIntent();
}
class SaveEditorIntent extends Intent {
  const SaveEditorIntent();
}
class FullscreenEditorIntent extends Intent {
  const FullscreenEditorIntent();
}

/// Editor mejorado con funcionalidades avanzadas
class EnhancedNoteEditor extends StatefulWidget {
  final String? noteId;
  final String? initialContent;
  final String? initialTitle;
  final ValueChanged<String>? onContentChanged;
  final ValueChanged<String>? onTitleChanged;
  final VoidCallback? onSave;
  final bool readOnly;
  final EditorMode mode;
  final Map<String, dynamic>? metadata;

  const EnhancedNoteEditor({
    super.key,
    this.noteId,
    this.initialContent,
    this.initialTitle,
    this.onContentChanged,
    this.onTitleChanged,
    this.onSave,
    this.readOnly = false,
    this.mode = EditorMode.wysiwyg,
    this.metadata,
  });

  @override
  State<EnhancedNoteEditor> createState() => _EnhancedNoteEditorState();
}

class _EnhancedNoteEditorState extends State<EnhancedNoteEditor> with TickerProviderStateMixin, WidgetsBindingObserver {
  final _configService = EditorConfigService();
  // Controllers y estado principal
  late QuillController _quillController;
  late TextEditingController _titleController;
  late TextEditingController _markdownController;
  late FocusNode _titleFocusNode;
  late FocusNode _editorFocusNode;
  late ScrollController _scrollController;

  // Configuración del editor
  EditorSettings _settings = EditorSettings.defaultSettings();
  EditorMode _currentMode = EditorMode.wysiwyg;
  bool _isFullscreen = false;
  final bool _showToolbar = true;

  // Auto-guardado
  Timer? _autoSaveTimer;
  DateTime? _lastSaveTime;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  // Estado de UI
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Funcionalidades avanzadas
  final Map<String, dynamic> _statistics = {};

  // Autocompletado y sugerencias
  bool _showAutocomplete = false;
  List<AutocompleteSuggestion> _suggestions = [];

  // Colaboración en tiempo real (placeholder) - reservado para futura implementación
  // (Se removió la lógica para evitar warnings hasta implementar colaboración real)


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeEditor();
    _setupAnimations();
    _loadSettings();
    _initializeContent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _markdownController.dispose();
    _titleFocusNode.dispose();
    _editorFocusNode.dispose();
    _scrollController.dispose();
    _quillController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _initializeEditor() {
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _markdownController = TextEditingController(text: widget.initialContent ?? '');
    _titleFocusNode = FocusNode();
    _editorFocusNode = FocusNode();
    _scrollController = ScrollController();
    
    // Inicializar Quill Controller
    _quillController = QuillController.basic();
    
    // Listeners
    _titleController.addListener(_onTitleChanged);
    _markdownController.addListener(_onContentChanged);
    _quillController.addListener(_onQuillChanged);
  // Listener de foco (por ahora sin lógica específica; reservado para futuras mejoras)
  _editorFocusNode.addListener(_onFocusChanged);

    _currentMode = widget.mode;
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadSettings() async {
    // Cargar configuración persistente del usuario
    final fontSize = await _configService.getFontSize();
    final fontFamily = await _configService.getFontFamily();
    final showLineNumbers = await _configService.getShowLineNumbers();
    final enableSpellCheck = await _configService.getSyntaxHighlighting();
    final enableAutoSave = await _configService.getAutoSave();
    final autoSaveDelay = await _configService.getAutoSaveDelay();
    setState(() {
      _settings = EditorSettings(
        fontSize: fontSize,
        lineHeight: 1.5,
        fontFamily: fontFamily,
        showLineNumbers: showLineNumbers,
        enableSpellCheck: enableSpellCheck,
        enableAutoSave: enableAutoSave,
        autoSaveDelay: autoSaveDelay,
        enableCollaboration: false,
      );
    });
  }

  void _initializeContent() {
    if (widget.initialContent != null) {
      try {
        // Intentar cargar como Delta JSON
        final delta = Delta.fromJson(jsonDecode(widget.initialContent!));
        _quillController.document = Document.fromDelta(delta);
      } catch (e) {
        // Si falla, cargar como texto plano
        _quillController.document.insert(0, widget.initialContent!);
      }
    }
  }

  // Callbacks de cambios
  void _onTitleChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
    widget.onTitleChanged?.call(_titleController.text);
    _scheduleAutoSave();
  }

  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
    widget.onContentChanged?.call(_markdownController.text);
    _scheduleAutoSave();
    _updateStatistics();
  }

  void _onQuillChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
    final deltaJson = jsonEncode(_quillController.document.toDelta().toJson());
    widget.onContentChanged?.call(deltaJson);
    _scheduleAutoSave();
    _updateStatistics();
    _detectAutocomplete();
  }

  void _onFocusChanged() {
    // Espacio para lógica futura (por ejemplo: mostrar ayudas contextuales)
  }

  // Auto-guardado
  void _scheduleAutoSave() {
  if (!_settings.enableAutoSave || widget.readOnly) return;
    
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _performAutoSave();
    });
  }

  Future<void> _performAutoSave() async {
    if (_isSaving || !_hasUnsavedChanges) return;

    setState(() => _isSaving = true);
    
    try {
      widget.onSave?.call();
      setState(() {
        _hasUnsavedChanges = false;
        _lastSaveTime = DateTime.now();
      });
    } catch (e) {
      debugPrint('Error en auto-guardado: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Estadísticas y métricas
  void _updateStatistics() {
    final content = _getCurrentContent();
    _statistics['wordCount'] = _countWords(content);
    _statistics['characterCount'] = content.length;
    _statistics['paragraphCount'] = _countParagraphs(content);
    _statistics['lastModified'] = DateTime.now();
  }

  int _countWords(String text) {
    return text.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  int _countParagraphs(String text) {
    return text.split('\n').where((line) => line.trim().isNotEmpty).length;
  }

  String _getCurrentContent() {
    if (_currentMode == EditorMode.markdown) {
      return _markdownController.text;
    } else {
      return _quillController.document.toPlainText();
    }
  }

  // (Eliminado) Sesiones de escritura – se simplifica para reducir complejidad inicial

  // Autocompletado inteligente
  void _detectAutocomplete() {
    final selection = _quillController.selection;
    if (!selection.isValid) return;

    final text = _quillController.document.toPlainText();
    final position = selection.baseOffset;
    
    // Detectar patrones de autocompletado
    final beforeCursor = text.substring(0, position);
    
    // Detección de menciones @
    final atMatch = RegExp(r'@(\w*)$').firstMatch(beforeCursor);
    if (atMatch != null) {
      _showAutocompleteForMentions(atMatch.group(1) ?? '');
      return;
    }

    // Detección de hashtags #
    final hashMatch = RegExp(r'#(\w*)$').firstMatch(beforeCursor);
    if (hashMatch != null) {
      _showAutocompleteForTags(hashMatch.group(1) ?? '');
      return;
    }

    // Detección de comandos /
    final commandMatch = RegExp(r'/(\w*)$').firstMatch(beforeCursor);
    if (commandMatch != null) {
      _showAutocompleteForCommands(commandMatch.group(1) ?? '');
      return;
    }

    _hideAutocomplete();
  }

  void _showAutocompleteForMentions(String query) {
    // Implementar autocompletado de menciones
  _showAutocomplete = true; // mostrar overlay (implementación futura de resultados reales)
    setState(() {});
  }

  void _showAutocompleteForTags(String query) {
    // Implementar autocompletado de tags
  _showAutocomplete = true;
    setState(() {});
  }

  void _showAutocompleteForCommands(String query) {
    // Implementar autocompletado de comandos
    final commands = [
      AutocompleteSuggestion(
        text: '/heading',
        description: 'Insertar encabezado',
        icon: Icons.title,
        action: () => _insertHeading(),
      ),
      AutocompleteSuggestion(
        text: '/table',
        description: 'Insertar tabla',
        icon: Icons.table_chart,
        action: () => _insertTable(),
      ),
      AutocompleteSuggestion(
        text: '/code',
        description: 'Bloque de código',
        icon: Icons.code,
        action: () => _insertCodeBlock(),
      ),
    ];

    _suggestions = commands
        .where((cmd) => cmd.text.toLowerCase().contains(query.toLowerCase()))
        .toList();
    
  _showAutocomplete = true;
    setState(() {});
  }

  void _hideAutocomplete() {
    if (_showAutocomplete) {
      setState(() {
        _showAutocomplete = false;
        _suggestions.clear();
      });
    }
  }

  // Acciones del editor
  void _insertHeading() {
    // Implementar inserción de encabezado
  }

  void _insertTable() {
    // Implementar inserción de tabla
  }

  void _insertCodeBlock() {
    // Implementar inserción de bloque de código
  }

  void _toggleMode() {
    setState(() {
      if (_currentMode == EditorMode.wysiwyg) {
        _currentMode = EditorMode.markdown;
        // Convertir contenido de Quill a Markdown
        final plainText = _quillController.document.toPlainText();
        _markdownController.text = plainText;
      } else {
        _currentMode = EditorMode.wysiwyg;
        // Convertir Markdown a Quill
        _quillController.document.insert(0, _markdownController.text);
      }
    });
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => EditorSettingsDialog(
        settings: EditorSettings(
          fontSize: _settings.fontSize,
          lineHeight: _settings.lineHeight,
          fontFamily: _settings.fontFamily,
          showLineNumbers: _settings.showLineNumbers,
          enableSpellCheck: _settings.enableSpellCheck,
          enableAutoSave: _settings.enableAutoSave,
          autoSaveDelay: _settings.autoSaveDelay,
          enableCollaboration: _settings.enableCollaboration,
        ),
        onSettingsChanged: (newConfig) async {
          // Convert EditorSettings to EditorConfig if needed
          final EditorConfig config = newConfig is EditorConfig
              ? newConfig as EditorConfig
              : EditorConfig(
                  syntaxHighlighting: (newConfig as dynamic).enableSpellCheck,
                  autoComplete: true,
                  showLineNumbers: (newConfig as dynamic).showLineNumbers,
                  showMinimap: false,
                  wordWrap: true,
                  fontSize: (newConfig as dynamic).fontSize,
                  fontFamily: (newConfig as dynamic).fontFamily,
                  tabSize: 4,
                  insertSpaces: true,
                  autoSave: (newConfig as dynamic).enableAutoSave,
                  autoSaveDelay: (newConfig as dynamic).autoSaveDelay,
                  bracketMatching: true,
                  showWhitespace: false,
                  trimTrailingWhitespace: true,
                );
          await _configService.setEditorConfig(config);
          setState(() {
            _settings = EditorSettings(
              fontSize: config.fontSize,
              lineHeight: 1.5,
              fontFamily: config.fontFamily,
              showLineNumbers: config.showLineNumbers,
              enableSpellCheck: config.syntaxHighlighting,
              enableAutoSave: config.autoSave,
              autoSaveDelay: config.autoSaveDelay,
              enableCollaboration: false,
            );
          });
        },
      ),
    );
  }

  Future<void> _insertMedia() async {
    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null || widget.noteId == null) return;

      // Usar el servicio de almacenamiento mejorado
      // Implementar selector de archivos y subida
      
    } catch (e) {
      debugPrint('Error insertando media: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB): const BoldEditorIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI): const ItalicEditorIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SaveEditorIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyF): const FullscreenEditorIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          BoldEditorIntent: CallbackAction<BoldEditorIntent>(onInvoke: (intent) => _handleBoldShortcut()),
          ItalicEditorIntent: CallbackAction<ItalicEditorIntent>(onInvoke: (intent) => _handleItalicShortcut()),
          SaveEditorIntent: CallbackAction<SaveEditorIntent>(onInvoke: (intent) => _handleSaveShortcut()),
          FullscreenEditorIntent: CallbackAction<FullscreenEditorIntent>(onInvoke: (intent) => _toggleFullscreen()),
        },
        child: Focus(
          autofocus: true,
          child: Semantics(
            label: 'Editor de notas',
            explicitChildNodes: true,
            child: Scaffold(
        backgroundColor: _isFullscreen 
          ? Theme.of(context).scaffoldBackgroundColor
          : AppColors.surfaceOverlay,
              body: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      if (!_isFullscreen) _buildHeader(),
                      if (_showToolbar && !widget.readOnly) _buildToolbar(),
                      Expanded(child: _buildEditor()),
                      if (!widget.readOnly) _buildStatusBar(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBoldShortcut() {
    if (_currentMode == EditorMode.markdown) {
      _insertMarkdown('**', '**');
    } else {
      _quillController.formatSelection(Attribute.bold);
    }
  }

  void _handleItalicShortcut() {
    if (_currentMode == EditorMode.markdown) {
      _insertMarkdown('*', '*');
    } else {
      _quillController.formatSelection(Attribute.italic);
    }
  }

  void _handleSaveShortcut() {
    if (!_isSaving && _hasUnsavedChanges) {
      widget.onSave?.call();
      setState(() {
        _hasUnsavedChanges = false;
        _lastSaveTime = DateTime.now();
      });
    }
  }


  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              readOnly: widget.readOnly,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: 'Título de la nota...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildHeaderActions(),
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasUnsavedChanges)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: 8),
        if (_isSaving)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            onPressed: _isFullscreen ? _toggleFullscreen : null,
            icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
            tooltip: _isFullscreen ? 'Salir de pantalla completa' : 'Pantalla completa',
          ),
        IconButton(
          onPressed: _showSettings,
          icon: const Icon(Icons.settings),
          tooltip: 'Configuración del editor',
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildModeToggle(),
          const SizedBox(width: 16),
          if (_currentMode == EditorMode.wysiwyg) 
            _buildQuillToolbar()
          else
            _buildMarkdownToolbar(),
          const Spacer(),
          _buildUtilityActions(),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return SegmentedButton<EditorMode>(
      segments: const [
        ButtonSegment(
          value: EditorMode.wysiwyg,
          label: Text('Visual'),
          icon: Icon(Icons.wysiwyg),
        ),
        ButtonSegment(
          value: EditorMode.markdown,
          label: Text('Markdown'),
          icon: Icon(Icons.code),
        ),
      ],
      selected: {_currentMode},
      onSelectionChanged: (Set<EditorMode> selection) {
        if (selection.isNotEmpty) {
          _toggleMode();
        }
      },
    );
  }

  Widget _buildQuillToolbar() {
    // Toolbar personalizada mínima para evitar dependencias de API cambiantes de flutter_quill
    return Row(
      children: [
        _formatButton(icon: Icons.format_bold, tooltip: 'Negrita', attribute: Attribute.bold),
        _formatButton(icon: Icons.format_italic, tooltip: 'Cursiva', attribute: Attribute.italic),
        _formatButton(icon: Icons.format_underline, tooltip: 'Subrayado', attribute: Attribute.underline),
        _formatButton(icon: Icons.strikethrough_s, tooltip: 'Tachado', attribute: Attribute.strikeThrough),
        const VerticalDivider(),
        IconButton(
          icon: const Icon(Icons.format_list_bulleted),
          tooltip: 'Lista',
          onPressed: () => _quillController.formatSelection(Attribute.ul),
        ),
        IconButton(
          icon: const Icon(Icons.format_list_numbered),
          tooltip: 'Lista numerada',
          onPressed: () => _quillController.formatSelection(Attribute.ol),
        ),
        IconButton(
          icon: const Icon(Icons.code),
          tooltip: 'Código',
          onPressed: () => _quillController.formatSelection(Attribute.codeBlock),
        ),
        IconButton(
          icon: const Icon(Icons.format_quote),
          tooltip: 'Cita',
          onPressed: () => _quillController.formatSelection(Attribute.blockQuote),
        ),
      ],
    );
  }

  Widget _formatButton({required IconData icon, required String tooltip, required Attribute attribute}) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: () => _quillController.formatSelection(attribute),
    );
  }

  Widget _buildMarkdownToolbar() {
    return Row(
      children: [
        IconButton(
          onPressed: () => _insertMarkdown('**', '**'),
          icon: const Icon(Icons.format_bold),
          tooltip: 'Negrita',
        ),
        IconButton(
          onPressed: () => _insertMarkdown('*', '*'),
          icon: const Icon(Icons.format_italic),
          tooltip: 'Cursiva',
        ),
        IconButton(
          onPressed: () => _insertMarkdown('~~', '~~'),
          icon: const Icon(Icons.strikethrough_s),
          tooltip: 'Tachado',
        ),
        const VerticalDivider(),
        IconButton(
          onPressed: () => _insertMarkdown('# ', ''),
          icon: const Icon(Icons.title),
          tooltip: 'Encabezado',
        ),
        IconButton(
          onPressed: () => _insertMarkdown('- ', ''),
          icon: const Icon(Icons.format_list_bulleted),
          tooltip: 'Lista',
        ),
        IconButton(
          onPressed: () => _insertMarkdown('`', '`'),
          icon: const Icon(Icons.code),
          tooltip: 'Código',
        ),
      ],
    );
  }

  Widget _buildUtilityActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _insertMedia,
          icon: const Icon(Icons.attach_file),
          tooltip: 'Insertar archivo',
        ),
        IconButton(
          onPressed: _toggleFullscreen,
          icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
          tooltip: _isFullscreen ? 'Salir de pantalla completa' : 'Pantalla completa',
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Container(
      color: Theme.of(context).cardColor,
      child: Stack(
        children: [
          if (_currentMode == EditorMode.wysiwyg)
            _buildQuillEditor()
          else
            _buildMarkdownEditor(),
          
          if (_showAutocomplete)
            _buildAutocompleteOverlay(),
        ],
      ),
    );
  }

  Widget _buildQuillEditor() {
    final editor = QuillEditor.basic(controller: _quillController);
    if (widget.readOnly) {
      return AbsorbPointer(child: editor);
    }
    return editor;
  }

  Widget _buildMarkdownEditor() {
    return TextField(
      controller: _markdownController,
      focusNode: _editorFocusNode,
      scrollController: _scrollController,
      readOnly: widget.readOnly,
      maxLines: null,
      expands: true,
      style: TextStyle(
        fontSize: _settings.fontSize,
        height: _settings.lineHeight,
        fontFamily: 'monospace',
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(16),
        hintText: 'Escribe en Markdown...',
      ),
    );
  }

  Widget _buildAutocompleteOverlay() {
    return Positioned(
      left: 16,
      top: 100, // Calcular posición real del cursor
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 300,
            maxHeight: 200,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = _suggestions[index];
              return ListTile(
                leading: Icon(suggestion.icon, size: 16),
                title: Text(suggestion.text),
                subtitle: Text(suggestion.description),
                onTap: () {
                  suggestion.action?.call();
                  _hideAutocomplete();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_lastSaveTime != null)
            Text(
              'Guardado ${_formatLastSaveTime()}',
              style: const TextStyle(fontSize: 12, color: Colors.green),
            ),
          const Spacer(),
          Text(
            '${_statistics['wordCount'] ?? 0} palabras • ${_statistics['characterCount'] ?? 0} caracteres',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _insertMarkdown(String before, String after) {
    final selection = _markdownController.selection;
    final text = _markdownController.text;
    
    if (selection.isValid) {
      final selectedText = text.substring(selection.start, selection.end);
      final replacement = before + selectedText + after;
      
      _markdownController.value = _markdownController.value.copyWith(
        text: text.replaceRange(selection.start, selection.end, replacement),
        selection: TextSelection.collapsed(
          offset: selection.start + before.length + selectedText.length,
        ),
      );
    }
  }

  String _formatLastSaveTime() {
    if (_lastSaveTime == null) return '';
    
    final now = DateTime.now();
    final diff = now.difference(_lastSaveTime!);
    
    if (diff.inSeconds < 60) {
      return 'hace ${diff.inSeconds}s';
    } else if (diff.inMinutes < 60) {
      return 'hace ${diff.inMinutes}m';
    } else {
      return 'hace ${diff.inHours}h';
    }
  }
}

// Clases de soporte

enum EditorMode { wysiwyg, markdown }

class EditorSettings {
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final bool showLineNumbers;
  final bool enableSpellCheck;
  final bool enableAutoSave;
  final int autoSaveDelay;
  final bool enableCollaboration;

  const EditorSettings({
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.showLineNumbers,
    required this.enableSpellCheck,
    required this.enableAutoSave,
    required this.autoSaveDelay,
    required this.enableCollaboration,
  });

  static EditorSettings defaultSettings() {
    return const EditorSettings(
      fontSize: 16.0,
      lineHeight: 1.5,
      fontFamily: 'Roboto',
      showLineNumbers: false,
      enableSpellCheck: true,
      enableAutoSave: true,
      autoSaveDelay: 2,
      enableCollaboration: false,
    );
  }
}

class AutocompleteSuggestion {
  final String text;
  final String description;
  final IconData icon;
  final VoidCallback? action;

  const AutocompleteSuggestion({
    required this.text,
    required this.description,
    required this.icon,
    this.action,
  });
}

class EditorAction {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const EditorAction({
    required this.type,
    required this.data,
    required this.timestamp,
  });
}

class CollaboratorCursor {
  final String userId;
  final String userName;
  final Color color;
  final int position;

  const CollaboratorCursor({
    required this.userId,
    required this.userName,
    required this.color,
    required this.position,
  });
}

abstract class EditorPlugin {
  String get name;
  String get version;
  
  void initialize(BuildContext context);
  void dispose();
  Widget? buildToolbarItem();
  void onTextChanged(String text);
}

class EditorSettingsDialog extends StatefulWidget {
  final EditorSettings settings;
  final ValueChanged<EditorSettings> onSettingsChanged;

  const EditorSettingsDialog({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<EditorSettingsDialog> createState() => _EditorSettingsDialogState();
}

class _EditorSettingsDialogState extends State<EditorSettingsDialog> {
  late EditorSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configuración del Editor'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Tamaño de fuente'),
              subtitle: Slider(
                value: _settings.fontSize,
                min: 12,
                max: 24,
                divisions: 12,
                label: '${_settings.fontSize.round()}pt',
                onChanged: (value) {
                  setState(() {
                    _settings = EditorSettings(
                      fontSize: value,
                      lineHeight: _settings.lineHeight,
                      fontFamily: _settings.fontFamily,
                      showLineNumbers: _settings.showLineNumbers,
                      enableSpellCheck: _settings.enableSpellCheck,
                      enableAutoSave: _settings.enableAutoSave,
                      autoSaveDelay: _settings.autoSaveDelay,
                      enableCollaboration: _settings.enableCollaboration,
                    );
                  });
                },
              ),
            ),
            SwitchListTile(
              title: const Text('Auto-guardado'),
              subtitle: const Text('Guardar automáticamente los cambios'),
              value: _settings.enableAutoSave,
              onChanged: (value) {
                setState(() {
                  _settings = EditorSettings(
                    fontSize: _settings.fontSize,
                    lineHeight: _settings.lineHeight,
                    fontFamily: _settings.fontFamily,
                    showLineNumbers: _settings.showLineNumbers,
                    enableSpellCheck: _settings.enableSpellCheck,
                    enableAutoSave: value,
                    autoSaveDelay: _settings.autoSaveDelay,
                    enableCollaboration: _settings.enableCollaboration,
                  );
                });
              },
            ),
            SwitchListTile(
              title: const Text('Corrección ortográfica'),
              subtitle: const Text('Detectar errores de ortografía'),
              value: _settings.enableSpellCheck,
              onChanged: (value) {
                setState(() {
                  _settings = EditorSettings(
                    fontSize: _settings.fontSize,
                    lineHeight: _settings.lineHeight,
                    fontFamily: _settings.fontFamily,
                    showLineNumbers: _settings.showLineNumbers,
                    enableSpellCheck: value,
                    enableAutoSave: _settings.enableAutoSave,
                    autoSaveDelay: _settings.autoSaveDelay,
                    enableCollaboration: _settings.enableCollaboration,
                  );
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
        FilledButton(
          onPressed: () {
            widget.onSettingsChanged(_settings);
            Navigator.of(context).pop();
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}