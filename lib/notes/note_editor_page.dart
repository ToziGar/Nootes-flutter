import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/glass.dart';
import '../widgets/tag_input.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/toast_service.dart';
import '../editor/markdown_editor.dart';
import '../services/storage_service.dart';
import '../widgets/advanced_editor.dart';
import '../widgets/editor_settings_dialog.dart';
import '../services/editor_config_service.dart';
import '../theme/app_colors.dart';
import '../services/sharing_service.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.noteId, this.onChanged});
  final String noteId;
  final Future<void> Function()? onChanged;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _autoSaving = false;
  Timer? _auto;

  // Editor avanzado
  bool _useAdvancedEditor = false;
  EditorConfig _editorConfig = EditorConfig.defaultConfig();
  final EditorConfigService _editorConfigService = EditorConfigService();

  List<String> _tags = [];
  List<Map<String, dynamic>> _collections = [];
  String? _collectionId;
  List<String> _outgoing = [];
  List<String> _incoming = [];
  List<Map<String, dynamic>> _otherNotes = [];
  Map<String, String> _wikiIndex = {};
  Map<String, String> _idToTitle = {};

  // Permission enforcement
  Map<String, dynamic>? _accessInfo;
  bool get _isReadOnly => _accessInfo != null && _accessInfo!['permission'] != 'owner' && _accessInfo!['permission'] != 'edit';

  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _load();
    _loadEditorConfig();
    _title.addListener(_scheduleAutoSave);
    _content.addListener(_scheduleAutoSave);
  }

  Future<void> _loadEditorConfig() async {
    final config = await _editorConfigService.getEditorConfig();
    setState(() {
      _editorConfig = config;
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _scheduleAutoSave() {
    _auto?.cancel();
    setState(() => _autoSaving = true);
    _auto = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      await _save(autosave: true);
      if (mounted) setState(() => _autoSaving = false);
    });
  }

  Future<void> _load() async {
    final svc = FirestoreService.instance;
    final uid = _uid;
    final n = await svc.getNote(uid: uid, noteId: widget.noteId);
    
    // Check permissions for this note
    String? noteOwnerId;
    if (n != null) {
      // For owned notes, owner is current user
      noteOwnerId = uid;
    } else {
      // Try to find note via sharing (shared with current user)
      // For now, we'll handle this case later - assume owned if found
      noteOwnerId = uid;
    }
    
    _accessInfo = await SharingService().checkNoteAccess(widget.noteId, noteOwnerId);
    
    final cols = await svc.listCollections(uid: uid);
    final allNotes = await svc.listNotes(uid: uid);
    final outgoing = await svc.listOutgoingLinks(uid: uid, noteId: widget.noteId);
    final incoming = await svc.listIncomingLinks(uid: uid, noteId: widget.noteId);
    setState(() {
      _title.text = (n?['title']?.toString() ?? '');
      _content.text = (n?['content']?.toString() ?? '');
      _tags = List<String>.from((n?['tags'] as List?)?.whereType<String>() ?? const []);
      _collectionId = n?['collectionId']?.toString();
      _collections = cols;
      _outgoing = outgoing;
      _incoming = incoming;
      _otherNotes = allNotes.where((x) => x['id'].toString() != widget.noteId).toList();
      // Index for wikilinks: use title if non-empty, otherwise use ID so [[...]] always resolves
      _wikiIndex = {
        for (final m in allNotes)
          ((m['title']?.toString() ?? '').isEmpty ? m['id'].toString() : m['title'].toString()): m['id'].toString(),
      };
      // Map for labels: keep the raw title (may be empty) so we can render "Title (ID)" cleanly
      _idToTitle = {
        for (final m in allNotes) m['id'].toString(): (m['title']?.toString() ?? ''),
      };
      _loading = false;
    });
  }

  // Human-friendly label for a note reference
  String _labelFor(String id) {
    final t = _idToTitle[id]?.trim() ?? '';
    if (t.isEmpty) return id;
    final short = _shortId(id);
    return '$t ($short)';
  }

  String _shortId(String id) {
    // Keep IDs compact for UI elements like chips
    return id.length <= 8 ? id : id.substring(0, 8);
  }

  Future<void> _save({bool autosave = false}) async {
    setState(() => _saving = true);
    try {
      await FirestoreService.instance.updateNote(uid: _uid, noteId: widget.noteId, data: {
        'title': _title.text,
        'content': _content.text,
      });
      if (widget.onChanged != null) await widget.onChanged!();
      if (mounted && !autosave) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _pickAndUploadImage(BuildContext context) async {
    try {
      final url = await StorageService.pickAndUploadImage(uid: _uid);
      if (url == null) return null;
      ToastService.success('Imagen subida');
      return url;
    } catch (e) {
      if (mounted) {
        ToastService.error('No se pudo subir la imagen: $e');
      }
      return null;
    }
  }

  Future<String?> _pickWiki(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enlace interno'),
        content: SizedBox(
          width: 420,
          height: 360,
          child: ListView.builder(
            itemCount: _otherNotes.length,
            itemBuilder: (context, i) {
              final n = _otherNotes[i];
              final rawTitle = (n['title']?.toString() ?? '');
              final id = n['id'].toString();
              final display = rawTitle.trim().isEmpty ? id : '${rawTitle.trim()} (${_shortId(id)})';
              // Important: return a key that exists in _wikiIndex (raw title if not empty, otherwise the ID)
              final returnKey = rawTitle.trim().isEmpty ? id : rawTitle.trim();
              return ListTile(title: Text(display), onTap: () => Navigator.pop(context, returnKey));
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
      ),
    );
  }

  Future<void> _setCollection(String? v) async {
    setState(() => _saving = true);
    try {
      await FirestoreService.instance.moveNoteToCollection(uid: _uid, noteId: widget.noteId, collectionId: (v ?? '').isEmpty ? null : v);
      setState(() => _collectionId = v);
      if (widget.onChanged != null) await widget.onChanged!();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addTag(String tag) async {
    await FirestoreService.instance.addTagToNote(uid: _uid, noteId: widget.noteId, tag: tag);
    await _load();
    if (widget.onChanged != null) await widget.onChanged!();
  }

  Future<void> _removeTag(String tag) async {
    await FirestoreService.instance.removeTagFromNote(uid: _uid, noteId: widget.noteId, tag: tag);
    await _load();
    if (widget.onChanged != null) await widget.onChanged!();
  }

  Future<void> _addLink(String toId) async {
    await FirestoreService.instance.addLink(uid: _uid, fromNoteId: widget.noteId, toNoteId: toId);
    await _load();
    if (widget.onChanged != null) await widget.onChanged!();
  }

  Future<void> _removeLink(String toId) async {
    await FirestoreService.instance.removeLink(uid: _uid, fromNoteId: widget.noteId, toNoteId: toId);
    await _load();
    if (widget.onChanged != null) await widget.onChanged!();
  }

  void _toggleAdvancedEditor() {
    setState(() {
      _useAdvancedEditor = !_useAdvancedEditor;
    });
  }

  void _showEditorSettings() {
    showDialog(
      context: context,
      builder: (context) => EditorSettingsDialog(
        initialConfig: _editorConfig,
        onConfigChanged: (config) {
          setState(() {
            _editorConfig = config;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar nota'),
        actions: [
          // Botón para cambiar tipo de editor
          PopupMenuButton<String>(
            icon: Icon(
              _useAdvancedEditor ? Icons.code : Icons.edit,
              color: _useAdvancedEditor ? AppColors.primary : null,
            ),
            tooltip: 'Opciones del editor',
            onSelected: (value) {
              switch (value) {
                case 'toggle':
                  _toggleAdvancedEditor();
                  break;
                case 'settings':
                  _showEditorSettings();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      _useAdvancedEditor ? Icons.edit : Icons.code,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(_useAdvancedEditor ? 'Editor simple' : 'Editor avanzado'),
                  ],
                ),
              ),
              if (_useAdvancedEditor)
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 20),
                      SizedBox(width: 8),
                      Text('Configuración'),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: _saving ? null : () => _save(),
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: GlassBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _title,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        initialValue: _collectionId,
                        decoration: const InputDecoration(
                          labelText: 'Colección',
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                        items: [
                          DropdownMenuItem<String?>(value: null, child: Text('Sin colección')),
                          DropdownMenuItem<String?>(value: '', child: Text('Sin colección')),
                          ..._collections.map((c) => DropdownMenuItem<String?>(
                                value: c['id'].toString(),
                                child: Text(c['name']?.toString() ?? c['id'].toString()),
                              )),
                        ],
                        onChanged: (v) => _setCollection(v),
                      ),
                      const SizedBox(height: 8),
                      // Editor de contenido (condicional)
                      Container(
                        height: 400, // Altura fija para el editor
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _useAdvancedEditor
                            ? AdvancedEditor(
                                initialText: _content.text,
                                onTextChanged: (text) {
                                  if (_content.text != text) {
                                    _content.text = text;
                                    _scheduleAutoSave();
                                  }
                                },
                                syntaxHighlighting: _editorConfig.syntaxHighlighting,
                                autoComplete: _editorConfig.autoComplete,
                                showLineNumbers: _editorConfig.showLineNumbers,
                                showMinimap: _editorConfig.showMinimap,
                                wordWrap: _editorConfig.wordWrap,
                                fontSize: _editorConfig.fontSize,
                                themeMode: Theme.of(context).brightness == Brightness.dark 
                                    ? ThemeMode.dark 
                                    : ThemeMode.light,
                              )
                            : MarkdownEditor(
                                controller: _content,
                                onChanged: _isReadOnly ? null : (_) => _scheduleAutoSave(),
                                onPickImage: _isReadOnly ? null : _pickAndUploadImage,
                                onPickWiki: _isReadOnly ? null : _pickWiki,
                                wikiIndex: _wikiIndex,
                                readOnly: _isReadOnly,
                                onOpenNote: (id) async {
                                  if (id == widget.noteId) return;
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: id, onChanged: widget.onChanged)),
                                  );
                                  await _load();
                                },
                                splitEnabled: true,
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text('Etiquetas', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      TagInput(
                        initialTags: _tags,
                        onAdd: (t) => _addTag(t),
                        onRemove: (t) => _removeTag(t),
                      ),
                      const SizedBox(height: 12),
                      Text('Enlaces (grafo)', style: Theme.of(context).textTheme.titleMedium),
                      if (_autoSaving)
                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 4),
                          child: Text('Guardando...', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              decoration: const InputDecoration(
                                labelText: 'Añadir enlace a…',
                                prefixIcon: Icon(Icons.link_rounded),
                              ),
                              items: _otherNotes
                                  .map((n) {
                                    final id = n['id'].toString();
                                    return DropdownMenuItem<String?>(
                                      value: id,
                                      child: Text(_labelFor(id)),
                                    );
                                  })
                                  .toList(),
                              onChanged: (v) async {
                                if (v == null || v.isEmpty) return;
                                await _addLink(v);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Quick create link button — abre un diálogo de búsqueda
                          SizedBox(
                            height: 56,
                            child: FilledButton.icon(
                              onPressed: _otherNotes.isEmpty
                                  ? null
                                  : () async {
                                      final selected = await showDialog<String?>(
                                        context: context,
                                        builder: (context) {
                                          List<Map<String, dynamic>> results = List.from(_otherNotes);
                                          return StatefulBuilder(builder: (context, setState) {
                                            void doFilter(String q) {
                                              final qq = q.trim().toLowerCase();
                                              setState(() {
                                                results = _otherNotes
                                                    .where((n) {
                                                      final title = (n['title']?.toString() ?? '').toLowerCase();
                                                      final id = n['id'].toString().toLowerCase();
                                                      return title.contains(qq) || id.contains(qq);
                                                    })
                                                    .toList();
                                              });
                                            }

                                            return AlertDialog(
                                              title: const Text('Crear enlace a...'),
                                              content: SizedBox(
                                                width: 480,
                                                height: 380,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    TextField(
                                                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar nota por título o id'),
                                                      onChanged: doFilter,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Expanded(
                                                      child: results.isEmpty
                                                          ? const Center(child: Text('No hay notas que coincidan'))
                                                          : ListView.separated(
                                                              itemCount: results.length,
                                                              separatorBuilder: (_, __) => const Divider(height: 1),
                                                              itemBuilder: (context, i) {
                                                                final n = results[i];
                                                                final id = n['id'].toString();
                                                                final title = (n['title']?.toString() ?? 'Sin título');
                                                                return ListTile(
                                                                  title: Text(title),
                                                                  subtitle: Text(_shortId(id)),
                                                                  onTap: () => Navigator.pop(context, id),
                                                                );
                                                              },
                                                            ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                                              ],
                                            );
                                          });
                                        },
                                      );
                                      if (selected != null && selected.isNotEmpty) {
                                        await _addLink(selected);
                                      }
                                    },
                              icon: const Icon(Icons.add_link_rounded),
                              label: const Text('Crear enlace'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Enlaces salientes', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      _outgoing.isEmpty
                          ? const Text('Sin enlaces')
                          : Wrap(
                            spacing: 6,
                            runSpacing: -6,
                            children: _outgoing
                                .map((to) => InputChip(
                                      label: Text(_labelFor(to)),
                                      onDeleted: () => _removeLink(to),
                                      onPressed: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: to, onChanged: widget.onChanged)),
                                        );
                                          await _load();
                                        },
                                      ))
                                  .toList(),
                            ),
                      const SizedBox(height: 12),
                      Text('Enlaces entrantes', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      _incoming.isEmpty
                          ? const Text('Sin enlaces hacia esta nota')
                          : Wrap(
                            spacing: 6,
                            runSpacing: -6,
                            children: _incoming
                                .map((from) => ActionChip(
                                      label: Text(_labelFor(from)),
                                      onPressed: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: from, onChanged: widget.onChanged)),
                                        );
                                        await _load();
                                      },
                                    ))
                                .toList(),
                          ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}




