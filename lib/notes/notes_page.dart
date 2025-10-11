import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/glass.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'note_editor_page.dart';
import 'collections_page.dart';
import 'graph_page.dart';
import 'trash_page.dart';
import '../widgets/expandable_fab.dart';

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
  final _search = TextEditingController();
  Timer? _debounce;

  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _init = _reloadAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reloadAll() async {
    final svc = FirestoreService.instance;
    final uid = _uid;
    final s = _search.text.trim();
    final notes = s.isEmpty
        ? await svc.listNotesSummary(uid: uid)
        : await svc.searchNotesSummary(uid: uid, query: s);
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
      final id = await FirestoreService.instance.createNote(
        uid: _uid,
        data: {
          'title': '',
          'content': '',
          'tags': <String>[],
          'links': <String>[],
          if (_selectedCollection != null && _selectedCollection!.isNotEmpty)
            'collectionId': _selectedCollection,
        },
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NoteEditorPage(noteId: id, onChanged: _reloadAll),
        ),
      );
      await _reloadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo crear la nota: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredNotes {
    Iterable<Map<String, dynamic>> list = _notes;
    if (_selectedCollection != null && _selectedCollection!.isNotEmpty) {
      list = list.where(
        (n) => (n['collectionId']?.toString() ?? '') == _selectedCollection,
      );
    }
    if (_selectedTag != null && _selectedTag!.isNotEmpty) {
      list = list.where((n) {
        final tags = (n['tags'] as List?)?.whereType<String>() ?? const [];
        return tags.contains(_selectedTag);
      });
    }
    return list.toList();
  }

  Future<void> _togglePin(Map<String, dynamic> n) async {
    final id = n['id'].toString();
    final pinned = n['pinned'] == true;
    await FirestoreService.instance.setPinned(
      uid: _uid,
      noteId: id,
      pinned: !pinned,
    );
    await _reloadAll();
  }

  Future<void> _moveToTrash(Map<String, dynamic> n) async {
    await FirestoreService.instance.softDeleteNote(
      uid: _uid,
      noteId: n['id'].toString(),
    );
    await _reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas'),
        actions: [
          IconButton(
            tooltip: 'Papelera',
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TrashPage()));
              await _reloadAll();
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          IconButton(
            tooltip: 'Grafo',
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const GraphPage()));
            },
            icon: const Icon(Icons.account_tree_rounded),
          ),
          IconButton(
            tooltip: 'Colecciones',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CollectionsPage()),
              );
              await _reloadAll();
            },
            icon: const Icon(Icons.folder_open_rounded),
          ),
        ],
      ),
      floatingActionButton: ExpandableFab(
        actions: [
          FloatingActionButton.small(
            onPressed: _loading ? null : _createNote,
            tooltip: 'Nueva nota',
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.note_add_rounded),
          ),
          FloatingActionButton.small(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Agregar imagen (pendiente)')),
              );
            },
            tooltip: 'Imagen',
            child: const Icon(Icons.photo_camera),
          ),
          FloatingActionButton.small(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Grabar audio (pendiente)')),
              );
            },
            tooltip: 'Audio',
            child: const Icon(Icons.mic_rounded),
          ),
        ],
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
                    TextField(
                      controller: _search,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Buscar por título',
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 450),
                          _reloadAll,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedCollection,
                            decoration: InputDecoration(
                              labelText: 'Colección',
                              labelStyle: TextStyle(
                                color: AppColors.primary,
                                fontSize: 16,
                              ),
                              prefixIcon: Icon(
                                Icons.folder_outlined,
                                color: AppColors.primary,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            dropdownColor: Colors.white,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: const Text(
                                  'Todas',
                                  style: TextStyle(color: Colors.black87),
                                ),
                              ),
                              DropdownMenuItem<String?>(
                                value: '',
                                child: const Text('Sin colección'),
                              ),
                              ..._collections.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c['id'].toString(),
                                  child: Text(
                                    c['name']?.toString() ?? c['id'].toString(),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedCollection = v),
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
                              DropdownMenuItem<String?>(
                                value: null,
                                child: const Text('Todas'),
                              ),
                              ..._tags.map(
                                (t) => DropdownMenuItem<String?>(
                                  value: t,
                                  child: Text('#$t'),
                                ),
                              ),
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
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final n = _filteredNotes[i];
                                final title =
                                    (n['title']?.toString() ?? '').isEmpty
                                    ? 'Sin título'
                                    : n['title'].toString();
                                final tags =
                                    (n['tags'] as List?)
                                        ?.whereType<String>()
                                        .toList() ??
                                    const [];
                                final pinned = n['pinned'] == true;
                                return ListTile(
                                  title: Text(title),
                                  subtitle: tags.isEmpty
                                      ? null
                                      : Wrap(
                                          spacing: 6,
                                          runSpacing: -6,
                                          children: tags
                                              .take(6)
                                              .map(
                                                (t) => ActionChip(
                                                  label: Text(t),
                                                  onPressed: () => setState(
                                                    () => _selectedTag = t,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => NoteEditorPage(
                                          noteId: n['id'].toString(),
                                          onChanged: _reloadAll,
                                        ),
                                      ),
                                    );
                                    await _reloadAll();
                                  },
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: pinned ? 'Desfijar' : 'Fijar',
                                        onPressed: () => _togglePin(n),
                                        icon: Icon(
                                          pinned
                                              ? Icons.star_rounded
                                              : Icons.star_border_rounded,
                                        ),
                                        color: pinned ? Colors.amber : null,
                                      ),
                                      PopupMenuButton<String>(
                                        color: Colors.white,
                                        elevation: 8,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: Colors.black87,
                                        ),
                                        onSelected: (v) async {
                                          if (v == 'trash') {
                                            await _moveToTrash(n);
                                          } else if (v == 'purge') {
                                            await FirestoreService.instance
                                                .purgeNote(
                                                  uid: _uid,
                                                  noteId: n['id'].toString(),
                                                );
                                            await _reloadAll();
                                          } else if (v == 'duplicate') {
                                            final src = n;
                                            final newId = await FirestoreService
                                                .instance
                                                .createNote(
                                                  uid: _uid,
                                                  data: {
                                                    'title': src['title'] ?? '',
                                                    'content':
                                                        src['content'] ?? '',
                                                    'tags':
                                                        (src['tags'] as List?)
                                                            ?.whereType<
                                                              String
                                                            >()
                                                            .toList() ??
                                                        <String>[],
                                                    'links':
                                                        (src['links'] as List?)
                                                            ?.whereType<
                                                              String
                                                            >()
                                                            .toList() ??
                                                        <String>[],
                                                    if ((src['collectionId']
                                                            ?.toString()
                                                            .isNotEmpty ??
                                                        false))
                                                      'collectionId':
                                                          src['collectionId']
                                                              .toString(),
                                                  },
                                                );
                                            if (context.mounted) {
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      NoteEditorPage(
                                                        noteId: newId,
                                                        onChanged: _reloadAll,
                                                      ),
                                                ),
                                              );
                                            }
                                            await _reloadAll();
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'duplicate',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.copy,
                                                  color: AppColors.primary,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  'Duplicar',
                                                  style: TextStyle(
                                                    color: Colors.black87,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'trash',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete,
                                                  color: Colors.orange,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  'Mover a papelera',
                                                  style: TextStyle(
                                                    color: Colors.black87,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'purge',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete_forever,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  'Eliminar permanentemente',
                                                  style: TextStyle(
                                                    color: Colors.black87,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
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
