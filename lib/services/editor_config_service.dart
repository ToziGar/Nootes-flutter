import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio de configuración del editor avanzado
class EditorConfigService {
  static final EditorConfigService _instance = EditorConfigService._internal();
  factory EditorConfigService() => _instance;
  EditorConfigService._internal();

  static const _storage = FlutterSecureStorage();

  // Configuraciones del editor
  static const String _syntaxHighlightingKey = 'editor_syntax_highlighting';
  static const String _autoCompleteKey = 'editor_auto_complete';
  static const String _showLineNumbersKey = 'editor_show_line_numbers';
  static const String _showMinimapKey = 'editor_show_minimap';
  static const String _wordWrapKey = 'editor_word_wrap';
  static const String _fontSizeKey = 'editor_font_size';
  static const String _fontFamilyKey = 'editor_font_family';
  static const String _tabSizeKey = 'editor_tab_size';
  static const String _insertSpacesKey = 'editor_insert_spaces';
  static const String _autoSaveKey = 'editor_auto_save';
  static const String _autoSaveDelayKey = 'editor_auto_save_delay';
  static const String _bracketMatchingKey = 'editor_bracket_matching';
  static const String _showWhitespaceKey = 'editor_show_whitespace';
  static const String _trimTrailingWhitespaceKey = 'editor_trim_trailing_whitespace';

  /// Obtiene si el resaltado de sintaxis está habilitado
  Future<bool> getSyntaxHighlighting() async {
    final value = await _storage.read(key: _syntaxHighlightingKey);
    return value == 'true' || value == null; // true por defecto
  }

  /// Establece si el resaltado de sintaxis está habilitado
  Future<void> setSyntaxHighlighting(bool enabled) async {
    await _storage.write(key: _syntaxHighlightingKey, value: enabled.toString());
  }

  /// Obtiene si el autocompletado está habilitado
  Future<bool> getAutoComplete() async {
    final value = await _storage.read(key: _autoCompleteKey);
    return value == 'true' || value == null; // true por defecto
  }

  /// Establece si el autocompletado está habilitado
  Future<void> setAutoComplete(bool enabled) async {
    await _storage.write(key: _autoCompleteKey, value: enabled.toString());
  }

  /// Obtiene si mostrar números de línea
  Future<bool> getShowLineNumbers() async {
    final value = await _storage.read(key: _showLineNumbersKey);
    return value == 'true' || value == null; // true por defecto
  }

  /// Establece si mostrar números de línea
  Future<void> setShowLineNumbers(bool show) async {
    await _storage.write(key: _showLineNumbersKey, value: show.toString());
  }

  /// Obtiene si mostrar minimap
  Future<bool> getShowMinimap() async {
    final value = await _storage.read(key: _showMinimapKey);
    return value == 'true'; // false por defecto
  }

  /// Establece si mostrar minimap
  Future<void> setShowMinimap(bool show) async {
    await _storage.write(key: _showMinimapKey, value: show.toString());
  }

  /// Obtiene si usar ajuste de línea
  Future<bool> getWordWrap() async {
    final value = await _storage.read(key: _wordWrapKey);
    return value == 'true' || value == null; // true por defecto
  }

  /// Establece si usar ajuste de línea
  Future<void> setWordWrap(bool wrap) async {
    await _storage.write(key: _wordWrapKey, value: wrap.toString());
  }

  /// Obtiene el tamaño de fuente
  Future<double> getFontSize() async {
    final value = await _storage.read(key: _fontSizeKey);
    return double.tryParse(value ?? '') ?? 16.0;
  }

  /// Establece el tamaño de fuente
  Future<void> setFontSize(double size) async {
    await _storage.write(key: _fontSizeKey, value: size.toString());
  }

  /// Obtiene la familia de fuente
  Future<String> getFontFamily() async {
    final value = await _storage.read(key: _fontFamilyKey);
    return value ?? 'monospace';
  }

  /// Establece la familia de fuente
  Future<void> setFontFamily(String family) async {
    await _storage.write(key: _fontFamilyKey, value: family);
  }

  /// Obtiene el tamaño de tabulación
  Future<int> getTabSize() async {
    final value = await _storage.read(key: _tabSizeKey);
    return int.tryParse(value ?? '') ?? 4;
  }

  /// Establece el tamaño de tabulación
  Future<void> setTabSize(int size) async {
    await _storage.write(key: _tabSizeKey, value: size.toString());
  }

  /// Obtiene si insertar espacios en lugar de tabs
  Future<bool> getInsertSpaces() async {
    final value = await _storage.read(key: _insertSpacesKey);
    return value == 'true' || value == null; // true por defecto
  }

  /// Establece si insertar espacios en lugar de tabs
  Future<void> setInsertSpaces(bool insert) async {
    await _storage.write(key: _insertSpacesKey, value: insert.toString());
  }

  /// Obtiene si el autoguardado está habilitado
  Future<bool> getAutoSave() async {
    final value = await _storage.read(key: _autoSaveKey);
    return value == 'true' || value == null; // true por defecto
  }

  /// Establece si el autoguardado está habilitado
  Future<void> setAutoSave(bool enabled) async {
    await _storage.write(key: _autoSaveKey, value: enabled.toString());
  }

  /// Obtiene el retraso del autoguardado en milisegundos
  Future<int> getAutoSaveDelay() async {
    final value = await _storage.read(key: _autoSaveDelayKey);
    return int.tryParse(value ?? '') ?? 2000;
  }

  /// Establece el retraso del autoguardado en milisegundos
  Future<void> setAutoSaveDelay(int delay) async {
    await _storage.write(key: _autoSaveDelayKey, value: delay.toString());
  }

  /// Obtiene si mostrar coincidencias de corchetes
  Future<bool> getBracketMatching() async {
    final value = await _storage.read(key: _bracketMatchingKey);
    return value == 'true' || value == null; // true por defecto
  }

  /// Establece si mostrar coincidencias de corchetes
  Future<void> setBracketMatching(bool enabled) async {
    await _storage.write(key: _bracketMatchingKey, value: enabled.toString());
  }

  /// Obtiene si mostrar espacios en blanco
  Future<bool> getShowWhitespace() async {
    final value = await _storage.read(key: _showWhitespaceKey);
    return value == 'true'; // false por defecto
  }

  /// Establece si mostrar espacios en blanco
  Future<void> setShowWhitespace(bool show) async {
    await _storage.write(key: _showWhitespaceKey, value: show.toString());
  }

  /// Obtiene si eliminar espacios al final de línea
  Future<bool> getTrimTrailingWhitespace() async {
    final value = await _storage.read(key: _trimTrailingWhitespaceKey);
    return value == 'true' || value == null; // true por defecto
  }

  /// Establece si eliminar espacios al final de línea
  Future<void> setTrimTrailingWhitespace(bool trim) async {
    await _storage.write(key: _trimTrailingWhitespaceKey, value: trim.toString());
  }

  /// Obtiene todas las configuraciones del editor
  Future<EditorConfig> getEditorConfig() async {
    return EditorConfig(
      syntaxHighlighting: await getSyntaxHighlighting(),
      autoComplete: await getAutoComplete(),
      showLineNumbers: await getShowLineNumbers(),
      showMinimap: await getShowMinimap(),
      wordWrap: await getWordWrap(),
      fontSize: await getFontSize(),
      fontFamily: await getFontFamily(),
      tabSize: await getTabSize(),
      insertSpaces: await getInsertSpaces(),
      autoSave: await getAutoSave(),
      autoSaveDelay: await getAutoSaveDelay(),
      bracketMatching: await getBracketMatching(),
      showWhitespace: await getShowWhitespace(),
      trimTrailingWhitespace: await getTrimTrailingWhitespace(),
    );
  }

  /// Establece múltiples configuraciones del editor
  Future<void> setEditorConfig(EditorConfig config) async {
    await Future.wait([
      setSyntaxHighlighting(config.syntaxHighlighting),
      setAutoComplete(config.autoComplete),
      setShowLineNumbers(config.showLineNumbers),
      setShowMinimap(config.showMinimap),
      setWordWrap(config.wordWrap),
      setFontSize(config.fontSize),
      setFontFamily(config.fontFamily),
      setTabSize(config.tabSize),
      setInsertSpaces(config.insertSpaces),
      setAutoSave(config.autoSave),
      setAutoSaveDelay(config.autoSaveDelay),
      setBracketMatching(config.bracketMatching),
      setShowWhitespace(config.showWhitespace),
      setTrimTrailingWhitespace(config.trimTrailingWhitespace),
    ]);
  }

  /// Restablece todas las configuraciones a valores por defecto
  Future<void> resetToDefaults() async {
    await setEditorConfig(EditorConfig.defaultConfig());
  }
}

/// Clase que representa la configuración completa del editor
class EditorConfig {
  final bool syntaxHighlighting;
  final bool autoComplete;
  final bool showLineNumbers;
  final bool showMinimap;
  final bool wordWrap;
  final double fontSize;
  final String fontFamily;
  final int tabSize;
  final bool insertSpaces;
  final bool autoSave;
  final int autoSaveDelay;
  final bool bracketMatching;
  final bool showWhitespace;
  final bool trimTrailingWhitespace;

  const EditorConfig({
    required this.syntaxHighlighting,
    required this.autoComplete,
    required this.showLineNumbers,
    required this.showMinimap,
    required this.wordWrap,
    required this.fontSize,
    required this.fontFamily,
    required this.tabSize,
    required this.insertSpaces,
    required this.autoSave,
    required this.autoSaveDelay,
    required this.bracketMatching,
    required this.showWhitespace,
    required this.trimTrailingWhitespace,
  });

  /// Configuración por defecto
  static EditorConfig defaultConfig() {
    return const EditorConfig(
      syntaxHighlighting: true,
      autoComplete: true,
      showLineNumbers: true,
      showMinimap: false,
      wordWrap: true,
      fontSize: 16.0,
      fontFamily: 'monospace',
      tabSize: 4,
      insertSpaces: true,
      autoSave: true,
      autoSaveDelay: 2000,
      bracketMatching: true,
      showWhitespace: false,
      trimTrailingWhitespace: true,
    );
  }

  /// Crea una copia con modificaciones
  EditorConfig copyWith({
    bool? syntaxHighlighting,
    bool? autoComplete,
    bool? showLineNumbers,
    bool? showMinimap,
    bool? wordWrap,
    double? fontSize,
    String? fontFamily,
    int? tabSize,
    bool? insertSpaces,
    bool? autoSave,
    int? autoSaveDelay,
    bool? bracketMatching,
    bool? showWhitespace,
    bool? trimTrailingWhitespace,
  }) {
    return EditorConfig(
      syntaxHighlighting: syntaxHighlighting ?? this.syntaxHighlighting,
      autoComplete: autoComplete ?? this.autoComplete,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      showMinimap: showMinimap ?? this.showMinimap,
      wordWrap: wordWrap ?? this.wordWrap,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      tabSize: tabSize ?? this.tabSize,
      insertSpaces: insertSpaces ?? this.insertSpaces,
      autoSave: autoSave ?? this.autoSave,
      autoSaveDelay: autoSaveDelay ?? this.autoSaveDelay,
      bracketMatching: bracketMatching ?? this.bracketMatching,
      showWhitespace: showWhitespace ?? this.showWhitespace,
      trimTrailingWhitespace: trimTrailingWhitespace ?? this.trimTrailingWhitespace,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EditorConfig &&
        other.syntaxHighlighting == syntaxHighlighting &&
        other.autoComplete == autoComplete &&
        other.showLineNumbers == showLineNumbers &&
        other.showMinimap == showMinimap &&
        other.wordWrap == wordWrap &&
        other.fontSize == fontSize &&
        other.fontFamily == fontFamily &&
        other.tabSize == tabSize &&
        other.insertSpaces == insertSpaces &&
        other.autoSave == autoSave &&
        other.autoSaveDelay == autoSaveDelay &&
        other.bracketMatching == bracketMatching &&
        other.showWhitespace == showWhitespace &&
        other.trimTrailingWhitespace == trimTrailingWhitespace;
  }

  @override
  int get hashCode {
    return Object.hash(
      syntaxHighlighting,
      autoComplete,
      showLineNumbers,
      showMinimap,
      wordWrap,
      fontSize,
      fontFamily,
      tabSize,
      insertSpaces,
      autoSave,
      autoSaveDelay,
      bracketMatching,
      showWhitespace,
      trimTrailingWhitespace,
    );
  }

  @override
  String toString() {
    return 'EditorConfig('
        'syntaxHighlighting: $syntaxHighlighting, '
        'autoComplete: $autoComplete, '
        'showLineNumbers: $showLineNumbers, '
        'showMinimap: $showMinimap, '
        'wordWrap: $wordWrap, '
        'fontSize: $fontSize, '
        'fontFamily: $fontFamily, '
        'tabSize: $tabSize, '
        'insertSpaces: $insertSpaces, '
        'autoSave: $autoSave, '
        'autoSaveDelay: $autoSaveDelay, '
        'bracketMatching: $bracketMatching, '
        'showWhitespace: $showWhitespace, '
        'trimTrailingWhitespace: $trimTrailingWhitespace)';
  }
}