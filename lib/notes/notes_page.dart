import 'package:flutter/material.dart';
import '../widgets/glass.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'note_editor_page.dart';
import 'collections_page.dart';
import 'graph_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late Future<void> _init;
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _collections = [];
  List<String> _tags = [];

  String? _selectedCollection;
  String? _selectedTag;
  bool _loading = false;

  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _init = _reloadAll();
  }

  Future<void> _reloadAll() async {
    final svc = FirestoreService.instance;
    final uid = _uid;
    final notes = await svc.listNotes(uid: uid);
    final cols = await svc.listCollections(uid: uid);
    final tags = await svc.listTags(uid: uid);
    setState(() {
      _notes = notes;
      _collections = cols;
      _tags = tags;
    });
  }

  Future<void> _createNote() async {
    setState(() => _loading = true);
    try {
      final id = await FirestoreService.instance.createNote(uid: _uid, data: {
        'title': '',
        'content': '',
        'tags': <String>[],
        'links': <String>[],
        if (_selectedCollection != null && _selectedCollection!.isNotEmpty) 'collectionId': _selectedCollection,
      });
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NoteEditorPage(noteId: id, onChanged: _reloadAll),
      ));
      await _reloadAll();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredNotes {
    Iterable<Map<String, dynamic>> list = _notes;
    if (_selectedCollection != null && _selectedCollection!.isNotEmpty) {
      list = list.where((n) => (n['collectionId']?.toString() ?? '') == _selectedCollection);
    }
    if (_selectedTag != null && _selectedTag!.isNotEmpty) {
      list = list.where((n) {
        final tags = (n['tags'] as List?)?.whereType<String>() ?? const [];
        return tags.contains(_selectedTag);
      });
    }
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas'),
        actions: [
          IconButton(
            tooltip: 'Grafo',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GraphPage()));
            },
            icon: const Icon(Icons.account_tree_rounded),
          ),
          IconButton(
            tooltip: 'Colecciones',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollectionsPage()));
              await _reloadAll();
            },
            icon: const Icon(Icons.folder_open_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _createNote,
        icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.note_add_rounded),
        label: const Text('Nueva nota'),
      ),
      body: GlassBackground(
        child: SafeArea(
          child: FutureBuilder<void>(
            future: _init,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                        initialValue: _selectedCollection,
                            decoration: const InputDecoration(
                              labelText: 'Colección',
                              prefixIcon: Icon(Icons.folder_outlined),
                            ),
                            items: [
                              DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                              DropdownMenuItem<String?>(value: '', child: Text('Sin colección')),
                              ..._collections.map((c) => DropdownMenuItem<String?>(
                                    value: c['id'].toString(),
                                    child: Text(c['name']?.toString() ?? c['id'].toString()),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _selectedCollection = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                        initialValue: _selectedTag,
                            decoration: const InputDecoration(
                              labelText: 'Etiqueta',
                              prefixIcon: Icon(Icons.sell_outlined),
                            ),
                            items: [
                              DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                              ..._tags.map((t) => DropdownMenuItem<String?>(value: t, child: Text('#$t'))),
                            ],
                            onChanged: (v) => setState(() => _selectedTag = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _filteredNotes.isEmpty
                          ? const Center(child: Text('No hay notas'))
                          : ListView.separated(
                              itemCount: _filteredNotes.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final n = _filteredNotes[i];
                                final title = (n['title']?.toString() ?? '').isEmpty ? 'Sin título' : n['title'].toString();
                                final tags = (n['tags'] as List?)?.whereType<String>().toList() ?? const [];
                                return ListTile(
                                  title: Text(title),
                                  subtitle: tags.isEmpty
                                      ? null
                                      : Wrap(
                                          spacing: 6,
                                          runSpacing: -6,
                                          children: tags.take(6).map((t) => Chip(label: Text(t))).toList(),
                                        ),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => NoteEditorPage(noteId: n['id'].toString(), onChanged: _reloadAll),
                                      ),
                                    );
                                    await _reloadAll();
                                  },
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'delete') {
                                        await FirestoreService.instance.deleteNote(uid: _uid, noteId: n['id'].toString());
                                        await _reloadAll();
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}





