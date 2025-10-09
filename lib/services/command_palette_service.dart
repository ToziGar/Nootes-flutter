import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/color_utils.dart';

/// Servicio para la paleta de comandos del editor
class CommandPaletteService {
  static final CommandPaletteService _instance = CommandPaletteService._internal();
  factory CommandPaletteService() => _instance;
  CommandPaletteService._internal();

  final List<EditorCommand> _commands = [];
  final List<String> _recentCommands = [];
  final Map<String, VoidCallback> _callbacks = {};

  /// Obtiene todos los comandos disponibles
  List<EditorCommand> get commands => List.unmodifiable(_commands);

  /// Obtiene comandos recientes
  List<String> get recentCommands => List.unmodifiable(_recentCommands);

  /// Inicializa el servicio con comandos predeterminados
  void initialize() {
    _registerDefaultCommands();
  }

  /// Registra un comando personalizado
  void registerCommand(EditorCommand command, VoidCallback callback) {
    _commands.add(command);
    _callbacks[command.id] = callback;
  }

  /// Ejecuta un comando por ID
  bool executeCommand(String commandId) {
    final callback = _callbacks[commandId];
    if (callback != null) {
      callback();
      _addToRecent(commandId);
      return true;
    }
    return false;
  }

  /// Busca comandos por texto
  List<EditorCommand> searchCommands(String query) {
    if (query.isEmpty) {
      // Mostrar comandos recientes primero
      final recent = <EditorCommand>[];
      final others = <EditorCommand>[];
      
      for (final command in _commands) {
        if (_recentCommands.contains(command.id)) {
          recent.add(command);
        } else {
          others.add(command);
        }
      }
      
      return [...recent, ...others];
    }
    
    final lowerQuery = query.toLowerCase();
    return _commands.where((command) {
      return command.title.toLowerCase().contains(lowerQuery) ||
             command.description.toLowerCase().contains(lowerQuery) ||
             command.category.toLowerCase().contains(lowerQuery) ||
             command.keywords.any((keyword) => keyword.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Agrega un comando a los recientes
  void _addToRecent(String commandId) {
    _recentCommands.remove(commandId);
    _recentCommands.insert(0, commandId);
    if (_recentCommands.length > 10) {
      _recentCommands.removeLast();
    }
  }

  /// Registra comandos predeterminados
  void _registerDefaultCommands() {
    // Comandos de archivo
    registerCommand(
      EditorCommand(
        id: 'file.new',
        title: 'Nueva Nota',
        description: 'Crear una nueva nota',
        category: 'Archivo',
        icon: Icons.note_add,
        shortcut: 'Ctrl+N',
        keywords: ['nuevo', 'crear', 'nota'],
      ),
      () {}, // Se implementará en el widget
    );

    registerCommand(
      EditorCommand(
        id: 'file.save',
        title: 'Guardar',
        description: 'Guardar la nota actual',
        category: 'Archivo',
        icon: Icons.save,
        shortcut: 'Ctrl+S',
        keywords: ['guardar', 'save'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'file.export',
        title: 'Exportar',
        description: 'Exportar nota a PDF o texto',
        category: 'Archivo',
        icon: Icons.download,
        keywords: ['exportar', 'pdf', 'descargar'],
      ),
      () {},
    );

    // Comandos de edición
    registerCommand(
      EditorCommand(
        id: 'edit.undo',
        title: 'Deshacer',
        description: 'Deshacer la última acción',
        category: 'Edición',
        icon: Icons.undo,
        shortcut: 'Ctrl+Z',
        keywords: ['deshacer', 'undo'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'edit.redo',
        title: 'Rehacer',
        description: 'Rehacer la última acción deshecha',
        category: 'Edición',
        icon: Icons.redo,
        shortcut: 'Ctrl+Y',
        keywords: ['rehacer', 'redo'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'edit.cut',
        title: 'Cortar',
        description: 'Cortar texto seleccionado',
        category: 'Edición',
        icon: Icons.cut,
        shortcut: 'Ctrl+X',
        keywords: ['cortar', 'cut'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'edit.copy',
        title: 'Copiar',
        description: 'Copiar texto seleccionado',
        category: 'Edición',
        icon: Icons.copy,
        shortcut: 'Ctrl+C',
        keywords: ['copiar', 'copy'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'edit.paste',
        title: 'Pegar',
        description: 'Pegar texto del portapapeles',
        category: 'Edición',
        icon: Icons.paste,
        shortcut: 'Ctrl+V',
        keywords: ['pegar', 'paste'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'edit.selectAll',
        title: 'Seleccionar Todo',
        description: 'Seleccionar todo el texto',
        category: 'Edición',
        icon: Icons.select_all,
        shortcut: 'Ctrl+A',
        keywords: ['seleccionar', 'todo', 'select all'],
      ),
      () {},
    );

    // Comandos de búsqueda
    registerCommand(
      EditorCommand(
        id: 'search.find',
        title: 'Buscar',
        description: 'Buscar texto en la nota',
        category: 'Búsqueda',
        icon: Icons.search,
        shortcut: 'Ctrl+F',
        keywords: ['buscar', 'find', 'search'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'search.replace',
        title: 'Buscar y Reemplazar',
        description: 'Buscar y reemplazar texto',
        category: 'Búsqueda',
        icon: Icons.find_replace,
        shortcut: 'Ctrl+H',
        keywords: ['reemplazar', 'replace'],
      ),
      () {},
    );

    // Comandos de formato
    registerCommand(
      EditorCommand(
        id: 'format.bold',
        title: 'Negrita',
        description: 'Aplicar formato de negrita',
        category: 'Formato',
        icon: Icons.format_bold,
        shortcut: 'Ctrl+B',
        keywords: ['negrita', 'bold'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'format.italic',
        title: 'Cursiva',
        description: 'Aplicar formato de cursiva',
        category: 'Formato',
        icon: Icons.format_italic,
        shortcut: 'Ctrl+I',
        keywords: ['cursiva', 'italic'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'format.underline',
        title: 'Subrayado',
        description: 'Aplicar subrayado',
        category: 'Formato',
        icon: Icons.format_underlined,
        shortcut: 'Ctrl+U',
        keywords: ['subrayado', 'underline'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'format.strikethrough',
        title: 'Tachado',
        description: 'Aplicar tachado',
        category: 'Formato',
        icon: Icons.format_strikethrough,
        keywords: ['tachado', 'strikethrough'],
      ),
      () {},
    );

    // Comandos de vista
    registerCommand(
      EditorCommand(
        id: 'view.zenMode',
        title: 'Modo Zen',
        description: 'Activar modo de escritura sin distracciones',
        category: 'Vista',
        icon: Icons.fullscreen,
        shortcut: 'F11',
        keywords: ['zen', 'fullscreen', 'pantalla completa'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'view.preview',
        title: 'Vista Previa',
        description: 'Mostrar vista previa de Markdown',
        category: 'Vista',
        icon: Icons.preview,
        shortcut: 'Ctrl+Shift+V',
        keywords: ['preview', 'vista previa', 'markdown'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'view.wordWrap',
        title: 'Ajuste de Línea',
        description: 'Alternar ajuste automático de línea',
        category: 'Vista',
        icon: Icons.wrap_text,
        keywords: ['wrap', 'ajuste', 'línea'],
      ),
      () {},
    );

    // Comandos de navegación
    registerCommand(
      EditorCommand(
        id: 'nav.goToLine',
        title: 'Ir a Línea',
        description: 'Ir a un número de línea específico',
        category: 'Navegación',
        icon: Icons.my_location,
        shortcut: 'Ctrl+G',
        keywords: ['línea', 'goto', 'ir'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'nav.nextNote',
        title: 'Siguiente Nota',
        description: 'Ir a la siguiente nota',
        category: 'Navegación',
        icon: Icons.skip_next,
        keywords: ['siguiente', 'next'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'nav.prevNote',
        title: 'Nota Anterior',
        description: 'Ir a la nota anterior',
        category: 'Navegación',
        icon: Icons.skip_previous,
        keywords: ['anterior', 'previous'],
      ),
      () {},
    );

    // Comandos de herramientas
    registerCommand(
      EditorCommand(
        id: 'tools.wordCount',
        title: 'Contar Palabras',
        description: 'Mostrar estadísticas de palabras',
        category: 'Herramientas',
        icon: Icons.bar_chart,
        keywords: ['palabras', 'count', 'estadísticas'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'tools.insertDate',
        title: 'Insertar Fecha',
        description: 'Insertar fecha y hora actual',
        category: 'Herramientas',
        icon: Icons.today,
        keywords: ['fecha', 'date', 'time'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'tools.insertTemplate',
        title: 'Insertar Plantilla',
        description: 'Insertar una plantilla predefinida',
        category: 'Herramientas',
        icon: Icons.text_snippet,
        keywords: ['plantilla', 'template'],
      ),
      () {},
    );

    // Comandos de configuración
    registerCommand(
      EditorCommand(
        id: 'settings.editor',
        title: 'Configuración del Editor',
        description: 'Abrir configuración del editor',
        category: 'Configuración',
        icon: Icons.settings,
        keywords: ['configuración', 'settings', 'editor'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'settings.theme',
        title: 'Cambiar Tema',
        description: 'Cambiar tema de la aplicación',
        category: 'Configuración',
        icon: Icons.palette,
        keywords: ['tema', 'theme', 'color'],
      ),
      () {},
    );

    registerCommand(
      EditorCommand(
        id: 'settings.shortcuts',
        title: 'Atajos de Teclado',
        description: 'Ver y configurar atajos de teclado',
        category: 'Configuración',
        icon: Icons.keyboard,
        keywords: ['atajos', 'shortcuts', 'keyboard'],
      ),
      () {},
    );
  }
}

/// Información de un comando del editor
class EditorCommand {
  final String id;
  final String title;
  final String description;
  final String category;
  final IconData icon;
  final String? shortcut;
  final List<String> keywords;

  const EditorCommand({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    this.shortcut,
    this.keywords = const [],
  });

  @override
  String toString() {
    return 'EditorCommand($id: $title)';
  }
}

/// Widget de la paleta de comandos
class CommandPalette extends StatefulWidget {
  final CommandPaletteService service;
  final Function(String) onCommandExecuted;

  const CommandPalette({
    super.key,
    required this.service,
    required this.onCommandExecuted,
  });

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<EditorCommand> _filteredCommands = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _filteredCommands = widget.service.searchCommands('');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateFilter() {
    setState(() {
      _filteredCommands = widget.service.searchCommands(_searchController.text);
      _selectedIndex = 0;
    });
  }

  void _executeSelectedCommand() {
    if (_selectedIndex >= 0 && _selectedIndex < _filteredCommands.length) {
      final command = _filteredCommands[_selectedIndex];
      widget.onCommandExecuted(command.id);
      Navigator.of(context).pop();
    }
  }

  void _moveSelection(int delta) {
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, _filteredCommands.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacityCompat(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra de búsqueda
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacityCompat(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: theme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KeyboardListener(
                      focusNode: _focusNode,
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                            _moveSelection(1);
                          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                            _moveSelection(-1);
                          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                            _executeSelectedCommand();
                          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                            Navigator.of(context).pop();
                          }
                        }
                      },
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar comandos...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: theme.disabledColor),
                        ),
                        style: theme.textTheme.bodyLarge,
                        onChanged: (_) => _updateFilter(),
                      ),
                    ),
                  ),
                  Text(
                    '${_filteredCommands.length} comandos',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                ],
              ),
            ),
            
            // Lista de comandos
            Flexible(
              child: _filteredCommands.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: theme.disabledColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron comandos',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Intenta con otros términos de búsqueda',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredCommands.length,
                      itemBuilder: (context, index) {
                        final command = _filteredCommands[index];
                        final isSelected = index == _selectedIndex;
                        final isRecent = widget.service.recentCommands.contains(command.id);
                        
                        return Container(
              color: isSelected
                ? theme.primaryColor.withOpacityCompat(0.1)
                : null,
                          child: ListTile(
                            dense: true,
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isRecent)
                                  Icon(
                                    Icons.history,
                                    size: 16,
                                    color: theme.primaryColor,
                                  ),
                                const SizedBox(width: 4),
                                Icon(
                                  command.icon,
                                  color: isSelected 
                                      ? theme.primaryColor
                                      : theme.iconTheme.color,
                                ),
                              ],
                            ),
                            title: Text(
                              command.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isSelected ? theme.primaryColor : null,
                                fontWeight: isSelected ? FontWeight.bold : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  command.description,
                                  style: theme.textTheme.bodySmall,
                                ),
                                if (command.shortcut != null)
                                  Text(
                                    command.shortcut!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      color: theme.primaryColor,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacityCompat(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                command.category,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.primaryColor,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            onTap: () {
                              widget.onCommandExecuted(command.id);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
            ),
            
            // Ayuda del teclado
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(
                  top: BorderSide(color: theme.dividerColor),
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildKeyboardHint('↑↓', 'Navegar'),
                  const SizedBox(width: 16),
                  _buildKeyboardHint('Enter', 'Ejecutar'),
                  const SizedBox(width: 16),
                  _buildKeyboardHint('Esc', 'Cerrar'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardHint(String key, String description) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            key,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          description,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}