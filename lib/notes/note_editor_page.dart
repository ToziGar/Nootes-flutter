import 'package:flutter/material.dart';
import '../widgets/glass.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_input.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

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

  List<String> _tags = [];
  List<Map<String, dynamic>> _collections = [];
  String? _collectionId;
  List<String> _outgoing = [];
  List<Map<String, dynamic>> _otherNotes = [];

  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final svc = FirestoreService.instance;
    final uid = _uid;
    final n = await svc.getNote(uid: uid, noteId: widget.noteId);
    final cols = await svc.listCollections(uid: uid);
    final allNotes = await svc.listNotes(uid: uid);
    final outgoing = await svc.listOutgoingLinks(uid: uid, noteId: widget.noteId);
    setState(() {
      _title.text = (n?['title']?.toString() ?? '');
      _content.text = (n?['content']?.toString() ?? '');
      _tags = List<String>.from((n?['tags'] as List?)?.whereType<String>() ?? const []);
      _collectionId = n?['collectionId']?.toString();
      _collections = cols;
      _outgoing = outgoing;
      _otherNotes = allNotes.where((x) => x['id'].toString() != widget.noteId).toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirestoreService.instance.updateNote(uid: _uid, noteId: widget.noteId, data: {
        'title': _title.text,
        'content': _content.text,
      });
      if (widget.onChanged != null) await widget.onChanged!();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar nota'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
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
                      TextField(
                        controller: _content,
                        decoration: const InputDecoration(
                          labelText: 'Contenido',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                        minLines: 6,
                        maxLines: 20,
                      ),
                      const SizedBox(height: 12),
                      Text('Etiquetas', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      TagInput(
                        initialTags: _tags,
                        onAdd: (t) => _addTag(t),
                        onRemove: (t) => _removeTag(t),
                      ),
                      const SizedBox(height: 12),
                      Text('Enlaces (grafo)', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted)),
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
                                  .map((n) => DropdownMenuItem<String?>(
                                        value: n['id'].toString(),
                                        child: Text((n['title']?.toString() ?? '').isEmpty ? n['id'].toString() : n['title'].toString()),
                                      ))
                                  .toList(),
                              onChanged: (v) async {
                                if (v == null || v.isEmpty) return;
                                await _addLink(v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_outgoing.isEmpty)
                        const Text('Sin enlaces')
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: -6,
                          children: _outgoing
                              .map((to) => InputChip(
                                    label: Text(to),
                                    onDeleted: () => _removeLink(to),
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




