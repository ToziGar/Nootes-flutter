import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../widgets/glass.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../editor/markdown_editor.dart';
import '../editor/rich_text_editor.dart';
import '../widgets/tag_input.dart';
import '../widgets/expandable_fab.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';

class NotesWorkspacePage extends StatefulWidget {
  const NotesWorkspacePage({super.key});

  @override
  State<NotesWorkspacePage> createState() => _NotesWorkspacePageState();
}

class _NotesWorkspacePageState extends State<NotesWorkspacePage> with TickerProviderStateMixin {
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
  bool _focusMode = false;
  final _storage = const FlutterSecureStorage();
  bool _isRecording = false;
  late final AnimationController _editorCtrl;
  late final Animation<double> _editorFade;
  late final Animation<Offset> _editorOffset;

  late final AnimationController _savePulseCtrl;
  late final Animation<double> _saveScale;

  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _editorCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _editorFade = CurvedAnimation(parent: _editorCtrl, curve: Curves.easeIn);
    _editorOffset = Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(_editorCtrl);

    _savePulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _saveScale = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _savePulseCtrl, curve: Curves.easeOut));

    _loadLastAndNotes();
  }

  Future<void> _loadLastAndNotes() async {
    final last = await _storage.read(key: 'last_note_id');
    await _loadNotes();
    if (last != null && last.isNotEmpty) {
      // If last exists and present in notes, select it
      final present = _notes.any((n) => n['id'].toString() == last);
      if (present) _select(last);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _title.dispose();
    _content.dispose();
    _debounce?.cancel();
    _editorCtrl.dispose();
    _savePulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final svc = FirestoreService.instance;
    final q = _search.text.trim();
    final notes = q.isEmpty
        ? await svc.listNotesSummary(uid: _uid)
        : await svc.searchNotesSummary(uid: _uid, query: q);
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
    if (_selectedId == null && notes.isNotEmpty) {
      await _select(notes.first['id'].toString());
    }
  }

  Future<void> _select(String id) async {
    if (!mounted) return;
    setState(() {
      _selectedId = id;
      _saving = true;
    });
    final n = await FirestoreService.instance.getNote(uid: _uid, noteId: id);
    if (!mounted) return;
    setState(() {
      _title.text = (n?['title']?.toString() ?? '');
      _content.text = (n?['content']?.toString() ?? '');
      _tags = List<String>.from((n?['tags'] as List?)?.whereType<String>() ?? const []);
      _richJson = (n?['rich']?.toString() ?? '');
      _saving = false;
    });
    // run editor entrance animation
    try {
      if (mounted) _editorCtrl.forward(from: 0);
    } catch (_) {}
    // persist last opened note id
    await _storage.write(key: 'last_note_id', value: id);
  }

  Future<void> _save() async {
    if (_selectedId == null) return;
    // small pulse feedback
    _savePulseCtrl.forward().then((_) => _savePulseCtrl.reverse());
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

  Future<void> _insertImage() async {
    final url = await StorageService.pickAndUploadImage(uid: _uid);
    if (url == null) return;
    // insert markdown image at cursor: simple append for now
    final newText = '${_content.text}\n![]($url)\n';
    setState(() {
      _content.text = newText;
    });
    await _save();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final url = await AudioService.stopAndUpload(uid: _uid);
      setState(() => _isRecording = false);
      if (url != null) {
        final newText = '${_content.text}\n[audio]($url)\n';
        setState(() => _content.text = newText);
        await _save();
      }
    } else {
      final path = await AudioService.startRecording();
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No permission to record audio')));
        return;
      }
      setState(() => _isRecording = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grabando... pulsa otra vez para detener')));
    }
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
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 700;
      return Scaffold(
        appBar: _focusMode
            ? null
            : AppBar(
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
                  ScaleTransition(
                    scale: _saveScale,
                    child: IconButton(
                      tooltip: 'Guardar',
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                    ),
                  ),
                  IconButton(
                    tooltip: _focusMode ? 'Salir de foco' : 'Modo foco',
                    onPressed: () => setState(() => _focusMode = !_focusMode),
                    icon: Icon(_focusMode ? Icons.fullscreen_exit : Icons.center_focus_strong_rounded),
                  ),
                ],
              ),
        drawer: narrow
            ? Drawer(
                child: SafeArea(child: _buildNotesList(width: constraints.maxWidth)),
              )
            : null,
        body: GlassBackground(
          child: Row(
            children: [
              if (!_focusMode && !narrow)
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.white.withOpacity(0.08))),
                    ),
                    child: SafeArea(child: _buildNotesList(width: constraints.maxWidth)),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: narrow ? 12.0 : 24.0, vertical: 16.0),
                  child: _selectedId == null
                      ? const Center(child: Text('Selecciona o crea una nota'))
                      : FadeTransition(
                          opacity: _editorFade,
                          child: SlideTransition(
                            position: _editorOffset,
                            child: SingleChildScrollView(
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
                                  const Text('Etiquetas'),
                                  const SizedBox(height: 6),
                                  TagInput(
                                    initialTags: _tags,
                                    onAdd: (t) async {
                                      setState(() => _tags = [..._tags, t]);
                                      await _save();
                                    },
                                    onRemove: (t) async {
                                      setState(() => _tags = _tags.where((e) => e != t).toList());
                                      await _save();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Padding(
          padding: EdgeInsets.only(bottom: narrow ? 12 : 20, right: narrow ? 12 : 24),
          child: ExpandableFab(
            actions: [
              FloatingActionButton.small(
                onPressed: _create,
                tooltip: 'Nueva nota',
                child: const Icon(Icons.note_add_rounded),
              ),
              FloatingActionButton.small(
                onPressed: _insertImage,
                tooltip: 'Imagen',
                child: const Icon(Icons.photo_camera),
              ),
              FloatingActionButton.small(
                onPressed: _toggleRecording,
                tooltip: 'Audio',
                child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildNotesList({required double width}) {
    return Column(
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
    );
  }

  void _debouncedSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }
}
