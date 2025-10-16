// ignore_for_file: unused_element_parameter

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
import 'note_templates.dart';
import '../widgets/advanced_search_dialog.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  // Performance: cache and lazy loading
  static const int _notesPageSize = 30;
  int _notesLoaded = 0;
  bool _hasMoreNotes = true;
  bool _isLoadingMore = false;
  final List<Map<String, dynamic>> _notesCache = [];
  String? _lastNoteId;
  final ScrollController _scrollController = ScrollController();
  // Advanced search state
  String? _searchQueryAdvanced;
  List<String> _searchTagsAdvanced = [];
  DateTimeRange? _searchDateRangeAdvanced;
  SortOption _searchSortOptionAdvanced = SortOption.dateDesc;
  bool _gridView = false;
  bool _sortPinnedFirst = true;
  bool _sortNewestFirst = true;
  late Future<void> _init;
  List<Map<String, dynamic>> _collections = [];
  List<String> _tags = [];

  String? _selectedCollection;
  String? _selectedTag;
  String? _selectedTemplateId;
  bool _loading = false;
  final _search = TextEditingController();
  Timer? _debounce;

  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _init = _reloadAll();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMoreNotes) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMoreNotes();
    }
  }

  Future<void> _loadMoreNotes() async {
    if (_isLoadingMore || !_hasMoreNotes) return;
    setState(() => _isLoadingMore = true);
    try {
      final svc = FirestoreService.instance;
      final nextBatch = await svc.listNotesPaginated(
        uid: _uid,
        limit: _notesPageSize,
        startAfterId: _lastNoteId,
      );
      if (nextBatch.isEmpty) {
        setState(() {
          _hasMoreNotes = false;
          _isLoadingMore = false;
        });
        return;
      }
      setState(() {
        _notesCache.addAll(nextBatch);
        _notesLoaded += nextBatch.length;
        _lastNoteId = nextBatch.isNotEmpty ? nextBatch.last['id'] : _lastNoteId;
        _isLoadingMore = false;
        if (nextBatch.length < _notesPageSize) {
          _hasMoreNotes = false;
        }
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _reloadAll() async {
    final svc = FirestoreService.instance;
    final uid = _uid;
    final cols = await svc.listCollections(uid: uid);
    final tags = await svc.listTags(uid: uid);
    setState(() {
      _collections = cols;
      _tags = tags;
      _notesCache.clear();
      _notesLoaded = 0;
      _hasMoreNotes = true;
      _lastNoteId = null;
    });
    await _loadMoreNotes();
  }

  Future<void> _createNote() async {
    setState(() => _loading = true);
    try {
      String content = '';
      String title = '';
      List<String> tags = <String>[];
      // Import templates
      final templates = BuiltInTemplates.all;
      if (_selectedTemplateId != null && _selectedTemplateId!.isNotEmpty) {
        final template = templates.firstWhere(
          (t) => t.id == _selectedTemplateId,
          orElse: () => templates.first,
        );
        content = template.applyVariables({});
        title = template.name;
        tags = template.tags;
      }
      final id = await FirestoreService.instance.createNote(
        uid: _uid,
        data: {
          'title': title,
          'content': content,
          'tags': tags,
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
    Iterable<Map<String, dynamic>> list = _notesCache;
    // Advanced search query
    if (_searchQueryAdvanced != null &&
        _searchQueryAdvanced!.trim().isNotEmpty) {
      final q = _searchQueryAdvanced!.toLowerCase();
      list = list.where((n) {
        final title = (n['title']?.toString() ?? '').toLowerCase();
        final content = (n['content']?.toString() ?? '').toLowerCase();
        return title.contains(q) || content.contains(q);
      });
    }
    // Advanced tag filter
    if (_searchTagsAdvanced.isNotEmpty) {
      list = list.where((n) {
        final tags = (n['tags'] as List?)?.whereType<String>() ?? const [];
        return _searchTagsAdvanced.any((tag) => tags.contains(tag));
      });
    }
    // Advanced date range filter
    if (_searchDateRangeAdvanced != null) {
      final start = _searchDateRangeAdvanced!.start;
      final end = _searchDateRangeAdvanced!.end;
      list = list.where((n) {
        final updated = n['updatedAt'];
        if (updated is int) {
          final date = DateTime.fromMillisecondsSinceEpoch(updated);
          return date.isAfter(start.subtract(const Duration(days: 1))) &&
              date.isBefore(end.add(const Duration(days: 1)));
        }
        return true;
      });
    }
    // Collection and tag filters (legacy)
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
    var result = list.toList();
    // Advanced sort
    switch (_searchSortOptionAdvanced) {
      case SortOption.dateDesc:
        result.sort(
          (a, b) => (b['updatedAt'] ?? 0).compareTo(a['updatedAt'] ?? 0),
        );
        break;
      case SortOption.dateAsc:
        result.sort(
          (a, b) => (a['updatedAt'] ?? 0).compareTo(b['updatedAt'] ?? 0),
        );
        break;
      case SortOption.titleAsc:
        result.sort(
          (a, b) => (a['title']?.toString() ?? '').compareTo(
            b['title']?.toString() ?? '',
          ),
        );
        break;
      case SortOption.titleDesc:
        result.sort(
          (a, b) => (b['title']?.toString() ?? '').compareTo(
            a['title']?.toString() ?? '',
          ),
        );
        break;
      case SortOption.updated:
        result.sort(
          (a, b) => (b['updatedAt'] ?? 0).compareTo(a['updatedAt'] ?? 0),
        );
        break;
    }
    // Pinned sort (legacy)
    if (_sortPinnedFirst) {
      result.sort((a, b) {
        final ap = a['pinned'] == true ? 1 : 0;
        final bp = b['pinned'] == true ? 1 : 0;
        if (ap != bp) return bp - ap;
        return 0;
      });
    }
    // Lazy loading: return only loaded portion
    return result.take(_notesLoaded).toList();
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
            tooltip: 'Búsqueda avanzada',
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () async {
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (ctx) => AdvancedSearchDialog(
                  initialSearchQuery: _searchQueryAdvanced,
                  initialSelectedTags: _searchTagsAdvanced,
                  initialDateRange: _searchDateRangeAdvanced,
                  initialSortOption: _searchSortOptionAdvanced,
                  availableTags: _tags,
                ),
              );
              if (result != null) {
                setState(() {
                  _searchQueryAdvanced = result['query'] as String?;
                  _searchTagsAdvanced =
                      (result['tags'] as List?)?.whereType<String>().toList() ??
                      [];
                  _searchDateRangeAdvanced =
                      result['dateRange'] as DateTimeRange?;
                  _searchSortOptionAdvanced =
                      result['sortOption'] as SortOption? ??
                      SortOption.dateDesc;
                });
                await _reloadAll();
              }
            },
          ),
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
            onPressed: _loading
                ? null
                : () async {
                    await showDialog(
                      context: context,
                      builder: (ctx) {
                        final templates = BuiltInTemplates.all;
                        return AlertDialog(
                          title: const Text('Seleccionar plantilla'),
                          content: SizedBox(
                            width: 350,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedTemplateId,
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('Nota vacía'),
                                    ),
                                    ...templates.map(
                                      (t) => DropdownMenuItem(
                                        value: t.id,
                                        child: Row(
                                          children: [
                                            Icon(t.icon, color: t.color),
                                            const SizedBox(width: 8),
                                            Text(t.name),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _selectedTemplateId = v),
                                  decoration: const InputDecoration(
                                    labelText: 'Plantilla',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedTemplateId == null
                                      ? 'Crea una nota vacía.'
                                      : templates
                                            .firstWhere(
                                              (t) =>
                                                  t.id == _selectedTemplateId,
                                              orElse: () => templates.first,
                                            )
                                            .description,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                              },
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _createNote();
                              },
                              icon: const Icon(Icons.note_add_rounded),
                              label: const Text('Crear nota'),
                            ),
                          ],
                        );
                      },
                    );
                  },
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
                    // Sorting controls
                    Row(
                      children: [
                        IconButton(
                          tooltip: _sortPinnedFirst
                              ? 'Mostrar fijadas primero'
                              : 'Ordenar sin fijadas',
                          icon: Icon(
                            _sortPinnedFirst ? Icons.star : Icons.star_border,
                            color: AppColors.primary,
                          ),
                          onPressed: () => setState(
                            () => _sortPinnedFirst = !_sortPinnedFirst,
                          ),
                        ),
                        IconButton(
                          tooltip: _sortNewestFirst
                              ? 'Más recientes primero'
                              : 'Más antiguas primero',
                          icon: Icon(
                            _sortNewestFirst
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: AppColors.primary,
                          ),
                          onPressed: () => setState(
                            () => _sortNewestFirst = !_sortNewestFirst,
                          ),
                        ),
                        IconButton(
                          tooltip: _gridView
                              ? 'Vista de lista'
                              : 'Vista de cuadrícula',
                          icon: Icon(
                            _gridView ? Icons.view_list : Icons.grid_view,
                            color: AppColors.primary,
                          ),
                          onPressed: () =>
                              setState(() => _gridView = !_gridView),
                        ),
                      ],
                    ),
                    Expanded(
                      child: _filteredNotes.isEmpty
                          ? const Center(child: Text('No hay notas'))
                          : _gridView
                          ? GridView.builder(
                              controller: _scrollController,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 1.6,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount:
                                  _filteredNotes.length +
                                  (_hasMoreNotes ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i == _filteredNotes.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
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
                                return _NoteCard(
                                  note: n,
                                  title: title,
                                  tags: tags,
                                  pinned: pinned,
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
                                  onPin: () => _togglePin(n),
                                  onMenu: (v) async {
                                    if (v == 'trash') {
                                      await _moveToTrash(n);
                                    } else if (v == 'purge') {
                                      await FirestoreService.instance.purgeNote(
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
                                              'content': src['content'] ?? '',
                                              'tags':
                                                  (src['tags'] as List?)
                                                      ?.whereType<String>()
                                                      .toList() ??
                                                  <String>[],
                                              'links':
                                                  (src['links'] as List?)
                                                      ?.whereType<String>()
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
                                            builder: (_) => NoteEditorPage(
                                              noteId: newId,
                                              onChanged: _reloadAll,
                                            ),
                                          ),
                                        );
                                      }
                                      await _reloadAll();
                                    }
                                  },
                                );
                              },
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              itemCount:
                                  _filteredNotes.length +
                                  (_hasMoreNotes ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                if (i == _filteredNotes.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
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
                                return _NoteCard(
                                  note: n,
                                  title: title,
                                  tags: tags,
                                  pinned: pinned,
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
                                  onPin: () => _togglePin(n),
                                  onMenu: (v) async {
                                    if (v == 'trash') {
                                      await _moveToTrash(n);
                                    } else if (v == 'purge') {
                                      await FirestoreService.instance.purgeNote(
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
                                              'content': src['content'] ?? '',
                                              'tags':
                                                  (src['tags'] as List?)
                                                      ?.whereType<String>()
                                                      .toList() ??
                                                  <String>[],
                                              'links':
                                                  (src['links'] as List?)
                                                      ?.whereType<String>()
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
                                            builder: (_) => NoteEditorPage(
                                              noteId: newId,
                                              onChanged: _reloadAll,
                                            ),
                                          ),
                                        );
                                      }
                                      await _reloadAll();
                                    }
                                  },
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

class _NoteCard extends StatefulWidget {
  final Map<String, dynamic> note;
  final String title;
  final List<String> tags;
  final bool pinned;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final ValueChanged<String> onMenu;
  const _NoteCard({
    super.key,
    required this.note,
    required this.title,
    required this.tags,
    required this.pinned,
    required this.onTap,
    required this.onPin,
    required this.onMenu,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isWeb =
        Theme.of(context).platform == TargetPlatform.fuchsia ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.macOS;
    Widget card = Semantics(
      label: 'Nota${widget.pinned ? ' fijada' : ''}: ${widget.title}',
      button: true,
      child: Card(
        elevation: _hovering ? 8 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.pinned)
                      Semantics(
                        label: 'Nota fijada',
                        child: Icon(
                          Icons.star_rounded,
                          color: Colors.amber.shade700,
                          size: 20,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_hovering || !isWeb)
                      FocusTraversalOrder(
                        order: NumericFocusOrder(1.0),
                        child: IconButton(
                          icon: Icon(
                            widget.pinned
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: widget.pinned
                                ? Colors.amber.shade700
                                : AppColors.primary,
                          ),
                          tooltip: widget.pinned ? 'Desfijar' : 'Fijar',
                          onPressed: widget.onPin,
                        ),
                      ),
                    if (_hovering || !isWeb)
                      FocusTraversalOrder(
                        order: NumericFocusOrder(2.0),
                        child: PopupMenuButton<String>(
                          color: Colors.white,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          icon: Icon(Icons.more_vert, color: Colors.black87),
                          onSelected: widget.onMenu,
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
                      ),
                  ],
                ),
                if (widget.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: -6,
                      children: widget.tags
                          .take(6)
                          .map(
                            (t) => Semantics(
                              label: 'Etiqueta $t',
                              child: ActionChip(
                                label: Text(t),
                                onPressed: () {},
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (isWeb) {
      card = MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: card,
      );
    }
    return card;
  }
}
