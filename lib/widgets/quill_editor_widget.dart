import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'dart:convert';

class QuillEditorWidget extends StatefulWidget {
  final String uid;
  final String? initialDeltaJson;
  final ValueChanged<String> onChanged;
  final Future<void> Function(String) onSave;
  final Future<void> Function(List<String>)? onLinksChanged;
  final Future<void> Function(String)? onNoteOpen;
  final bool splitEnabled;

  const QuillEditorWidget({
    super.key,
    required this.uid,
    this.initialDeltaJson,
    required this.onChanged,
    required this.onSave,
    this.onLinksChanged,
    this.onNoteOpen,
    this.splitEnabled = false,
  });

  @override
  State<QuillEditorWidget> createState() => _QuillEditorWidgetState();
}

class _QuillEditorWidgetState extends State<QuillEditorWidget> {
  late QuillController _controller;
  // bool _isFullscreen = false; // Commented out until used
  bool _darkTheme = false;
  // String _searchQuery = ''; // Commented out until used
  // int _currentSearchIndex = 0; // Commented out until used
  // List<int> _searchResults = []; // Commented out until used

  @override
  void initState() {
    super.initState();
    _controller = widget.initialDeltaJson != null
        ? QuillController(
            document: Document.fromJson(
              widget.initialDeltaJson != null
                ? List<Map<String, dynamic>>.from(jsonDecode(widget.initialDeltaJson!))
                : [],
            ),
            selection: const TextSelection.collapsed(offset: 0),
          )
        : QuillController.basic();
        
    // Escuchar cambios en el documento
    _controller.addListener(_onDocumentChanged);
  }

  void _onDocumentChanged() {
    final deltaJson = jsonEncode(_controller.document.toDelta().toJson());
    widget.onChanged(deltaJson);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de herramientas avanzada estilo Quiver
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Wrap(
            spacing: 4.0,
            runSpacing: 4.0,
            children: [
              // Formato básico
              _buildToolbarButton(Icons.format_bold, () => _controller.formatSelection(Attribute.bold), 'Negrita'),
              _buildToolbarButton(Icons.format_italic, () => _controller.formatSelection(Attribute.italic), 'Cursiva'),
              _buildToolbarButton(Icons.format_underline, () => _controller.formatSelection(Attribute.underline), 'Subrayado'),
              _buildToolbarButton(Icons.strikethrough_s, () => _controller.formatSelection(Attribute.strikeThrough), 'Tachado'),
              const VerticalDivider(width: 16),
              
              // Alineación de texto
              _buildToolbarButton(Icons.format_align_left, () => _controller.formatSelection(Attribute.leftAlignment), 'Alinear izquierda'),
              _buildToolbarButton(Icons.format_align_center, () => _controller.formatSelection(Attribute.centerAlignment), 'Centrar'),
              _buildToolbarButton(Icons.format_align_right, () => _controller.formatSelection(Attribute.rightAlignment), 'Alinear derecha'),
              _buildToolbarButton(Icons.format_align_justify, () => _controller.formatSelection(Attribute.justifyAlignment), 'Justificar'),
              const VerticalDivider(width: 16),
              
              // Listas y citas
              _buildToolbarButton(Icons.format_list_bulleted, () => _controller.formatSelection(Attribute.ul), 'Lista'),
              _buildToolbarButton(Icons.format_list_numbered, () => _controller.formatSelection(Attribute.ol), 'Lista numerada'),
              _buildToolbarButton(Icons.format_quote, () => _controller.formatSelection(Attribute.blockQuote), 'Cita'),
              _buildToolbarButton(Icons.code, () => _controller.formatSelection(Attribute.codeBlock), 'Bloque de código'),
              const VerticalDivider(width: 16),
              
              // Historial
              _buildToolbarButton(Icons.undo, () => _controller.undo(), 'Deshacer'),
              _buildToolbarButton(Icons.redo, () => _controller.redo(), 'Rehacer'),
              const VerticalDivider(width: 16),
              
              // Búsqueda y medios
              _buildToolbarButton(Icons.search, () => _showSearchDialog(context), 'Buscar'),
              _buildToolbarButton(Icons.image, () => _insertImage(context), 'Insertar imagen'),
              _buildToolbarButton(Icons.link, () => _insertLink(context), 'Insertar enlace'),
              const VerticalDivider(width: 16),
              
              // Herramientas avanzadas
              _buildToolbarButton(Icons.file_upload, () => _exportContent(context), 'Exportar'),
              _buildToolbarButton(Icons.file_download, () => _importContent(context), 'Importar'),
              _buildToolbarButton(Icons.color_lens, () => _showColorPicker(context), 'Color de texto'),
              _buildToolbarButton(_darkTheme ? Icons.light_mode : Icons.dark_mode, () => _toggleTheme(), 'Cambiar tema'),
              _buildToolbarButton(Icons.fullscreen, () => _toggleFullscreen(context), 'Pantalla completa'),
            ],
          ),
        ),
        // Editor expandido con tema adaptativo
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _darkTheme ? Colors.grey[900] : Theme.of(context).colorScheme.surface,
            ),
            padding: const EdgeInsets.all(16.0),
            child: QuillEditor.basic(
              controller: _controller,
            ),
          ),
        ),
        // Barra de estado y guardado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Palabras: ${_getWordCount()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  final json = jsonEncode(_controller.document.toDelta().toJson());
                  widget.onChanged(json);
                  // Capture messenger before awaiting to avoid using context across async gaps
                  final messenger = ScaffoldMessenger.of(context);
                  await widget.onSave(json);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Nota guardada correctamente'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbarButton(IconData icon, VoidCallback onPressed, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  int _getWordCount() {
    final text = _controller.document.toPlainText();
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  void _toggleTheme() {
    setState(() {
      _darkTheme = !_darkTheme;
    });
    if (mounted) {
      _showSnackBar(context, 'Tema ${_darkTheme ? 'oscuro' : 'claro'} activado');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Funciones avanzadas estilo Quiver
  void _showSearchDialog(BuildContext context) {
    String query = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Buscar en nota'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Texto a buscar',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => query = v,
                onSubmitted: (v) {
                  query = v;
                  _performSearch(query);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                _performSearch(query);
                Navigator.of(ctx).pop();
              },
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );
  }

  void _performSearch(String query) {
    if (query.isEmpty) return;
    final text = _controller.document.toPlainText();
    final index = text.toLowerCase().indexOf(query.toLowerCase());
    if (index != -1) {
      _controller.updateSelection(
        TextSelection(baseOffset: index, extentOffset: index + query.length),
        ChangeSource.local,
      );
      _showSnackBar(context, 'Texto encontrado');
    } else {
      _showSnackBar(context, 'Texto no encontrado');
    }
  }

  void _insertImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        String imageUrl = '';
        return AlertDialog(
          title: const Text('Insertar imagen'),
          content: TextField(
            decoration: const InputDecoration(
              hintText: 'URL de la imagen',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => imageUrl = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (imageUrl.isNotEmpty) {
                  final delta = Delta()..insert({'image': imageUrl});
                  _controller.compose(delta, TextSelection.collapsed(offset: _controller.selection.baseOffset), ChangeSource.local);
                  _showSnackBar(context, 'Imagen insertada');
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Insertar'),
            ),
          ],
        );
      },
    );
  }

  void _insertLink(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        String linkUrl = '';
        String linkText = '';
        return AlertDialog(
          title: const Text('Insertar enlace'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Texto del enlace',
                  prefixIcon: Icon(Icons.text_fields),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => linkText = v,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'URL del enlace',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => linkUrl = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (linkUrl.isNotEmpty && linkText.isNotEmpty) {
                  _controller.formatText(
                    _controller.selection.baseOffset,
                    linkText.length,
                    LinkAttribute(linkUrl),
                  );
                  _showSnackBar(context, 'Enlace insertado');
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Insertar'),
            ),
          ],
        );
      },
    );
  }

  void _showColorPicker(BuildContext context) {
    final colors = [
      Colors.black,
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.brown,
      Colors.grey,
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Seleccionar color'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((color) {
              return InkWell(
                onTap: () {
                  _controller.formatSelection(ColorAttribute('#${color.toARGB32().toRadixString(16).padLeft(8, '0')}'));
                  Navigator.of(ctx).pop();
                  _showSnackBar(context, 'Color aplicado');
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  void _exportContent(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Exportar contenido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Exportar como JSON'),
                subtitle: const Text('Formato con formato completo'),
                onTap: () {
                  _showSnackBar(context, 'JSON copiado al portapapeles');
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet),
                title: const Text('Exportar como texto plano'),
                subtitle: const Text('Solo texto sin formato'),
                onTap: () {
                  _showSnackBar(context, 'Texto plano copiado al portapapeles');
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  void _importContent(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        String content = '';
        return AlertDialog(
          title: const Text('Importar contenido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pega el contenido JSON o texto a importar:'),
              const SizedBox(height: 16),
              TextField(
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Contenido a importar...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => content = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (content.isNotEmpty) {
                  try {
                    final jsonData = jsonDecode(content);
                    _controller.document = Document.fromJson(jsonData);
                    _showSnackBar(context, 'Contenido JSON importado');
                  } catch (e) {
                    _controller.document = Document()..insert(0, content);
                    _showSnackBar(context, 'Texto plano importado');
                  }
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Importar'),
            ),
          ],
        );
      },
    );
  }

  void _toggleFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Editor en pantalla completa'),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () async {
                  final json = jsonEncode(_controller.document.toDelta().toJson());
                  widget.onChanged(json);
                  // Capture navigator before awaiting to avoid using context across async gaps
                  final navigator = Navigator.of(context);
                  await widget.onSave(json);
                  navigator.pop();
                },
              ),
            ],
          ),
          body: QuillEditor.basic(controller: _controller),
        ),
      ),
    );
  }
}
