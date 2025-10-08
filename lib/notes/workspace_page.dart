import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../editor/markdown_editor.dart';
import '../editor/rich_text_editor.dart';
import '../widgets/tag_input.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../widgets/recording_overlay.dart';
import '../widgets/workspace_widgets.dart';
import '../theme/app_theme.dart';
import '../profile/settings_page.dart';
import '../widgets/folders_panel.dart';
import '../widgets/advanced_search_dialog.dart';
import '../widgets/recent_searches.dart';
import '../widgets/workspace_stats.dart';
import '../services/preferences_service.dart';
import '../services/keyboard_shortcuts_service.dart';
import 'folder_model.dart';
import 'template_picker_dialog.dart';
import 'productivity_dashboard.dart';

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
  List<Map<String, dynamic>> _allNotes = []; // Todas las notas antes de filtrar
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
  
  // Carpetas y filtros
  List<Folder> _folders = [];
  String? _selectedFolderId; // null = "Todas las notas"
  List<String> _filterTags = [];
  DateTimeRange? _filterDateRange;
  SortOption _sortOption = SortOption.dateDesc;
  
  // Nuevas funcionalidades
  bool _compactMode = false;
  bool _showSidebar = true;
  bool _showStats = false;
  bool _showRecentSearches = false;
  
  // Animaciones de transición
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

    _loadPreferences();
    _loadLastAndNotes();
  }
  
  Future<void> _loadPreferences() async {
    final compactMode = await PreferencesService.getCompactMode();
    final selectedFolder = await PreferencesService.getSelectedFolder();
    final filterTags = await PreferencesService.getFilterTags();
    final dateRange = await PreferencesService.getDateRange();
    final sortOption = await PreferencesService.getSortOption();
    
    if (!mounted) return;
    setState(() {
      _compactMode = compactMode;
      _selectedFolderId = selectedFolder;
      _filterTags = filterTags;
      
      if (dateRange != null) {
        try {
          _filterDateRange = DateTimeRange(
            start: DateTime.parse(dateRange['start']!),
            end: DateTime.parse(dateRange['end']!),
          );
        } catch (e) {
          _filterDateRange = null;
        }
      }
      
      if (sortOption != null) {
        try {
          _sortOption = SortOption.values.firstWhere(
            (e) => e.name == sortOption,
            orElse: () => SortOption.dateDesc,
          );
        } catch (e) {
          _sortOption = SortOption.dateDesc;
        }
      }
    });
  }

  Future<void> _loadLastAndNotes() async {
    final last = await _storage.read(key: 'last_note_id');
    await _loadFolders();
    await _loadNotes();
    if (last != null && last.isNotEmpty) {
      // If last exists and present in notes, select it
      final present = _notes.any((n) => n['id'].toString() == last);
      if (present) _select(last);
    }
  }
  
  Future<void> _loadFolders() async {
    try {
      final foldersData = await FirestoreService.instance.listFolders(uid: _uid);
      if (!mounted) return;
      setState(() {
        _folders = foldersData.map((data) => Folder.fromJson(data)).toList();
      });
    } catch (e) {
      debugPrint('Error loading folders: $e');
      if (!mounted) return;
      setState(() => _folders = []);
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
    
    try {
      // Cargar directamente desde Firestore (caché deshabilitado temporalmente por problema de serialización)
      List<Map<String, dynamic>> allNotes = await svc.listNotesSummary(uid: _uid);
      
      if (!mounted) return;
      
      debugPrint('📝 Notas cargadas: ${allNotes.length}');
      
      // Aplicar filtros
      var filteredNotes = List<Map<String, dynamic>>.from(allNotes);
      
      // Filtro por carpeta
      if (_selectedFolderId != null) {
        try {
          final folder = _folders.firstWhere((f) => f.id == _selectedFolderId);
          filteredNotes = filteredNotes.where((note) {
            final noteId = note['id'].toString();
            return folder.noteIds.contains(noteId);
          }).toList();
        } catch (e) {
          // Si no se encuentra la carpeta, mostrar todas las notas
          _selectedFolderId = null;
        }
      }
      
      // Filtro por búsqueda de texto
      final q = _search.text.trim();
      if (q.isNotEmpty) {
        filteredNotes = filteredNotes.where((note) {
          final title = (note['title'] ?? '').toString().toLowerCase();
          final content = (note['content'] ?? '').toString().toLowerCase();
          final searchLower = q.toLowerCase();
          return title.contains(searchLower) || content.contains(searchLower);
        }).toList();
      }
      
      // Filtro por tags
      if (_filterTags.isNotEmpty) {
        filteredNotes = filteredNotes.where((note) {
          final noteTags = List<String>.from((note['tags'] as List?)?.whereType<String>() ?? []);
          return _filterTags.every((tag) => noteTags.contains(tag));
        }).toList();
      }
      
      // Filtro por rango de fechas
      if (_filterDateRange != null) {
        filteredNotes = filteredNotes.where((note) {
          final createdAt = note['createdAt'];
          if (createdAt == null) return false;
          
          DateTime noteDate;
          if (createdAt is DateTime) {
            noteDate = createdAt;
          } else if (createdAt is int) {
            noteDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
          } else {
            return false;
          }
          
          return !noteDate.isBefore(_filterDateRange!.start) &&
                 !noteDate.isAfter(_filterDateRange!.end.add(const Duration(days: 1)));
        }).toList();
      }
      
      // Aplicar ordenamiento
      _sortNotes(filteredNotes);
      
      debugPrint('✅ Notas filtradas: ${filteredNotes.length}');
      
      setState(() {
        _allNotes = allNotes;
        _notes = filteredNotes;
        _loading = false;
      });
      
      if (_selectedId == null && filteredNotes.isNotEmpty) {
        await _select(filteredNotes.first['id'].toString());
      }
    } catch (e) {
      debugPrint('❌ Error cargando notas: $e');
      if (!mounted) return;
      setState(() {
        _allNotes = [];
        _notes = [];
        _loading = false;
      });
    }
  }
  
  void _sortNotes(List<Map<String, dynamic>> notes) {
    switch (_sortOption) {
      case SortOption.dateDesc:
        notes.sort((a, b) {
          final aDate = _getDateTime(a['createdAt']);
          final bDate = _getDateTime(b['createdAt']);
          return bDate.compareTo(aDate);
        });
        break;
      case SortOption.dateAsc:
        notes.sort((a, b) {
          final aDate = _getDateTime(a['createdAt']);
          final bDate = _getDateTime(b['createdAt']);
          return aDate.compareTo(bDate);
        });
        break;
      case SortOption.titleAsc:
        notes.sort((a, b) {
          final aTitle = (a['title'] ?? '').toString().toLowerCase();
          final bTitle = (b['title'] ?? '').toString().toLowerCase();
          return aTitle.compareTo(bTitle);
        });
        break;
      case SortOption.titleDesc:
        notes.sort((a, b) {
          final aTitle = (a['title'] ?? '').toString().toLowerCase();
          final bTitle = (b['title'] ?? '').toString().toLowerCase();
          return bTitle.compareTo(aTitle);
        });
        break;
      case SortOption.updated:
        notes.sort((a, b) {
          final aDate = _getDateTime(a['updatedAt'] ?? a['createdAt']);
          final bDate = _getDateTime(b['updatedAt'] ?? b['createdAt']);
          return bDate.compareTo(aDate);
        });
        break;
    }
  }
  
  DateTime _getDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
  
  List<String> _getAllAvailableTags() {
    final tags = <String>{};
    for (final note in _allNotes) {
      final noteTags = List<String>.from((note['tags'] as List?)?.whereType<String>() ?? []);
      tags.addAll(noteTags);
    }
    return tags.toList()..sort();
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

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }
  
  Future<void> _openAdvancedSearch() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AdvancedSearchDialog(
        availableTags: _getAllAvailableTags(),
        initialSearchQuery: _search.text,
        initialSelectedTags: _filterTags,
        initialDateRange: _filterDateRange,
        initialSortOption: _sortOption,
      ),
    );
    
    if (result != null) {
      final query = result['query'] ?? '';
      
      // Guardar búsqueda en el historial
      if (query.isNotEmpty) {
        await PreferencesService.addRecentSearch(query);
      }
      
      setState(() {
        _search.text = query;
        _filterTags = List<String>.from(result['tags'] ?? []);
        _filterDateRange = result['dateRange'];
        _sortOption = result['sortOption'] ?? SortOption.dateDesc;
      });
      
      // Guardar filtros en preferencias
      await PreferencesService.setFilterTags(_filterTags);
      await PreferencesService.setDateRange(
        _filterDateRange?.start,
        _filterDateRange?.end,
      );
      await PreferencesService.setSortOption(_sortOption.name);
      
      await _loadNotes();
    }
  }
  
  void _onFolderSelected(String? folderId) {
    setState(() => _selectedFolderId = folderId);
    PreferencesService.setSelectedFolder(folderId);
    _loadNotes();
  }
  
  void _toggleCompactMode() {
    setState(() => _compactMode = !_compactMode);
    PreferencesService.setCompactMode(_compactMode);
  }
  
  void _toggleSidebar() {
    setState(() => _showSidebar = !_showSidebar);
  }
  
  void _toggleStats() {
    setState(() {
      _showStats = !_showStats;
      if (_showStats) _showRecentSearches = false;
    });
  }
  
  void _toggleRecentSearches() {
    setState(() {
      _showRecentSearches = !_showRecentSearches;
      if (_showRecentSearches) _showStats = false;
    });
  }
  
  void _focusSearchField() {
    // Focus en el campo de búsqueda (Ctrl+F)
    FocusScope.of(context).requestFocus(FocusNode());
    // Pequeño delay para que se enfoque correctamente
    Future.delayed(const Duration(milliseconds: 100), () {
      _search.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _search.text.length,
      );
    });
  }
  
  void _clearAllFilters() {
    setState(() {
      _search.clear();
      _filterTags = [];
      _filterDateRange = null;
      _sortOption = SortOption.dateDesc;
      _selectedFolderId = null;
    });
    
    PreferencesService.setFilterTags([]);
    PreferencesService.setDateRange(null, null);
    PreferencesService.setSortOption(SortOption.dateDesc.name);
    PreferencesService.setSelectedFolder(null);
    
    _loadNotes();
  }
  
  Future<void> _onNoteDroppedInFolder(String noteId, String folderId) async {
    try {
      await FirestoreService.instance.addNoteToFolder(
        uid: _uid,
        noteId: noteId,
        folderId: folderId,
      );
      
      // Recargar carpetas para actualizar la UI
      await _loadFolders();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nota agregada a la carpeta'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ),
      );
    }
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
    // Limpiar filtros temporalmente para asegurar que se vea la nota nueva
    final tempFilterTags = _filterTags;
    final tempFilterDateRange = _filterDateRange;
    final tempSelectedFolder = _selectedFolderId;
    
    setState(() {
      _filterTags = [];
      _filterDateRange = null;
      _selectedFolderId = null;
    });
    
    final id = await FirestoreService.instance.createNote(uid: _uid, data: {
      'title': '',
      'content': '',
      'tags': <String>[],
      'links': <String>[],
    });
    
    await _loadNotes();
    await _select(id);
    
    // Restaurar filtros después de un breve delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _filterTags = tempFilterTags;
          _filterDateRange = tempFilterDateRange;
          _selectedFolderId = tempSelectedFolder;
        });
      }
    });
  }

  Future<void> _createFromTemplate() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const TemplatePickerDialog(),
    );
    
    if (result != null) {
      // Limpiar filtros temporalmente para asegurar que se vea la nota nueva
      final tempFilterTags = _filterTags;
      final tempFilterDateRange = _filterDateRange;
      final tempSelectedFolder = _selectedFolderId;
      
      setState(() {
        _filterTags = [];
        _filterDateRange = null;
        _selectedFolderId = null;
      });
      
      final id = await FirestoreService.instance.createNote(uid: _uid, data: {
        'title': result['title'] ?? '',
        'content': result['content'] ?? '',
        'tags': result['tags'] ?? <String>[],
        'links': <String>[],
      });
      
      await _loadNotes();
      await _select(id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Nota creada desde plantilla')),
        );
      }
      
      // Restaurar filtros después de un breve delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _filterTags = tempFilterTags;
            _filterDateRange = tempFilterDateRange;
            _selectedFolderId = tempSelectedFolder;
          });
        }
      });
    }
  }

  void _openDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductivityDashboard()),
    );
  }

  Future<void> _insertImage() async {
    final url = await StorageService.pickAndUploadImage(uid: _uid);
    if (url == null) return;
    final sel = _content.selection;
    final i = sel.isValid ? sel.base.offset : _content.text.length;
    final before = _content.text.substring(0, i);
    final after = _content.text.substring(i);
    final insertion = '![]($url)';
    _content.text = '$before$insertion$after';
    _content.selection = TextSelection.collapsed(offset: before.length + insertion.length);
    await _save();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final url = await AudioService.stopAndUpload(uid: _uid);
      setState(() => _isRecording = false);
      if (url != null) {
        final sel = _content.selection;
        final i = sel.isValid ? sel.base.offset : _content.text.length;
        final before = _content.text.substring(0, i);
        final after = _content.text.substring(i);
        final insertion = '[audio]($url)';
        _content.text = '$before$insertion$after';
        _content.selection = TextSelection.collapsed(offset: before.length + insertion.length);
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
    return Shortcuts(
      shortcuts: KeyboardShortcutsService.getShortcuts(),
      child: Actions(
        actions: {
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (_) {
              _focusSearchField();
              return null;
            },
          ),
          NewNoteIntent: CallbackAction<NewNoteIntent>(
            onInvoke: (_) {
              _create();
              return null;
            },
          ),
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (_) {
              _save();
              return null;
            },
          ),
          AdvancedSearchIntent: CallbackAction<AdvancedSearchIntent>(
            onInvoke: (_) {
              _openAdvancedSearch();
              return null;
            },
          ),
          ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
            onInvoke: (_) {
              _toggleSidebar();
              return null;
            },
          ),
          FocusModeIntent: CallbackAction<FocusModeIntent>(
            onInvoke: (_) {
              setState(() => _focusMode = !_focusMode);
              return null;
            },
          ),
          ToggleCompactModeIntent: CallbackAction<ToggleCompactModeIntent>(
            onInvoke: (_) {
              _toggleCompactMode();
              return null;
            },
          ),
        },
        child: LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 800;
          
          if (_selectedId == null && _notes.isEmpty && !_loading) {
            return Scaffold(
              body: EmptyNotesState(onCreate: _create),
            );
          }
          
          return Scaffold(
        appBar: _focusMode
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: WorkspaceHeader(
                  saving: _saving,
                  richMode: _richMode,
                  focusMode: _focusMode,
                  onToggleMode: (mode) => setState(() => _richMode = mode),
                  onToggleFocus: () => setState(() => _focusMode = !_focusMode),
                  onSave: _save,
                  onSettings: _openSettings,
                  saveScale: _saveScale,
                ),
              ),
        drawer: narrow
            ? Drawer(
                backgroundColor: AppColors.surface,
                child: SafeArea(child: _buildNotesList(width: constraints.maxWidth)),
              )
            : null,
        body: Row(
            children: [
              if (!_focusMode && !narrow)
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                    ),
                    child: SafeArea(child: _buildNotesList(width: constraints.maxWidth)),
                  ),
                ),
              Expanded(
                child: Container(
                  color: AppColors.bg,
                  padding: EdgeInsets.all(narrow ? AppColors.space16 : AppColors.space24),
                  child: _selectedId == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppColors.space24),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppColors.radiusXl),
                                  border: Border.all(color: AppColors.borderColor),
                                ),
                                child: Icon(
                                  Icons.edit_note_rounded,
                                  size: 64,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: AppColors.space24),
                              Text(
                                'Selecciona una nota',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: AppColors.space8),
                              Text(
                                'o crea una nueva para comenzar',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : FadeTransition(
                          opacity: _editorFade,
                          child: SlideTransition(
                            position: _editorOffset,
                            child: Stack(
                              children: [
                                SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Título con estilo mejorado
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                          border: Border.all(color: AppColors.borderColor),
                                        ),
                                        child: TextField(
                                          controller: _title,
                                          style: Theme.of(context).textTheme.headlineMedium,
                                          decoration: const InputDecoration(
                                            hintText: 'Título de la nota',
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.all(AppColors.space20),
                                          ),
                                          onChanged: (_) => _debouncedSave(),
                                        ),
                                      ),
                                      const SizedBox(height: AppColors.space20),
                                      
                                      // Editor con contenedor
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                          border: Border.all(color: AppColors.borderColor),
                                        ),
                                        padding: const EdgeInsets.all(AppColors.space16),
                                        child: _richMode
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
                                      ),
                                      const SizedBox(height: AppColors.space20),
                                      
                                      // Tags con diseño mejorado
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                          border: Border.all(color: AppColors.borderColor),
                                        ),
                                        padding: const EdgeInsets.all(AppColors.space16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.label_outline_rounded,
                                                  size: 18,
                                                  color: AppColors.textSecondary,
                                                ),
                                                const SizedBox(width: AppColors.space8),
                                                Text(
                                                  'Etiquetas',
                                                  style: Theme.of(context).textTheme.titleSmall,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: AppColors.space12),
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
                                      const SizedBox(height: AppColors.space48),
                                    ],
                                  ),
                                ),
                                if (_isRecording)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: RecordingOverlay(
                                      isRecording: _isRecording,
                                      onStop: () async {
                                        final url = await AudioService.stopAndUpload(uid: _uid);
                                        if (!mounted) return;
                                        setState(() => _isRecording = false);
                                        if (url != null) {
                                          final sel = _content.selection;
                                          final i = sel.isValid ? sel.base.offset : _content.text.length;
                                          final newText = '${_content.text.substring(0, i)}[audio]($url)${_content.text.substring(i)}';
                                          setState(() => _content.text = newText);
                                          await _save();
                                        }
                                      },
                                      onCancel: () async {
                                        if (AudioService.supportsDiscard) await AudioService.stopRecordingAndDiscard();
                                        if (!mounted) return;
                                        setState(() => _isRecording = false);
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        floatingActionButton: _selectedId != null
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: narrow ? AppColors.space16 : AppColors.space24,
                  right: narrow ? AppColors.space16 : AppColors.space24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Dashboard button
                    FloatingActionButton.small(
                      heroTag: 'dashboard',
                      onPressed: _openDashboard,
                      tooltip: 'Dashboard de Productividad',
                      backgroundColor: const Color(0xFF8B5CF6),
                      child: const Icon(Icons.analytics_rounded, size: 20),
                    ),
                    const SizedBox(height: AppColors.space8),
                    
                    // Botón de plantilla
                    FloatingActionButton.small(
                      heroTag: 'template',
                      onPressed: _createFromTemplate,
                      tooltip: 'Crear desde Plantilla',
                      backgroundColor: const Color(0xFFF59E0B),
                      child: const Icon(Icons.description_rounded, size: 20),
                    ),
                    const SizedBox(height: AppColors.space12),
                    
                    // Botón de nueva nota
                    FloatingActionButton.extended(
                      heroTag: 'new_note',
                      onPressed: _create,
                      icon: const Icon(Icons.note_add_rounded),
                      label: const Text('Nueva'),
                      backgroundColor: AppColors.primary,
                    ),
                    const SizedBox(height: AppColors.space12),
                    
                    // Botones de multimedia
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Imagen
                        FloatingActionButton.small(
                          heroTag: 'add_image',
                          onPressed: _insertImage,
                          tooltip: 'Insertar imagen',
                          backgroundColor: AppColors.surfaceLight,
                          foregroundColor: AppColors.textPrimary,
                          child: const Icon(Icons.image_outlined, size: 20),
                        ),
                        const SizedBox(width: AppColors.space8),
                        
                        // Audio
                        FloatingActionButton.small(
                          heroTag: 'add_audio',
                          onPressed: _toggleRecording,
                          tooltip: _isRecording ? 'Detener grabación' : 'Grabar audio',
                          backgroundColor: _isRecording ? AppColors.danger : AppColors.surfaceLight,
                          foregroundColor: _isRecording ? Colors.white : AppColors.textPrimary,
                          child: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_outlined,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : null,
          );
        }),
      ),
    );
  }

  Widget _buildNotesList({required double width}) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // Barra de búsqueda moderna
          Container(
            padding: const EdgeInsets.all(AppColors.space16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          hintText: 'Buscar notas...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _search.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _search.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: AppColors.space8),
                    // Botón de búsqueda avanzada
                    IconButton.filled(
                      onPressed: _openAdvancedSearch,
                      icon: Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: (_filterTags.isNotEmpty || _filterDateRange != null) 
                            ? AppColors.primary 
                            : AppColors.textSecondary,
                      ),
                      tooltip: 'Búsqueda avanzada',
                      style: IconButton.styleFrom(
                        backgroundColor: (_filterTags.isNotEmpty || _filterDateRange != null)
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surfaceLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppColors.space12),
                
                // Fila de acciones
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _create,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Nueva'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppColors.space16,
                            vertical: AppColors.space12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppColors.space8),
                    // Botón de estadísticas
                    IconButton(
                      onPressed: _toggleStats,
                      icon: Icon(
                        _showStats ? Icons.analytics : Icons.analytics_outlined,
                        size: 20,
                      ),
                      tooltip: 'Estadísticas',
                      style: IconButton.styleFrom(
                        backgroundColor: _showStats 
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surfaceLight,
                        foregroundColor: _showStats 
                            ? AppColors.primary 
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppColors.space4),
                    // Botón de búsquedas recientes
                    IconButton(
                      onPressed: _toggleRecentSearches,
                      icon: Icon(
                        _showRecentSearches ? Icons.history : Icons.history_outlined,
                        size: 20,
                      ),
                      tooltip: 'Búsquedas recientes',
                      style: IconButton.styleFrom(
                        backgroundColor: _showRecentSearches 
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surfaceLight,
                        foregroundColor: _showRecentSearches 
                            ? AppColors.primary 
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppColors.space4),
                    // Botón de modo compacto
                    IconButton(
                      onPressed: _toggleCompactMode,
                      icon: Icon(
                        _compactMode ? Icons.density_small : Icons.density_medium,
                        size: 20,
                      ),
                      tooltip: _compactMode ? 'Modo expandido' : 'Modo compacto',
                      style: IconButton.styleFrom(
                        backgroundColor: _compactMode 
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surfaceLight,
                        foregroundColor: _compactMode 
                            ? AppColors.primary 
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                
                // Indicador de filtros activos
                if (_filterTags.isNotEmpty || _filterDateRange != null || _selectedFolderId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppColors.space12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_notes.length} resultado(s)',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearAllFilters,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Limpiar filtros',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Widget de estadísticas
          if (_showStats)
            Padding(
              padding: const EdgeInsets.all(AppColors.space12),
              child: WorkspaceStats(
                notes: _allNotes,
                folders: _folders.length,
              ),
            ),
          
          // Widget de búsquedas recientes
          if (_showRecentSearches)
            Padding(
              padding: const EdgeInsets.all(AppColors.space12),
              child: RecentSearches(
                onSearchSelected: (query) {
                  setState(() {
                    _search.text = query;
                    _showRecentSearches = false;
                  });
                  _loadNotes();
                },
              ),
            ),
          
          // Panel de carpetas
          if (_folders.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
              ),
              child: FoldersPanel(
                folders: _folders,
                selectedFolderId: _selectedFolderId,
                onFolderSelected: _onFolderSelected,
                onFolderCreated: (folder) async {
                  try {
                    await FirestoreService.instance.createFolder(
                      uid: _uid,
                      data: folder.toJson(),
                    );
                    await _loadFolders();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al crear carpeta: $e'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                },
                onFolderUpdated: (folder) async {
                  try {
                    await FirestoreService.instance.updateFolder(
                      uid: _uid,
                      folderId: folder.id,
                      data: folder.toJson(),
                    );
                    await _loadFolders();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al actualizar carpeta: $e'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                },
                onFolderDeleted: (folderId) async {
                  try {
                    await FirestoreService.instance.deleteFolder(
                      uid: _uid,
                      folderId: folderId,
                    );
                    if (_selectedFolderId == folderId) {
                      setState(() => _selectedFolderId = null);
                    }
                    await _loadFolders();
                    await _loadNotes();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al eliminar carpeta: $e'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                },
                onNoteDropped: _onNoteDroppedInFolder,
              ),
            ),
          
          // Lista de notas con tarjetas modernas
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _notes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppColors.space32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.note_outlined,
                                size: 48,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: AppColors.space16),
                              Text(
                                'No hay notas',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppColors.space8),
                              Text(
                                'Crea tu primera nota',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppColors.space12),
                        itemCount: _notes.length,
                        itemBuilder: (context, i) {
                          final note = _notes[i];
                          final id = note['id'].toString();
                          return NotesSidebarCard(
                            note: note,
                            isSelected: id == _selectedId,
                            onTap: () => _select(id),
                            onPin: () async {
                              await FirestoreService.instance.setPinned(
                                uid: _uid,
                                noteId: id,
                                pinned: !(note['pinned'] == true),
                              );
                              await _loadNotes();
                            },
                            onDelete: () => _delete(id),
                            enableDrag: true,
                            compact: _compactMode,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _debouncedSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }
}
