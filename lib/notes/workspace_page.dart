import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/glass.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../editor/markdown_editor.dart';
import '../editor/rich_text_editor.dart';
import '../widgets/tag_input.dart';

class NotesWorkspacePage extends StatefulWidget {
  const NotesWorkspacePage({super.key});

  @override
  State<NotesWorkspacePage> createState() => _NotesWorkspacePageState();
}

class _NotesWorkspacePageState extends State<NotesWorkspacePage> {
  final _search = TextEditingController();
  final _title = TextEditingController();
  final _content = TextEditingController();
  List<String> _tags = [];

  List<Map<String, dynamic>> _notes = [];
  String? _selectedId;
  Timer? _debounce;
  bool _loading = true;
  bool _saving = false;
  bool _richMode = false;
  String _richJson = '';

  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _search.dispose();
    _title.dispose();
    _content.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final svc = FirestoreService.instance;
    final q = _search.text.trim();
    final notes = q.isEmpty
        ? await svc.listNotesSummary(uid: _uid)
        : await svc.searchNotesSummary(uid: _uid, query: q);
    setState(() {
      _notes = notes;
      _loading = false;
    });
    if (_selectedId == null && notes.isNotEmpty) {
      _select(notes.first['id'].toString());
    }
  }

  Future<void> _select(String id) async {
    setState(() {
      _selectedId = id;
      _saving = true;
    });
    final n = await FirestoreService.instance.getNote(uid: _uid, noteId: id);
    setState(() {
      _title.text = (n?['title']?.toString() ?? '');
      _content.text = (n?['content']?.toString() ?? '');
      _tags = List<String>.from((n?['tags'] as List?)?.whereType<String>() ?? const []);
      _richJson = (n?['rich']?.toString() ?? '');
      _saving = false;
    });
  }

  Future<void> _save() async {
    if (_selectedId == null) return;
    setState(() => _saving = true);
    try {
      final data = {
        'title': _title.text,
        'content': _content.text,
        'tags': _tags,
      };
      if (_richJson.isNotEmpty) {
        data['rich'] = _richJson;
      }
      await FirestoreService.instance.updateNote(
        uid: _uid,
        noteId: _selectedId!,
        data: data,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _create() async {
    final id = await FirestoreService.instance.createNote(uid: _uid, data: {
      'title': '',
      'content': '',
      'tags': <String>[],
      'links': <String>[],
    });
    await _loadNotes();
    await _select(id);
  }

  Future<void> _delete(String id) async {
    await FirestoreService.instance.deleteNote(uid: _uid, noteId: id);
    if (_selectedId == id) {
      _selectedId = null;
      _title.clear();
      _content.clear();
      _tags = [];
    }
    await _loadNotes();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _loadNotes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nootes — Workspace'),
        actions: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Markdown')),
              ButtonSegment(value: true, label: Text('Rich')),
            ],
            selected: {_richMode},
            onSelectionChanged: (s) => setState(() => _richMode = s.first),
          ),
          const SizedBox(width: 8),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          IconButton(
            tooltip: 'Guardar',
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
          ),
        ],
      ),
      body: GlassBackground(
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 300,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              hintText: 'Buscar notas…',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Nueva nota',
                          onPressed: _create,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            itemCount: _notes.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final n = _notes[i];
                              final id = n['id'].toString();
                              final title = (n['title']?.toString() ?? '').isEmpty ? 'Sin título' : n['title'].toString();
                              final selected = id == _selectedId;
                              return Material(
                                color: selected ? Colors.white.withOpacity(0.06) : Colors.transparent,
                                child: ListTile(
                                  dense: true,
                                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  leading: IconButton(
                                    icon: Icon((n['pinned'] == true) ? Icons.star_rounded : Icons.star_border_rounded,
                                        color: (n['pinned'] == true) ? Colors.amber : null),
                                    onPressed: () async {
                                      await FirestoreService.instance.setPinned(uid: _uid, noteId: id, pinned: !(n['pinned'] == true));
                                      await _loadNotes();
                                    },
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'delete') await _delete(id);
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                    ],
                                  ),
                                  onTap: () => _select(id),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            // Editor area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _selectedId == null
                    ? const Center(child: Text('Selecciona o crea una nota'))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _title,
                              decoration: const InputDecoration(
                                hintText: 'Título',
                                prefixIcon: Icon(Icons.title_rounded),
                              ),
                              onChanged: (_) => _debouncedSave(),
                            ),
                            const SizedBox(height: 12),
                            _richMode
                                ? RichTextEditor(
                                    uid: _uid,
                                    initialDeltaJson: _richJson.isEmpty ? null : _richJson,
                                    onChanged: (deltaJson) {
                                      _richJson = deltaJson;
                                      _debouncedSave();
                                    },
                                    onSave: (deltaJson) async {
                                      _richJson = deltaJson;
                                      await _save();
                                    },
                                  )
                                : MarkdownEditor(
                                    controller: _content,
                                    onChanged: (_) => _debouncedSave(),
                                    splitEnabled: true,
                                  ),
                            const SizedBox(height: 12),
                            Text('Etiquetas'),
                            const SizedBox(height: 6),
                            TagInput(
                              initialTags: _tags,
                              onAdd: (t) async { setState(() => _tags = [..._tags, t]); await _save(); },
                              onRemove: (t) async { setState(() => _tags = _tags.where((e) => e != t).toList()); await _save(); },
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _debouncedSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }
}
