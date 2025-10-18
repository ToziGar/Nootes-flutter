import 'folder_model.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../pages/sync_debug_page.dart';
import '../widgets/enhanced_note_editor.dart';
import '../services/firestore_service.dart';
import '../services/field_timestamp_helper.dart';
import '../services/export_import_service.dart';
import '../services/toast_service.dart';
// Markdown and legacy rich editors removed in favor of Quill WYSIWYG
import '../widgets/quill_editor_widget.dart';
import '../widgets/tag_input.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../widgets/recording_overlay.dart';
import '../widgets/workspace_widgets.dart';
import '../widgets/enhanced_context_menu.dart';
import '../widgets/note_autocomplete_overlay.dart' show NoteSuggestion;
import './template_picker_dialog.dart';
import './productivity_dashboard.dart';
import './folder_dialog.dart';
import '../theme/app_theme.dart';
import '../utils/debug.dart';
import '../pages/app_shell.dart';
import '../profile/settings_page.dart';
import '../widgets/backlinks_panel.dart';
import '../widgets/unified_context_menu.dart';
import '../widgets/advanced_search_dialog.dart';
import '../widgets/recent_searches.dart';
import '../widgets/workspace_stats.dart';
import '../utils/error_message_mapper.dart';
import '../widgets/unified_fab_menu.dart';
import '../services/preferences_service.dart';
import '../services/keyboard_shortcuts_service.dart';
import '../services/sharing_service.dart';
import '../widgets/share_dialog.dart';
import '../theme/icon_registry.dart';

// ignore_for_file: unused_element, unused_local_variable, use_super_parameters

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage>
    with TickerProviderStateMixin {
  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Developer-only quick access to Sync Debug
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppColors.space12),
              child: ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Sync Debug (dev)'),
                onTap: () {
                  final uid = AuthService.instance.currentUser?.uid;
                  if (uid != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SyncDebugPage(uid: uid),
                      fullscreenDialog: true,
                    ));
                  } else {
                    ToastService.error('No user signed in');
                  }
                },
              ),
            ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              // overflow: TextOverflow.ellipsis, // For selectable text, ellipsis is not supported
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final days = [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ];
      return '${days[date.weekday - 1]} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  // Editor and search state
  final TextEditingController _search = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  List<String> _tags = [];
  String _richJson = '';
  bool _saving = false;
  bool _loading = false;
  // Notes state
  List<Map<String, dynamic>> _allNotes = [];
  List<Map<String, dynamic>> _notes = [];
  // (Placeholders removed; real implementations appear later in this file.)
  final _storage = const FlutterSecureStorage();
  bool _isRecording = false;
  late final AnimationController _editorCtrl;
  late final Animation<double> _editorFade;
  late final Animation<Offset> _editorOffset;
  // Filters and view state
  bool _compactMode = false;
  String? _selectedFolderId;
  List<String> _filterTags = [];
  DateTimeRange? _filterDateRange;
  SortOption _sortOption = SortOption.dateDesc;
  // Save pulse animation
  late final AnimationController _savePulseCtrl;
  late final Animation<double> _saveScale;
  // Current selection
  String? _selectedId;
  // Folders state
  List<Folder> _folders = [];
  // Sidebar panels
  bool _showSidebar = true;
  bool _showStats = false;
  bool _showRecentSearches = false;
  bool _showBacklinks = false;
  // Debounce for search/save
  Timer? _debounce;
  // Expanded folders tracking
  final Set<String> _expandedFolders = {};
  // Current user id helper
  String getUid() {
    return AuthService.instance.currentUser!.uid;
  }

  Future<void> _showCreateFolderDialog() async {
    final created = await showDialog<Folder?>(
      context: context,
      builder: (context) => const FolderDialog(),
    );
    if (created != null) {
      final data = created.toJson();
      // Ensure structure aligns with Firestore expectations
      await FirestoreService.instance.createFolder(
        uid: getUid(),
        data: {
          'name': data['name'],
          'icon': _iconToString(created.icon),
          'emoji': created.emoji,
          'color': created.color.toARGB32(),
          'noteIds': created.noteIds,
          'createdAt': (data['createdAt'] as DateTime).toIso8601String(),
          'updatedAt': (data['updatedAt'] as DateTime).toIso8601String(),
          'order': data['order'] ?? 0,
        },
      );
      await _loadFolders();
    }
  }

  @override
  void initState() {
    super.initState();
    _editorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _editorFade = CurvedAnimation(parent: _editorCtrl, curve: Curves.easeInOut);
    _editorOffset = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(_editorCtrl);
    _savePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _saveScale = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _savePulseCtrl, curve: Curves.easeOut));
    // Load preferences and initial data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadPreferences();
      await _loadFolders();
      await _loadNotes();
      await _loadLastAndNotes();
    });
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
      final foldersData = await FirestoreService.instance.listFolders(
        uid: getUid(),
      );
  logDebug('📁 Carpetas cargadas: ${foldersData.length}');
      if (!mounted) return;

      // Eliminar duplicados por ID lógico de carpeta
      final seen = <String>{};
      final uniqueFolders = <Folder>[];

      for (var data in foldersData) {
        // Usar folderId si existe, sino usar id
        final logicalId = data['folderId']?.toString() ?? data['id'].toString();
        if (!seen.contains(logicalId)) {
          seen.add(logicalId);
          // Crear folder usando los datos originales del documento. Usamos
          // `logicalId` únicamente para detectar duplicados, pero no
          // sobrescribimos el campo 'id' ni 'docId' para mantener el
          // Document ID que Firestore usa para operaciones como delete.
          final folder = Folder.fromJson(Map<String, dynamic>.from(data));
          uniqueFolders.add(folder);
        } else {
          logDebug('⚠️ Carpeta duplicada ignorada: ${data['name']} ($logicalId)');
        }
      }

      if (mounted) {
        setState(() {
          _folders = uniqueFolders;
          logDebug('✅ Carpetas únicas: ${_folders.length}');
          for (var folder in _folders) {
            logDebug('  - ${folder.name} (${folder.noteIds.length} notas)');
          }
        });
      }

      // 🧹 LIMPIEZA AUTOMÁTICA: Verificar y limpiar referencias a notas inexistentes
      await _cleanOrphanedNoteReferences();

      // 🧹 LIMPIEZA ADICIONAL: (Desactivado) Eliminación de duplicados en Firestore
      // Temporalmente desactivado para evitar borrar carpetas principales por colisiones
      // await _cleanDuplicateFoldersInFirestore();
    } catch (e) {
  logDebug('❌ Error loading folders: $e');
      if (!mounted) return;
      if (mounted) setState(() => _folders = []);
    }
  }

  /// Limpia referencias a notas que ya no existen en las carpetas
  Future<void> _cleanOrphanedNoteReferences() async {
    try {
      // Obtener todos los IDs de notas que existen realmente
      final allNotes = await FirestoreService.instance.listNotesSummary(
        uid: getUid(),
      );
      final existingNoteIds = allNotes.map((n) => n['id'].toString()).toSet();

      // Revisar cada carpeta
      for (var folder in _folders) {
        // Encontrar notas "fantasma" (que están en noteIds pero no existen)
        final orphanedNotes = folder.noteIds
            .where((noteId) => !existingNoteIds.contains(noteId))
            .toList();

        if (orphanedNotes.isNotEmpty) {
          logDebug('🧹 Limpiando ${orphanedNotes.length} referencias huérfanas en carpeta "${folder.name}"');

          // Crear lista limpia sin las notas huérfanas
          final cleanedNoteIds = folder.noteIds
              .where((noteId) => existingNoteIds.contains(noteId))
              .toList();

          // Actualizar la carpeta en Firestore
          await FirestoreService.instance.updateFolder(
            uid: getUid(),
            folderId: folder.id,
            data: {'noteIds': cleanedNoteIds},
          );

          // Actualizar el objeto local
          folder.noteIds.clear();
          folder.noteIds.addAll(cleanedNoteIds);

          logDebug(
            '✅ Carpeta "${folder.name}" limpiada: ${cleanedNoteIds.length} notas válidas',
          );
        }
      }

      // Actualizar UI si se hicieron cambios
      if (mounted) {
        setState(() {
          // UI update after cleaning orphaned notes
          for (var folder in _folders) {
            logDebug('  - ${folder.name} (${folder.noteIds.length} notas)');
          }
        });
      }
    } catch (e) {
  logDebug('⚠️ Error al limpiar referencias huérfanas: $e');
    }
  }

  /// Verifica la integridad de las carpetas después de operaciones críticas
  Future<void> _verifyFolderIntegrity(String deletedFolderId) async {
    try {
  logDebug('🔍 Verificando integridad de carpetas...');

      // Obtener carpetas desde Firestore para comparar (comparar docId)
      final remoteFolders = await FirestoreService.instance.listFolders(
        uid: getUid(),
      );
      final remoteDocIds = remoteFolders
          .map((f) => (f['docId'] ?? f['id']).toString())
          .toSet();

      // Verificar que la carpeta eliminada NO está en Firestore (por docId)
      if (remoteDocIds.contains(deletedFolderId)) {
        logDebug(
          '❌ ERROR: La carpeta (docId) $deletedFolderId todavía existe en Firestore',
        );
        throw Exception('La carpeta no se eliminó correctamente de Firestore');
      }

      // Verificar que el estado local coincide con Firestore (mapear local a docId)
      final localDocIds = _folders
          .map((f) => f.docId.isNotEmpty ? f.docId : f.id)
          .toSet();
      final phantomFolders = localDocIds.difference(remoteDocIds);

      if (phantomFolders.isNotEmpty) {
        logDebug(
          '👻 Carpetas fantasma detectadas en estado local: $phantomFolders',
        );
        // Limpiar carpetas fantasma del estado local
        setState(() {
          _folders.removeWhere((f) => phantomFolders.contains(f.id));
        });
  logDebug('✅ Carpetas fantasma eliminadas del estado local');
      }

  logDebug('✅ Verificación de integridad completada');
    } catch (e) {
      logDebug('⚠️ Error en verificación de integridad: $e');
      // En caso de error, forzar recarga completa
      await _loadFolders();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _title.dispose();
    _content.dispose();
    _debounce?.cancel();
  _editorCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final svc = FirestoreService.instance;

    try {
      // Modo especial: secciones "Compartidas"
      if (_selectedFolderId == '__SHARED_WITH_ME__') {
        // Notas compartidas conmigo y aceptadas
        final sharedNotes = await SharingService().getSharedNotes();
        if (!mounted) return;
        setState(() {
          _allNotes = sharedNotes;
          _notes = sharedNotes;
          _loading = false;
        });
        return;
      } else if (_selectedFolderId == '__SHARED_BY_ME__') {
        // Notas que yo he compartido
        final sharedByMe = await SharingService().getSharedByMe(
          type: SharedItemType.note,
        );
        final sharedIds = sharedByMe.map((s) => s.itemId).toSet();
        // Cargar mis notas y filtrar por las compartidas
        List<Map<String, dynamic>> myNotes = await svc.listNotesSummary(
          uid: getUid(),
        );
        final filtered = myNotes
            .where((n) => sharedIds.contains(n['id'].toString()))
            .toList();
        if (!mounted) return;
        setState(() {
          _allNotes = filtered;
          _notes = filtered;
          _loading = false;
        });
        return;
      }
      // Cargar notas propias (caché deshabilitado temporalmente por problema de serialización)
      List<Map<String, dynamic>> allNotes = await svc.listNotesSummary(
        uid: getUid(),
      );

      if (!mounted) return;

  logDebug('📝 Notas cargadas: ${allNotes.length}');

      // Aplicar filtros
      var filteredNotes = List<Map<String, dynamic>>.from(allNotes);

      // Filtro por carpeta (excluye virtuales)
      if (_selectedFolderId != null &&
          _selectedFolderId != '__SHARED_WITH_ME__' &&
          _selectedFolderId != '__SHARED_BY_ME__') {
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
          final noteTags = List<String>.from(
            (note['tags'] as List?)?.whereType<String>() ?? [],
          );
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
              !noteDate.isAfter(
                _filterDateRange!.end.add(const Duration(days: 1)),
              );
        }).toList();
      }

      // Aplicar ordenamiento
      _sortNotes(filteredNotes);

      logDebug('✅ Notas filtradas: ${filteredNotes.length}');

      setState(() {
        _allNotes = allNotes;
        _notes = filteredNotes;
        _loading = false;
      });

      if (_selectedId == null && filteredNotes.isNotEmpty) {
        await _select(filteredNotes.first['id'].toString());
      }
    } catch (e) {
      logDebug('❌ Error cargando notas: $e');
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
      final noteTags = List<String>.from(
        (note['tags'] as List?)?.whereType<String>() ?? [],
      );
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
    // Si la nota es compartida conmigo, obtenerla desde el propietario
    String ownerUid = getUid();
    try {
      final Map<String, dynamic> maybe = _notes.firstWhere(
        (n) => (n['id']?.toString() ?? '') == id,
        orElse: () => <String, dynamic>{},
      );
      final owner = (maybe['ownerId'] as String?) ?? '';
      if (maybe['isShared'] == true && owner.isNotEmpty) {
        ownerUid = owner;
      }
    } catch (_) {}
    final n = await FirestoreService.instance.getNote(
      uid: ownerUid,
      noteId: id,
    );
    if (!mounted) return;
    setState(() {
      _title.text = (n?['title']?.toString() ?? '');
      _content.text = (n?['content']?.toString() ?? '');
      _tags = List<String>.from(
        (n?['tags'] as List?)?.whereType<String>() ?? const [],
      );
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
    final appShell = AppShell.of(context);
    if (appShell != null) {
      appShell.navigateToSettings();
    }
    // Si no hay AppShell, no abrir settings como nueva ruta para evitar inconsistencias.
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

  Widget _buildVirtualSharedTile({
    required String id,
    required String name,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedFolderId == id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(
        horizontal: AppColors.space8,
        vertical: AppColors.space4,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: isSelected
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            setState(() => _selectedFolderId = id);
            await PreferencesService.setSelectedFolder(id);
            _loadNotes();
          },
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppColors.space12,
              vertical: AppColors.space12,
            ),
            child: Row(
              children: [
                _loading
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
                                (_selectedFolderId == '__SHARED_WITH_ME__' ||
                                        _selectedFolderId == '__SHARED_BY_ME__')
                                    ? 'No hay notas compartidas'
                                    : 'No hay notas',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                _selectedFolderId == '__SHARED_WITH_ME__'
                                    ? 'Cuando alguien comparta contigo, aparecerán aquí'
                                    : _selectedFolderId == '__SHARED_BY_ME__'
                                    ? 'Aún no has compartido notas'
                                    : 'Crea tu primera nota',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    : /* Aquí iría la lista de notas/folders */ Container(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedId == null || !mounted) return;
    // small pulse feedback
    _savePulseCtrl.forward().then((_) => _savePulseCtrl.reverse());

    // NO usar setState aquí para evitar perder el foco del editor
    _saving = true;

    try {
      Map<String, dynamic> data = {
        'title': _title.text,
        'content': _content.text,
        'tags': _tags,
      };
      if (_richJson.isNotEmpty) {
        data['rich'] = _richJson;
      }
      try {
        data = attachFieldTimestamps(data);
      } catch (_) {}
      await FirestoreService.instance.updateNote(
        uid: getUid(),
        noteId: _selectedId!,
        data: data,
      );

      // 🔥 ACTUALIZACIÓN INSTANTÁNEA: Actualizar la nota en la lista local sin recargar desde Firestore
      final noteIndex = _allNotes.indexWhere((n) => n['id'] == _selectedId);
      if (noteIndex >= 0) {
        _allNotes[noteIndex] = {
          ..._allNotes[noteIndex],
          'title': _title.text,
          'tags': _tags,
          'updatedAt': DateTime.now(),
        };

        // Reaplicar filtros para actualizar _notes
        var filteredNotes = List<Map<String, dynamic>>.from(_allNotes);

        // Filtro por carpeta
        if (_selectedFolderId != null) {
          try {
            final folder = _folders.firstWhere(
              (f) => f.id == _selectedFolderId,
            );
            filteredNotes = filteredNotes.where((note) {
              final noteId = note['id'].toString();
              return folder.noteIds.contains(noteId);
            }).toList();
          } catch (e) {
            _selectedFolderId = null;
          }
        }

        // Filtro por búsqueda
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
            final noteTags = List<String>.from(
              (note['tags'] as List?)?.whereType<String>() ?? [],
            );
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
                !noteDate.isAfter(
                  _filterDateRange!.end.add(const Duration(days: 1)),
                );
          }).toList();
        }

        _sortNotes(filteredNotes);

        if (mounted) {
          setState(() {
            _notes = filteredNotes;
          });
        }
      }
    } finally {
      _saving = false;
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

    // Pedir título obligatorio antes de crear
    final title = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Nueva nota'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Título de la nota',
              hintText: 'Escribe un título',
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
    if (title == null || title.isEmpty) {
      // Restaurar filtros si cancela o deja vacío
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _filterTags = tempFilterTags;
            _filterDateRange = tempFilterDateRange;
            _selectedFolderId = tempSelectedFolder;
          });
        }
      });
      if (title != null && title.isEmpty) {
        ToastService.warning('El título no puede estar vacío');
      }
      return;
    }

    final id = await FirestoreService.instance.createNote(
      uid: getUid(),
      data: {
        'title': title,
        'content': '',
        'tags': <String>[],
        'links': <String>[],
        'icon': '📝',
        'iconColor': const Color(
          0xFF6B7280,
        ).toARGB32(), // Color gris independiente
      },
    );

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

      final id = await FirestoreService.instance.createNote(
        uid: getUid(),
        data: {
          'title': result['title'] ?? '',
          'content': result['content'] ?? '',
          'tags': result['tags'] ?? <String>[],
          'links': <String>[],
          'icon': '📝',
          'iconColor': const Color(
            0xFF6B7280,
          ).toARGB32(), // Color gris independiente
        },
      );

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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProductivityDashboard()));
  }

  Future<void> _insertImage() async {
    final url = await StorageService.pickAndUploadImage(uid: getUid());
    if (url == null) return;
    final sel = _content.selection;
    final i = sel.isValid ? sel.base.offset : _content.text.length;
    final before = _content.text.substring(0, i);
    final after = _content.text.substring(i);
    final insertion = '![]($url)';
    _content.text = '$before$insertion$after';
    _content.selection = TextSelection.collapsed(
      offset: before.length + insertion.length,
    );
    await _save();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final url = await AudioService.stopAndUpload(uid: getUid());
      setState(() => _isRecording = false);
      if (url != null) {
        final sel = _content.selection;
        final i = sel.isValid ? sel.base.offset : _content.text.length;
        final before = _content.text.substring(0, i);
        final after = _content.text.substring(i);
        final insertion = '[audio]($url)';
        _content.text = '$before$insertion$after';
        _content.selection = TextSelection.collapsed(
          offset: before.length + insertion.length,
        );
        await _save();
      }
    } else {
      final path = await AudioService.startRecording();
      if (path == null) {
        ToastService.error('No permission to record audio');
        return;
      }
      setState(() => _isRecording = true);
      ToastService.info('Grabando... pulsa otra vez para detener');
    }
  }

  Future<void> _delete(String id) async {
    await FirestoreService.instance.deleteNote(uid: getUid(), noteId: id);
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

  Future<void> _onNoteDroppedInFolder(String noteId, String folderId) async {
    try {
      await FirestoreService.instance.addNoteToFolder(
        uid: getUid(),
        folderId: folderId,
        noteId: noteId,
      );
      await _loadFolders();
      await _loadNotes();
      ToastService.success('Nota añadida a la carpeta');
    } catch (e) {
  logDebug('⚠️ Error añadiendo nota a carpeta: $e');
      ToastService.error('Error al añadir nota a carpeta');
    }
  }

  // Construir carpeta desplegable estilo árbol
  Widget _buildFolderCard(Folder folder, int noteCount) {
    final isExpanded = _expandedFolders.contains(folder.id);
    final notesInFolder = _notes
        .where((n) => folder.noteIds.contains(n['id'].toString()))
        .toList();

    return DragTarget<String>(
      key: ValueKey('folder_${folder.id}'), // Key única para evitar duplicados
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) =>
          _onNoteDroppedInFolder(details.data, folder.id),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carpeta principal
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: isHovering
                    ? AppColors.success.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                border: isHovering
                    ? Border.all(color: AppColors.success, width: 2)
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: EnhancedContextMenuRegion(
                  actions: (context) => EnhancedContextMenuBuilder.folderMenu(
                    noteCount: folder.noteIds.length,
                  ),
                  onActionSelected: (action) =>
                      _handleEnhancedContextMenuAction(
                        action.value,
                        context: context,
                        folderId: folder.id,
                      ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedFolders.remove(folder.id);
                        } else {
                          _expandedFolders.add(folder.id);
                        }
                      });
                    },
                    onLongPress: () => _confirmDeleteFolder(folder),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppColors.space8,
                        vertical: AppColors.space8,
                      ),
                      child: Row(
                        children: [
                          // Flecha expandir/colapsar
                          Semantics(
                            label: isExpanded
                                ? 'Colapsar carpeta ${folder.name}'
                                : 'Expandir carpeta ${folder.name}',
                            button: true,
                            child: Icon(
                              isExpanded
                                  ? Icons.arrow_drop_down
                                  : Icons.arrow_right,
                              size: 24,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Icono de carpeta o emoji
                          if (folder.emoji != null)
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              child: Text(
                                folder.emoji!,
                                style: const TextStyle(fontSize: 16),
                              ),
                            )
                          else
                            Icon(
                              isExpanded
                                  ? Icons.folder_open_rounded
                                  : Icons.folder_rounded,
                              color: folder.color,
                              size: 18,
                            ),
                          const SizedBox(width: AppColors.space8),

                          // Nombre de carpeta
                          Expanded(
                            child: Semantics(
                              label: 'Nombre de carpeta: ${folder.name}',
                              readOnly: true,
                              child: Text(
                                folder.name,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),

                          // Contador de notas
                          if (noteCount > 0)
                            Semantics(
                              label: 'Notas en carpeta: $noteCount',
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: folder.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$noteCount',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                          // Botón editar
                          Semantics(
                            label: 'Editar carpeta ${folder.name}',
                            button: true,
                            child: IconButton(
                              icon: Icon(
                                Icons.brush_rounded,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                              onPressed: () => _showFolderIconPicker(folder.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Notas dentro de la carpeta (cuando está expandida)
            if (isExpanded && notesInFolder.isNotEmpty)
              ...notesInFolder.map((note) {
                final id = note['id'].toString();
                return EnhancedContextMenuRegion(
                  key: ValueKey('folder_note_${folder.id}_$id'),
                  actions: (context) => EnhancedContextMenuBuilder.noteMenu(
                    isInFolder: true,
                    isPinned: note['pinned'] == true,
                    isFavorite: note['favorite'] == true,
                    isArchived: note['archived'] == true,
                    hasIcon: note['icon'] != null,
                  ),
                  onActionSelected: (action) =>
                      _handleEnhancedContextMenuAction(
                        action.value,
                        context: context,
                        noteId: id,
                        folderId: folder.id,
                      ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 32, bottom: 2),
                    child: NotesSidebarCard(
                      note: note,
                      noteId: id,
                      isSelected: id == _selectedId,
                      onTap: () => _select(id),
                      onPin: () async {
                        await FirestoreService.instance.setPinned(
                          uid: getUid(),
                          noteId: id,
                          pinned: !(note['pinned'] == true),
                        );
                        _updateNoteInList(id, {
                          'pinned': !(note['pinned'] == true),
                        });
                      },
                      onDelete: () => _delete(id),
                      onSetIcon: () => _showNoteIconPicker(
                        noteId: id,
                        initialIcon: note['icon']?.toString(),
                        initialColor: note['iconColor'] is int
                            ? Color(note['iconColor'])
                            : null,
                      ),
                      onClearIcon: () async => _clearNoteIcon(id),
                      enableDrag: true,
                      compact: true,
                    ),
                  ),
                );
              }),

            // Mensaje si la carpeta está vacía y expandida
            if (isExpanded && notesInFolder.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 4, bottom: 8),
                child: Text(
                  'Arrastra notas aquí',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // All context menu and note helper methods are now inside the class body

  // Manejador mejorado de acciones del menú contextual
  Future<void> _handleEnhancedContextMenuAction(
    String? action, {
    required BuildContext context,
    String? noteId,
    String? folderId,
  }) async {
    if (action == null) return;

    // Capture messenger early to avoid using BuildContext after awaits.
    final messenger = ScaffoldMessenger.of(context);

    try {
      switch (action) {
        case 'open':
        case 'edit':
          if (noteId != null) await _select(noteId);
          break;
        case 'rename':
          if (noteId != null) {
            await _showRenameNoteDialog(noteId);
          } else if (folderId != null) {
            final folder = _folders.firstWhere((f) => f.id == folderId);
            await _showRenameFolderDialog(folder);
          }
          break;
        case 'duplicate':
          if (noteId != null) await _duplicateNote(noteId);
          break;
        case 'delete':
          if (noteId != null) {
            await _delete(noteId);
          } else if (folderId != null) {
            final folder = _folders.firstWhere((f) => f.id == folderId);
            await _confirmDeleteFolder(folder);
          }
          break;

        // Note actions - Pin/Favorite/Archive
        case 'togglePin':
          if (noteId != null) {
            final note = _allNotes.firstWhere(
              (n) => n['id'].toString() == noteId,
            );
            await _togglePinNote(noteId, !(note['pinned'] == true));
          }
          break;
        case 'toggleFavorite':
          if (noteId != null) {
            final note = _allNotes.firstWhere(
              (n) => n['id'].toString() == noteId,
            );
            await _toggleFavoriteNote(noteId, !(note['favorite'] == true));
          }
          break;
        case 'toggleArchive':
          if (noteId != null) {
            final note = _allNotes.firstWhere(
              (n) => n['id'].toString() == noteId,
            );
            await _toggleArchiveNote(noteId, !(note['archived'] == true));
          }
          break;

        // Note actions - Tags/Icon
        case 'addTags':
          if (noteId != null) await _showAddTagsDialog(noteId);
          break;
        case 'changeNoteIcon':
          if (noteId != null) {
            final note = _allNotes.firstWhere(
              (n) => n['id'].toString() == noteId,
            );
            await _showNoteIconPicker(
              noteId: noteId,
              initialIcon: note['icon']?.toString(),
              initialColor: note['iconColor'] is int
                  ? Color(note['iconColor'])
                  : null,
            );
          }
          break;
        case 'clearNoteIcon':
          if (noteId != null) await _clearNoteIcon(noteId);
          break;

        // Note actions - Share/Export/Link
        case 'export':
          if (noteId != null) {
            await _exportSingleNote(noteId);
          } else if (folderId != null) {
            await _exportFolder(folderId);
          }
          break;
        case 'share':
          if (noteId != null) {
            await _shareNote(noteId);
          } else if (folderId != null) {
            await _shareFolder(folderId);
          }
          break;
        case 'generatePublicLink':
          if (noteId != null) await _generatePublicLink(noteId);
          break;
        case 'copyLink':
          if (noteId != null) {
            await _copyNoteLink(noteId);
          } else if (folderId != null) {
            _copyFolderLink(folderId);
          }
          break;

        // Note actions - Folder management
        case 'moveToFolder':
          if (noteId != null) await _moveNoteToFolderDialog(noteId);
          break;
        case 'removeFromFolder':
          if (noteId != null && folderId != null) {
            await FirestoreService.instance.removeNoteFromFolder(
              uid: getUid(),
              folderId: folderId,
              noteId: noteId,
            );
            await _loadFolders();
            await _loadNotes();
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Nota quitada de la carpeta'),
                backgroundColor: AppColors.success,
              ),
            );
          }
          break;

        // Note/Folder info
        case 'properties':
          if (noteId != null) {
            _showNoteProperties(noteId);
          }
          break;
        case 'history':
          if (noteId != null) _showNoteHistory(noteId);
          break;

        // Folder actions
        case 'editFolder':
          if (folderId != null) {
            final folder = _folders.firstWhere((f) => f.id == folderId);
            await _showEditFolderDialog(folder);
          }
          break;
        case 'newSubfolder':
          if (folderId != null) {
            await _showCreateFolderDialog();
          }
          break;
        case 'changeIcon':
          if (folderId != null) await _showFolderIconPicker(folderId);
          break;

        // Workspace actions
        case 'newNote':
          await _create();
          break;
        case 'newFolder':
          await _showCreateFolderDialog();
          break;
        case 'newFromTemplate':
          await _createFromTemplate();
          break;
        case 'refresh':
          await _loadNotes();
          break;
        case 'openDashboard':
          _openDashboard();
          break;

        default:
          logDebug('⚠️ Acción no implementada: $action');
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  // Duplicar nota (nueva función)
  Future<void> _duplicateNote(String noteId) async {
    try {
      final notes = await FirestoreService.instance.listNotes(uid: getUid());
      final originalNote = notes.firstWhere(
        (n) => n['id'].toString() == noteId,
      );

      await FirestoreService.instance.createNote(
        uid: getUid(),
        data: {
          'title': '${originalNote['title']} (copia)',
          'content': originalNote['content'],
          'richContent': originalNote['richContent'],
          'tags': originalNote['tags'] ?? [],
          'pinned': false,
          'icon': originalNote['icon'] ?? '📝',
          'iconColor':
              originalNote['iconColor'] ?? const Color(0xFF6B7280).toARGB32(),
        },
      );

      await _loadNotes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Nota duplicada'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      logDebug('⚠️ Error duplicando nota: $e');
    }
  }

  Future<void> _moveNoteToFolderDialog(String noteId) async {
    if (_folders.isEmpty) {
      ToastService.info('No hay carpetas. Crea una primero.');
      return;
    }
    final selected = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Mover a carpeta'),
          content: SizedBox(
            width: 320,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _folders.length,
              itemBuilder: (ctx, index) {
                final folder = _folders[index];
                return ListTile(
                  leading: Icon(Icons.folder_rounded, color: folder.color),
                  title: Text(folder.name),
                  subtitle: Text('${folder.noteIds.length} notas'),
                  onTap: () => Navigator.pop(ctx, folder.id),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (selected != null) {
      try {
        // Eliminar la nota de todas las carpetas previas
        for (final folder in _folders) {
          if (folder.noteIds.contains(noteId)) {
            await FirestoreService.instance.removeNoteFromFolder(
              uid: getUid(),
              folderId: folder.id,
              noteId: noteId,
            );
          }
        }
        // Agregar la nota a la nueva carpeta
        await FirestoreService.instance.addNoteToFolder(
          uid: getUid(),
          folderId: selected,
          noteId: noteId,
        );
        await _loadFolders();
        await _loadNotes();
        ToastService.success('Nota movida a carpeta');
      } catch (e) {
        logDebug('⚠️ Error moviendo nota a carpeta: $e');
        ToastService.error('Error al mover nota');
      }
    }
  }

  Future<void> _exportFolder(String folderId) async {
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);
      final allNotes = await FirestoreService.instance.listNotes(uid: getUid());
      final folderNotes = allNotes
          .where((note) => folder.noteIds.contains(note['id'].toString()))
          .toList();

      if (folderNotes.isEmpty) {
        ToastService.info('La carpeta está vacía');
        return;
      }

      // Export each note in the folder
      for (final note in folderNotes) {
        await ExportImportService.exportSingleNoteToMarkdown(note);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${folderNotes.length} notas exportadas de "${folder.name}"',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
  logDebug('❌ Error exportando carpeta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _showEditFolderDialog(Folder folder) async {
    // For now, edit dialog is just rename + color picker combined
    await _showRenameFolderDialog(folder);
  }

  // --- New helper methods for extended context menu actions ---

  Future<void> _togglePinNote(String noteId, bool pin) async {
      try {
      Map<String, dynamic> pinnedData = {'pinned': pin};
      try {
        pinnedData = attachFieldTimestamps(pinnedData);
      } catch (_) {}
      await FirestoreService.instance.updateNote(
        uid: getUid(),
        noteId: noteId,
        data: pinnedData,
      );
      if (mounted) {
        setState(() {
          final idx = _allNotes.indexWhere((n) => n['id'].toString() == noteId);
          if (idx >= 0) {
            _allNotes[idx]['pinned'] = pin;
          }
          final idx2 = _notes.indexWhere((n) => n['id'].toString() == noteId);
          if (idx2 >= 0) {
            _notes[idx2]['pinned'] = pin;
          }
        });
      }
      ToastService.success(pin ? 'Nota fijada' : 'Nota desfijada');
    } catch (e) {
  logDebug('⚠️ Error toggling pin: $e');
    }
  }

  Future<void> _toggleFavoriteNote(String noteId, bool fav) async {
      try {
      Map<String, dynamic> favData = {'favorite': fav};
      try {
        favData = attachFieldTimestamps(favData);
      } catch (_) {}
      await FirestoreService.instance.updateNote(
        uid: getUid(),
        noteId: noteId,
        data: favData,
      );
      if (mounted) {
        setState(() {
          final idx = _allNotes.indexWhere((n) => n['id'].toString() == noteId);
          if (idx >= 0) {
            _allNotes[idx]['favorite'] = fav;
          }
          final idx2 = _notes.indexWhere((n) => n['id'].toString() == noteId);
          if (idx2 >= 0) {
            _notes[idx2]['favorite'] = fav;
          }
        });
      }
      ToastService.success(
        fav ? 'Añadido a favoritos' : 'Eliminado de favoritos',
      );
    } catch (e) {
  logDebug('⚠️ Error toggling favorite: $e');
    }
  }

  Future<void> _toggleArchiveNote(String noteId, bool archive) async {
      try {
      Map<String, dynamic> archiveData = {'archived': archive};
      try {
        archiveData = attachFieldTimestamps(archiveData);
      } catch (_) {}
      await FirestoreService.instance.updateNote(
        uid: getUid(),
        noteId: noteId,
        data: archiveData,
      );
      if (mounted) {
        setState(() {
          final idx = _allNotes.indexWhere((n) => n['id'].toString() == noteId);
          if (idx >= 0) {
            _allNotes[idx]['archived'] = archive;
          }
          final idx2 = _notes.indexWhere((n) => n['id'].toString() == noteId);
          if (idx2 >= 0) {
            _notes[idx2]['archived'] = archive;
          }
        });
      }
      ToastService.success(archive ? 'Nota archivada' : 'Nota desarchivada');
    } catch (e) {
  logDebug('⚠️ Error toggling archive: $e');
    }
  }

  Future<void> _showAddTagsDialog(String noteId) async {
    final note = _allNotes.firstWhere((n) => n['id'].toString() == noteId);
    final currentTags = List<String>.from((note['tags'] as List?) ?? []);
    final controller = TextEditingController(text: currentTags.join(', '));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir etiquetas'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'etiqueta1, etiqueta2'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final tags = controller.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      try {
        Map<String, dynamic> tagsData = {'tags': tags};
        try {
          tagsData = attachFieldTimestamps(tagsData);
        } catch (_) {}
        await FirestoreService.instance.updateNote(
          uid: getUid(),
          noteId: noteId,
          data: tagsData,
        );
        if (mounted) {
          setState(() {
            final idx = _allNotes.indexWhere(
              (n) => n['id'].toString() == noteId,
            );
            if (idx >= 0) {
              _allNotes[idx]['tags'] = tags;
            }
            final idx2 = _notes.indexWhere((n) => n['id'].toString() == noteId);
            if (idx2 >= 0) {
              _notes[idx2]['tags'] = tags;
            }
          });
        }
        ToastService.success('Etiquetas actualizadas');
      } catch (e) {
  logDebug('⚠️ Error actualizando etiquetas: $e');
      }
    }
  }

  Future<void> _copyNoteLink(String noteId) async {
    try {
      // Fallback share link — copiar una referencia local segura
      final url = '${Uri.base.toString()}#note/$noteId';
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) ToastService.success('Enlace copiado');
    } catch (e) {
  logDebug('⚠️ Error copiando enlace: $e');
    }
  }

  // Generar enlace público para compartir fácilmente
  Future<void> _generatePublicLink(String noteId) async {
    try {
      final sharingService = SharingService();
      final token = await sharingService.generatePublicLink(noteId: noteId);
      final publicUrl = '${Uri.base.toString()}public/$token';

      await Clipboard.setData(ClipboardData(text: publicUrl));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.link_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Enlace público copiado al portapapeles')),
              ],
            ),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Ver',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Enlace público'),
                    content: SelectableText(publicUrl),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
  logDebug('❌ Error generando enlace público: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar enlace: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showNoteHistory(String noteId) {
    // Simple placeholder — open history page or dialog if available
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Historial de la nota'),
        content: const Text('Historial no disponible en esta versión.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFolderColorPicker(String folderId) async {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.amber,
      Colors.pink,
      Colors.purple,
      Colors.grey,
    ];
    final chosen = await showDialog<Color?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Color de carpeta'),
        content: Wrap(
          spacing: 8,
          children: colors
              .map(
                (c) => GestureDetector(
                  onTap: () => Navigator.pop(ctx, c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (chosen != null) {
      try {
        await FirestoreService.instance.updateFolder(
          uid: getUid(),
          folderId: folderId,
          data: {'color': chosen.toARGB32()},
        );
        if (mounted) {
          setState(() {
            final idx = _folders.indexWhere((f) => f.id == folderId);
            if (idx >= 0) {
              _folders[idx] = _folders[idx].copyWith(color: chosen);
            }
          });
        }
      } catch (e) {
  logDebug('⚠️ Error cambiando color de carpeta: $e');
      }
    }
  }

  void _showNoteProperties(String noteId) {
    final note = _allNotes.firstWhere((n) => n['id'].toString() == noteId);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Propiedades de la nota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Título: ${note['title'] ?? ''}'),
            const SizedBox(height: 8),
            Text('ID: $noteId'),
            const SizedBox(height: 8),
            Text('Creado: ${note['createdAt'] ?? '—'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // Minimal insert helpers for editor
  void _insertMarkdownTable() {
    final before = _content.text;
    _content.text =
        '$before\n| Col1 | Col2 | Col3 |\n|---|---:|:---:|\n|   |   |   |\n';
    _content.selection = TextSelection.collapsed(offset: _content.text.length);
  }

  void _insertCodeBlock() {
    final before = _content.text;
    _content.text = '$before\n```\n// lenguaje\n```\n';
    _content.selection = TextSelection.collapsed(
      offset: _content.text.length - 7,
    );
  }

  // Exportar una sola nota
  Future<void> _exportSingleNote(String noteId) async {
    try {
      final notes = await FirestoreService.instance.listNotes(uid: getUid());
      final note = notes.firstWhere((n) => n['id'].toString() == noteId);

      await ExportImportService.exportSingleNoteToMarkdown(note);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nota exportada'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
  logDebug('❌ Error exportando nota: $e');
    }
  }

  // Compartir una nota
  Future<void> _shareNote(String noteId) async {
    try {
      final notes = await FirestoreService.instance.listNotes(uid: getUid());
      final note = notes.firstWhere((n) => n['id'].toString() == noteId);

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => ShareDialog(
            itemId: noteId,
            itemType: SharedItemType.note,
            itemTitle: note['title']?.toString() ?? 'Sin título',
          ),
        );
      }
    } catch (e) {
  logDebug('❌ Error compartiendo nota: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // Compartir una carpeta
  Future<void> _shareFolder(String folderId) async {
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => ShareDialog(
            itemId: folderId,
            itemType: SharedItemType.folder,
            itemTitle: folder.name,
          ),
        );
      }
    } catch (e) {
  logDebug('❌ Error compartiendo carpeta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir carpeta: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // Confirmar eliminación de carpeta
  Future<void> _confirmDeleteFolder(Folder folder) async {
    final hasNotes = folder.noteIds.isNotEmpty;
    final noteCountText = hasNotes ? ' (${folder.noteIds.length} notas)' : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Eliminar carpeta',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro que deseas eliminar "${folder.name}"$noteCountText?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (hasNotes) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Las ${folder.noteIds.length} notas se moverán fuera de la carpeta y quedarán sin organizar.',
                        style: TextStyle(
                          color: AppColors.warning.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'La carpeta está vacía y se puede eliminar de forma segura.',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(hasNotes ? 'Eliminar y mover notas' : 'Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
  try {
  logDebug('🗑️ Eliminando carpeta (docId): ${folder.docId}');

        // 1. Si tiene notas, moverlas fuera de la carpeta primero
        if (hasNotes) {
          logDebug(
            '📦 Moviendo ${folder.noteIds.length} notas fuera de la carpeta...',
          );
          for (final noteId in folder.noteIds) {
            try {
              await FirestoreService.instance.removeNoteFromFolder(
                uid: getUid(),
                folderId: folder.docId, // Usar docId consistentemente
                noteId: noteId,
              );
              logDebug('✅ Nota $noteId movida fuera de la carpeta');
            } catch (e) {
              logDebug('⚠️ Error moviendo nota $noteId: $e');
            }
          }
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // 2. Eliminar de Firestore
        logDebug(
          '🔥 Intentando eliminar carpeta de Firestore (uid: ${getUid()}, folderId: ${folder.docId})',
        );
        await FirestoreService.instance.deleteFolder(
          uid: getUid(),
          folderId: folder.docId,
        );
  logDebug('✅ Carpeta eliminada de Firestore - ${folder.docId}');

        // 3. Verificar que realmente se eliminó
        await Future.delayed(const Duration(milliseconds: 500));
        final deletedFolder = await FirestoreService.instance.getFolder(
          uid: getUid(),
          folderId: folder.docId,
        );

        if (deletedFolder != null) {
          throw Exception(
            'La carpeta no se eliminó correctamente de Firestore',
          );
        }
  logDebug('✅ Verificación: Carpeta realmente eliminada de Firestore');

        // 4. Actualizar estado local inmediatamente
        setState(() {
          _folders.removeWhere((f) => f.id == folder.id);
          _expandedFolders.remove(folder.id);
          if (_selectedFolderId == folder.id) {
            _selectedFolderId = null;
          }
        });
  logDebug('✅ Carpeta eliminada del estado local');

        // 5. Verificar integridad y hacer limpieza final
        await _verifyFolderIntegrity(folder.docId);

        // 6. Recargar carpetas Y notas para sincronizar con Firestore
        await _loadFolders();
        await _loadNotes();

  logDebug('✅ Eliminación y verificación completa');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasNotes
                          ? 'Carpeta "${folder.name}" eliminada y ${folder.noteIds.length} notas movidas'
                          : 'Carpeta "${folder.name}" eliminada',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        logDebug('❌ Error eliminando carpeta: $e');
        // Si falla, recargar carpetas para restaurar estado consistente
        await _loadFolders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar carpeta: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
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
          // FocusModeIntent removed
          ToggleCompactModeIntent: CallbackAction<ToggleCompactModeIntent>(
            onInvoke: (_) {
              _toggleCompactMode();
              return null;
            },
          ),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 800;

            if (_selectedId == null && _notes.isEmpty && !_loading) {
              return Scaffold(body: EmptyNotesState(onCreate: _create));
            }

            return Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: WorkspaceHeader(
                  saving: _saving,
                  // We now have a single WYSIWYG editor; use this control as a focus mode indicator only.
                  focusMode: false,
                  onToggleFocus: null,
                  onSave: _save,
                    onSettings: _openSettings,
                    onCopyMarkdown: () async {
                      // Copy current note as Markdown to clipboard
                      if (_selectedId == null) {
                        ToastService.error('No hay nota seleccionada');
                        return;
                      }
                      try {
                        final note = _allNotes.firstWhere((n) => n['id'] == _selectedId);
                        await ExportImportService.exportSingleNoteToMarkdown(note);
                        // On native platforms ExportImportService throws UnimplementedError; fallback to clipboard
                        ToastService.info('Nota exportada (ver descargas o portapapeles)');
                      } catch (e) {
                        // Fallback: copy markdown to clipboard
                        try {
                          final note = _allNotes.firstWhere((n) => n['id'] == _selectedId);
                          final title = note['title']?.toString() ?? 'Sin título';
                          final content = note['content']?.toString() ?? '';
                          final tags = (note['tags'] as List?)?.join(', ') ?? '';
                          final createdAt = note['createdAt']?.toString() ?? '';
                          final markdown = '''# $title

  **Fecha:** $createdAt
  ${tags.isNotEmpty ? '**Etiquetas:** $tags\n' : ''}
  ---

  $content
  ''';
                          await Clipboard.setData(ClipboardData(text: markdown));
                          ToastService.success('Markdown copiado al portapapeles');
                        } catch (e) {
                          logDebug('❌ Error exportando carpeta: $e');
                        }
                      }
                    },
                    onExport: () async {
                      // Export single note (platform-specific)
                      if (_selectedId == null) {
                        ToastService.error('No hay nota seleccionada');
                        return;
                      }
                      try {
                        final note = _allNotes.firstWhere((n) => n['id'] == _selectedId);
                        await ExportImportService.exportSingleNoteToMarkdown(note);
                        ToastService.success('Exportado nota como Markdown');
                      } catch (e) {
                        ToastService.error('Error exportando nota: $e');
                      }
                    },
                    onExportAll: () async {
                      try {
                        await ExportImportService.exportToJson(_allNotes);
                        ToastService.success('Exportación de todas las notas iniciada');
                      } catch (e) {
                        ToastService.error('Error exportando notas: $e');
                      }
                    },
                  saveScale: _saveScale,
                ),
              ),
              drawer: narrow
                  ? Drawer(
                      backgroundColor: AppColors.surfaceLight2,
                      child: SafeArea(
                        child: _buildNotesList(width: constraints.maxWidth),
                      ),
                    )
                  : null,
              body: Row(
                children: [
                  if (!narrow)
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 260,
                        maxWidth: 360,
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: AppColors.borderColorLight,
                            ),
                          ),
                        ),
                        child: SafeArea(
                          child: _buildNotesList(width: constraints.maxWidth),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Container(
                      color: AppColors.bgLight,
                      padding: EdgeInsets.all(
                        narrow ? AppColors.space16 : AppColors.space24,
                      ),
                      child: _selectedId == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppColors.space24,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight2,
                                      borderRadius: BorderRadius.circular(
                                        AppColors.radiusXl,
                                      ),
                                      border: Border.all(
                                        color: AppColors.borderColorLight,
                                      ),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: AppColors.space8),
                                  Text(
                                    'o crea una nueva para comenzar',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textSecondaryLight,
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
                                    // EDITOR PROFESIONAL A TIEMPO REAL
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Título minimalista sin bordes
                                        TextField(
                                          controller: _title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                          decoration: const InputDecoration(
                                            hintText: 'Sin título',
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: AppColors.space16,
                                                  vertical: AppColors.space12,
                                                ),
                                          ),
                                          onChanged: (_) {
                                            // NO llamar setState aquí para evitar perder foco
                                            _debouncedSave();
                                          },
                                        ),
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: AppColors.borderColor,
                                        ),

                                        // Editor expandido al máximo
                                        Expanded(
                                          child: QuillEditorWidget(
                                            uid: getUid(),
                                            initialDeltaJson: _richJson.isEmpty
                                                ? null
                                                : _richJson,
                                            onChanged: (deltaJson) {
                                              _richJson = deltaJson;
                                              _debouncedSave();
                                            },
                                            onPlainTextChanged: (plain) {
                                              // Keep plain-text mirror for previews/search/export
                                              if (_content.text != plain) {
                                                _content.text = plain;
                                              }
                                            },
                                            onSave: (deltaJson) async {
                                              _richJson = deltaJson;
                                              await _save();
                                            },
                                            fetchNoteSuggestions: (query) async {
                                              final q = query
                                                  .trim()
                                                  .toLowerCase();
                                              if (q.isEmpty) {
                                                return _allNotes
                                                    .take(20)
                                                    .map(
                                                      (n) => NoteSuggestion(
                                                        id: n['id'].toString(),
                                                        title:
                                                            (n['title']
                                                                ?.toString() ??
                                                            ''),
                                                        tags: List<String>.from(
                                                          (n['tags'] as List?)
                                                                  ?.whereType<
                                                                    String
                                                                  >() ??
                                                              const [],
                                                        ),
                                                      ),
                                                    )
                                                    .toList();
                                              }
                                              final filtered = _allNotes
                                                  .where((n) {
                                                    final title =
                                                        (n['title']?.toString() ??
                                                                '')
                                                            .toLowerCase();
                                                    final id = n['id']
                                                        .toString()
                                                        .toLowerCase();
                                                    return title.contains(q) ||
                                                        id.contains(q);
                                                  })
                                                  .take(20);
                                              return filtered
                                                  .map(
                                                    (n) => NoteSuggestion(
                                                      id: n['id'].toString(),
                                                      title:
                                                          (n['title']
                                                              ?.toString() ??
                                                          ''),
                                                      tags: List<String>.from(
                                                        (n['tags'] as List?)
                                                                ?.whereType<
                                                                  String
                                                                >() ??
                                                            const [],
                                                      ),
                                                    ),
                                                  )
                                                  .toList();
                                            },
                                            onLinksChanged: (linkedIds) async {
                                              if (_selectedId == null) return;
                                              try {
                                                await FirestoreService.instance
                                                    .updateNoteLinks(
                                                      uid: getUid(),
                                                      noteId: _selectedId!,
                                                      linkedNoteIds: linkedIds,
                                                    );
                                              } catch (e) {
                                                logDebug(
                                                  'Error updating links: $e',
                                                );
                                              }
                                            },
                                            onNoteOpen: (labelOrId) async {
                                              // Try resolve by exact ID first, then by title match
                                              String? id = _allNotes
                                                  .firstWhere(
                                                    (n) =>
                                                        n['id'].toString() ==
                                                        labelOrId,
                                                    orElse: () =>
                                                        <String, dynamic>{},
                                                  )['id']
                                                  ?.toString();
                                              id ??= _allNotes
                                                  .firstWhere(
                                                    (n) =>
                                                        (n['title']
                                                                ?.toString() ??
                                                            '') ==
                                                        labelOrId,
                                                    orElse: () =>
                                                        <String, dynamic>{},
                                                  )['id']
                                                  ?.toString();
                                              if (id != null && id.isNotEmpty) {
                                                await _select(id);
                                              }
                                            },
                                          ),
                                        ),

                                        // Tags compactos en la parte inferior
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            border: Border(
                                              top: BorderSide(
                                                color: AppColors.borderColor,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppColors.space16,
                                            vertical: AppColors.space8,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.label_outline_rounded,
                                                size: 16,
                                                color: AppColors.textMuted,
                                              ),
                                              const SizedBox(
                                                width: AppColors.space8,
                                              ),
                                              Expanded(
                                                child: TagInput(
                                                  initialTags: _tags,
                                                  onAdd: (t) async {
                                                    setState(
                                                      () =>
                                                          _tags = [..._tags, t],
                                                    );
                                                    await _save();
                                                  },
                                                  onRemove: (t) async {
                                                    setState(
                                                      () => _tags = _tags
                                                          .where((e) => e != t)
                                                          .toList(),
                                                    );
                                                    await _save();
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Panel de backlinks colapsable
                                        if (_selectedId != null)
                                          Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              border: Border(
                                                top: BorderSide(
                                                  color: AppColors.borderColor,
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                InkWell(
                                                  onTap: () => setState(
                                                    () => _showBacklinks =
                                                        !_showBacklinks,
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal:
                                                              AppColors.space16,
                                                          vertical:
                                                              AppColors.space8,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.link_rounded,
                                                          size: 16,
                                                          color: AppColors
                                                              .textMuted,
                                                        ),
                                                        const SizedBox(
                                                          width:
                                                              AppColors.space8,
                                                        ),
                                                        Text(
                                                          'Backlinks',
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: AppColors
                                                                    .textSecondary,
                                                              ),
                                                        ),
                                                        const Spacer(),
                                                        Icon(
                                                          _showBacklinks
                                                              ? Icons
                                                                    .keyboard_arrow_up_rounded
                                                              : Icons
                                                                    .keyboard_arrow_down_rounded,
                                                          size: 20,
                                                          color: AppColors
                                                              .textMuted,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (_showBacklinks)
                                                  Container(
                                                    height: 200,
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        top: BorderSide(
                                                          color: AppColors
                                                              .borderColor,
                                                        ),
                                                      ),
                                                    ),
                                                    child: BacklinksPanel(
                                                      uid: getUid(),
                                                      noteId: _selectedId!,
                                                      onNoteOpen:
                                                          (noteId) async {
                                                            await _select(
                                                              noteId,
                                                            );
                                                          },
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (_isRecording)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: RecordingOverlay(
                                          isRecording: _isRecording,
                                          onStop: () async {
                                            final url =
                                                await AudioService.stopAndUpload(
                                                  uid: getUid(),
                                                );
                                            if (!mounted) return;
                                            setState(
                                              () => _isRecording = false,
                                            );
                                            if (url != null) {
                                              final sel = _content.selection;
                                              final i = sel.isValid
                                                  ? sel.base.offset
                                                  : _content.text.length;
                                              final newText =
                                                  '${_content.text.substring(0, i)}[audio]($url)${_content.text.substring(i)}';
                                              setState(
                                                () => _content.text = newText,
                                              );
                                              await _save();
                                            }
                                          },
                                          onCancel: () async {
                                            if (AudioService.supportsDiscard) {
                                              await AudioService.stopRecordingAndDiscard();
                                            }
                                            if (!mounted) return;
                                            setState(
                                              () => _isRecording = false,
                                            );
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
                      child: UnifiedFABMenu(
                        onNewNote: _create,
                        onNewFolder: _showCreateFolderDialog,
                        onNewFromTemplate: _createFromTemplate,
                        onInsertImage: _insertImage,
                        onToggleRecording: _toggleRecording,
                        onOpenDashboard: _openDashboard,
                        isRecording: _isRecording,
                      ),
                    )
                  : null,
            );
          },
        ),
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
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 1),
              ),
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
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          suffixIcon: _search.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
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
                        color:
                            (_filterTags.isNotEmpty || _filterDateRange != null)
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      tooltip: 'Búsqueda avanzada',
                      style: IconButton.styleFrom(
                        backgroundColor:
                            (_filterTags.isNotEmpty || _filterDateRange != null)
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surfaceLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppColors.space12),

                // Fila de acciones simplificada (solo estadísticas y compacto)
                Row(
                  children: [
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
                        _showRecentSearches
                            ? Icons.history
                            : Icons.history_outlined,
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
                        _compactMode
                            ? Icons.density_small
                            : Icons.density_medium,
                        size: 20,
                      ),
                      tooltip: _compactMode
                          ? 'Modo expandido'
                          : 'Modo compacto',
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
                if (_filterTags.isNotEmpty ||
                    _filterDateRange != null ||
                    _selectedFolderId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppColors.space12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_notes.length} resultado(s)',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.textSecondary),
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
              child: WorkspaceStats(notes: _allNotes, folders: _folders.length),
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

          // Sidebar sin botones extra ni dropzones: mantener limpio el menú

          // Lista unificada de carpetas y notas con tarjetas modernas
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
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
                            (_selectedFolderId == '__SHARED_WITH_ME__' ||
                                    _selectedFolderId == '__SHARED_BY_ME__')
                                ? 'No hay notas compartidas'
                                : 'No hay notas',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _selectedFolderId == '__SHARED_WITH_ME__'
                                ? 'Cuando alguien comparta contigo, aparecerán aquí'
                                : _selectedFolderId == '__SHARED_BY_ME__'
                                ? 'Aún no has compartido notas'
                                : 'Crea tu primera nota',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                : EnhancedContextMenuRegion(
                    // Click derecho en área vacía
                    actions: (context) =>
                        EnhancedContextMenuBuilder.workspaceMenu(),
                    onActionSelected: (action) =>
                        _handleEnhancedContextMenuAction(
                          action.value,
                          context: context,
                        ),
                    child: Builder(
                      builder: (context) {
                        // En secciones virtuales de "Compartidas", no mostramos carpetas
                        final bool inVirtualShared =
                            _selectedFolderId == '__SHARED_WITH_ME__' ||
                            _selectedFolderId == '__SHARED_BY_ME__';
                        final List<Map<String, dynamic>> notesWithoutFolder;
                        if (inVirtualShared) {
                          notesWithoutFolder = List<Map<String, dynamic>>.from(
                            _notes,
                          );
                        } else {
                          // Obtener IDs de notas que están en carpetas
                          final Set<String> notesInFolders = {};
                          for (final folder in _folders) {
                            notesInFolders.addAll(folder.noteIds);
                          }
                          // Filtrar notas que NO están en carpetas
                          notesWithoutFolder = _notes
                              .where(
                                (n) => !notesInFolders.contains(
                                  n['id'].toString(),
                                ),
                              )
                              .toList();
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(AppColors.space12),
                          itemCount:
                              (inVirtualShared ? 0 : _folders.length) +
                              notesWithoutFolder.length +
                              2,
                          itemBuilder: (context, i) {
                            // Sección "Compartidas"
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppColors.space8,
                                  vertical: AppColors.space4,
                                ),
                                child: Text(
                                  'Compartidas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }
                            if (i == 1) {
                              return Column(
                                children: [
                                  _buildVirtualSharedTile(
                                    id: '__SHARED_WITH_ME__',
                                    name: 'Conmigo',
                                    icon: Icons.inbox_rounded,
                                    color: AppColors.info,
                                  ),
                                  _buildVirtualSharedTile(
                                    id: '__SHARED_BY_ME__',
                                    name: 'Por mí',
                                    icon: Icons.send_rounded,
                                    color: AppColors.secondary,
                                  ),
                                  const Divider(
                                    color: AppColors.borderColor,
                                    height: 1,
                                  ),
                                ],
                              );
                            }
                            // Sección de carpetas con sus notas
                            final baseIndex = 2; // virtual header + tiles
                            if (!inVirtualShared &&
                                i - baseIndex < _folders.length) {
                              final folder = _folders[i - baseIndex];
                              final noteCount = folder.noteIds.length;
                              return _buildFolderCard(folder, noteCount);
                            }

                            // Notas sin carpeta (con menú contextual)
                            final noteIndex =
                                i -
                                (inVirtualShared ? 0 : _folders.length) -
                                baseIndex;
                            final note = notesWithoutFolder[noteIndex];
                            final id = note['id'].toString();
                            return EnhancedContextMenuRegion(
                              actions: (context) =>
                                  EnhancedContextMenuBuilder.noteMenu(
                                    isInFolder: false,
                                    isPinned: note['pinned'] == true,
                                    isFavorite: note['favorite'] == true,
                                    isArchived: note['archived'] == true,
                                    hasIcon: note['icon'] != null,
                                  ),
                              onActionSelected: (action) =>
                                  _handleEnhancedContextMenuAction(
                                    action.value,
                                    context: context,
                                    noteId: id,
                                  ),
                              child: NotesSidebarCard(
                                note: note,
                                noteId: id,
                                isSelected: id == _selectedId,
                                onTap: () => _select(id),
                                onPin: () async {
                                  if (inVirtualShared ||
                                      note['isShared'] == true) {
                                    ToastService.info(
                                      'No puedes anclar notas compartidas',
                                    );
                                    return;
                                  }
                                  await FirestoreService.instance.setPinned(
                                    uid: getUid(),
                                    noteId: id,
                                    pinned: !(note['pinned'] == true),
                                  );
                                  await _loadNotes();
                                },
                                onDelete: () async {
                                  if (inVirtualShared) {
                                    // Si es carpeta compartida virtual, permitir "dejar de seguir"
                                    ToastService.info(
                                      'Nota quitada de compartidas',
                                    );
                                    return;
                                  }
                                  if (note['isShared'] == true) {
                                    // Para notas compartidas, permitir eliminarlas de la vista
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                          'Eliminar nota compartida',
                                        ),
                                        content: const Text(
                                          '¿Deseas dejar de ver esta nota compartida? No se eliminará para el propietario.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text(
                                              'Dejar de seguir',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      // Aquí deberías implementar la lógica para dejar de seguir
                                      ToastService.success(
                                        'Dejaste de seguir esta nota',
                                      );
                                      await _loadNotes();
                                    }
                                    return;
                                  }
                                  await _delete(id);
                                },
                                onSetIcon: () => _showNoteIconPicker(
                                  noteId: id,
                                  initialIcon: note['icon']?.toString(),
                                  initialColor: note['iconColor'] is int
                                      ? Color(note['iconColor'])
                                      : null,
                                ),
                                onClearIcon: () async => _clearNoteIcon(id),
                                enableDrag:
                                    !inVirtualShared &&
                                    note['isShared'] != true,
                                compact: _compactMode,
                              ),
                            );
                          },
                        );
                      },
                    ),
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

  // Nuevas funciones para el menú contextual mejorado

  // Icon registry for large icon/color sets
  // ignore_for_file: unused_import

  Future<void> _showNoteIconPicker({
    required String noteId,
    String? initialIcon,
    Color? initialColor,
  }) async {
    Color selectedColor = initialColor ?? AppColors.primary;
    String? selectedIcon = initialIcon ?? 'note';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        String query = '';
        final allIcons = NoteIconRegistry.icons.entries.toList();
        List<MapEntry<String, IconData>> filtered = allIcons;
        int tabIndex = 0;
        String emojiInput = '';
        String hexInput = selectedColor
            .toARGB32()
            .toRadixString(16)
            .padLeft(8, '0')
            .toUpperCase();

        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Icono de nota',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tabs: Iconos, Emoji, HEX
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Iconos'),
                        selected: tabIndex == 0,
                        onSelected: (_) => setState(() => tabIndex = 0),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Emoji'),
                        selected: tabIndex == 1,
                        onSelected: (_) => setState(() => tabIndex = 1),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('HEX'),
                        selected: tabIndex == 2,
                        onSelected: (_) => setState(() => tabIndex = 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (tabIndex == 0) ...[
                    // Search
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar icono…',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (v) {
                        setState(() {
                          query = v.trim().toLowerCase();
                          filtered = allIcons
                              .where((e) => e.key.toLowerCase().contains(query))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Icon grid (scrollable)
                    SizedBox(
                      height: 220,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (gctx, i) {
                          final entry = filtered[i];
                          final isSel = entry.key == selectedIcon;
                          return InkWell(
                            onTap: () =>
                                setState(() => selectedIcon = entry.key),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSel
                                      ? AppColors.primary
                                      : AppColors.borderColor,
                                ),
                              ),
                              child: Icon(
                                entry.value,
                                color: isSel
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else if (tabIndex == 1) ...[
                    // Emoji input
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Pega o escribe un emoji…',
                        prefixIcon: Icon(Icons.emoji_emotions_outlined),
                      ),
                      maxLength: 2,
                      onChanged: (v) => setState(() => emojiInput = v),
                    ),
                    const SizedBox(height: 16),
                    if (emojiInput.isNotEmpty)
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          emojiInput,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                  ] else if (tabIndex == 2) ...[
                    // HEX color input
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Color HEX (AARRGGBB)',
                        prefixIcon: Icon(Icons.colorize),
                      ),
                      maxLength: 8,
                      controller: TextEditingController(text: hexInput),
                      onChanged: (v) {
                        setState(() {
                          hexInput = v.toUpperCase();
                          if (hexInput.length == 8) {
                            try {
                              selectedColor = Color(
                                int.parse(hexInput, radix: 16),
                              );
                            } catch (_) {}
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Color palette (only for icon/emoji)
                  if (tabIndex != 2)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const Text(
                            'Color:',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          ...NoteIconRegistry.palette.map((c) {
                            final sel = selectedColor == c;
                            return GestureDetector(
                              onTap: () => setState(() => selectedColor = c),
                              child: Container(
                                width: 22,
                                height: 22,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: sel
                                        ? Colors.white
                                        : AppColors.borderColor,
                                    width: sel ? 2 : 1,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true && selectedIcon != null) {
      Map<String, dynamic> iconData = {'icon': selectedIcon, 'iconColor': selectedColor.toARGB32()};
      try {
        iconData = attachFieldTimestamps(iconData);
      } catch (_) {}
      await FirestoreService.instance.updateNote(
        uid: getUid(),
        noteId: noteId,
        data: iconData,
      );
      // ✅ CORRECCIÓN: Actualizar solo la nota específica en lugar de recargar todo
      _updateNoteInList(noteId, {
        'icon': selectedIcon,
        'iconColor': selectedColor.toARGB32(),
      });
    }
  }

  Future<void> _clearNoteIcon(String noteId) async {
    Map<String, dynamic> clearIconData = {'icon': null, 'iconColor': null};
    try {
      clearIconData = attachFieldTimestamps(clearIconData);
    } catch (_) {}
    await FirestoreService.instance.updateNote(
      uid: getUid(),
      noteId: noteId,
      data: clearIconData,
    );
    // ✅ CORRECCIÓN: Actualizar solo la nota específica en lugar de recargar todo
    _updateNoteInList(noteId, {'icon': null, 'iconColor': null});
  }

  /// Actualiza una nota específica en las listas locales sin recargar todo
  void _updateNoteInList(String noteId, Map<String, dynamic> updates) {
    if (!mounted) return;

    setState(() {
      // Actualizar en _allNotes
      final allIndex = _allNotes.indexWhere(
        (note) => note['id'].toString() == noteId,
      );
      if (allIndex >= 0) {
        _allNotes[allIndex] = {..._allNotes[allIndex], ...updates};
      }

      // Actualizar en _notes (lista filtrada)
      final notesIndex = _notes.indexWhere(
        (note) => note['id'].toString() == noteId,
      );
      if (notesIndex >= 0) {
        _notes[notesIndex] = {..._notes[notesIndex], ...updates};
      }
    });
  }

  Future<void> _showRenameNoteDialog(String noteId) async {
    final note = _allNotes.firstWhere(
      (n) => n['id'].toString() == noteId,
      orElse: () => {},
    );
    final controller = TextEditingController(
      text: (note['title']?.toString() ?? '').trim(),
    );
    final newTitle = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Renombrar nota'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'Introduce un nombre',
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    if (newTitle == null) return;
    if (newTitle.isEmpty) {
      ToastService.warning('El título no puede estar vacío');
      return;
    }
    Map<String, dynamic> renameData = {'title': newTitle};
    try {
      renameData = attachFieldTimestamps(renameData);
    } catch (_) {}
    await FirestoreService.instance.updateNote(
      uid: getUid(),
      noteId: noteId,
      data: renameData,
    );
    _updateNoteInList(noteId, {'title': newTitle});
  }

  Future<void> _showRenameFolderDialog(Folder folder) async {
    final controller = TextEditingController(text: folder.name);
    final newName = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Renombrar carpeta'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Introduce un nombre',
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    if (newName == null) return;
    if (newName.isEmpty) {
      ToastService.warning('El nombre no puede estar vacío');
      return;
    }
    await FirestoreService.instance.updateFolder(
      uid: getUid(),
      folderId: folder.id,
      data: {'name': newName},
    );
    await _loadFolders();
  }

  Future<void> _showFolderIconPicker(String folderId) async {
    final folder = _folders.firstWhere((f) => f.id == folderId);

    Color selectedColor = folder.color;
    String? selectedIcon = folder.emoji == null
        ? _iconToString(folder.icon)
        : null;
    String? selectedEmoji = folder.emoji;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        String query = '';
        final allIcons = NoteIconRegistry.icons.entries.toList();
        List<MapEntry<String, IconData>> filtered = allIcons;
        int tabIndex = selectedEmoji != null ? 1 : 0;
        String emojiInput = selectedEmoji ?? '';
        String hexInput = selectedColor
            .toARGB32()
            .toRadixString(16)
            .padLeft(8, '0')
            .toUpperCase();

        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Icono y color de carpeta',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tabs: Iconos, Emoji, HEX
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Iconos'),
                        selected: tabIndex == 0,
                        onSelected: (_) => setState(() => tabIndex = 0),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Emoji'),
                        selected: tabIndex == 1,
                        onSelected: (_) => setState(() => tabIndex = 1),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('HEX'),
                        selected: tabIndex == 2,
                        onSelected: (_) => setState(() => tabIndex = 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (tabIndex == 0) ...[
                    // Search
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar icono…',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (v) {
                        setState(() {
                          query = v.trim().toLowerCase();
                          filtered = allIcons
                              .where((e) => e.key.toLowerCase().contains(query))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Icon grid (scrollable)
                    SizedBox(
                      height: 220,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (gctx, i) {
                          final entry = filtered[i];
                          final isSel = entry.key == selectedIcon;
                          return InkWell(
                            onTap: () => setState(() {
                              selectedIcon = entry.key;
                              selectedEmoji = null;
                            }),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSel
                                      ? AppColors.primary
                                      : AppColors.borderColor,
                                ),
                              ),
                              child: Icon(
                                entry.value,
                                color: isSel
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else if (tabIndex == 1) ...[
                    // Emoji input
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Pega o escribe un emoji…',
                        prefixIcon: Icon(Icons.emoji_emotions_outlined),
                      ),
                      maxLength: 2,
                      onChanged: (v) => setState(() {
                        emojiInput = v;
                        selectedEmoji = v.isNotEmpty ? v : null;
                        selectedIcon = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (emojiInput.isNotEmpty)
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          emojiInput,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                  ] else if (tabIndex == 2) ...[
                    // HEX color input
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Color HEX (AARRGGBB)',
                        prefixIcon: Icon(Icons.colorize),
                      ),
                      maxLength: 8,
                      controller: TextEditingController(text: hexInput),
                      onChanged: (v) {
                        setState(() {
                          hexInput = v.toUpperCase();
                          if (hexInput.length == 8) {
                            try {
                              selectedColor = Color(
                                int.parse(hexInput, radix: 16),
                              );
                            } catch (_) {}
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Color palette (only for icon/emoji)
                  if (tabIndex != 2)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const Text(
                            'Color:',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          ...NoteIconRegistry.palette.map((c) {
                            final sel = selectedColor == c;
                            return GestureDetector(
                              onTap: () => setState(() => selectedColor = c),
                              child: Container(
                                width: 22,
                                height: 22,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: sel
                                        ? Colors.white
                                        : AppColors.borderColor,
                                    width: sel ? 2 : 1,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      try {
        final updateData = <String, dynamic>{'color': selectedColor.toARGB32()};

        if (selectedEmoji != null) {
          updateData['emoji'] = selectedEmoji;
          updateData['icon'] = null; // Clear icon when emoji is set
        } else if (selectedIcon != null) {
          updateData['icon'] = selectedIcon;
          updateData['emoji'] = null; // Clear emoji when icon is set
        }

        await FirestoreService.instance.updateFolder(
          uid: getUid(),
          folderId: folderId,
          data: updateData,
        );
        await _loadFolders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Icono y color de carpeta actualizados'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  String _iconToString(IconData icon) {
    // Usar los mismos tokens que Folder.fromJson/_iconFromString espera
    final iconMap = {
      Icons.folder_rounded: 'folder_rounded',
      Icons.work_rounded: 'work_rounded',
      Icons.school_rounded: 'school_rounded',
      Icons.home_rounded: 'home_rounded',
      Icons.favorite_rounded: 'favorite_rounded',
      Icons.star_rounded: 'star_rounded',
      Icons.bookmark_rounded: 'bookmark_rounded',
      Icons.lightbulb_rounded: 'lightbulb_rounded',
      Icons.code_rounded: 'code_rounded',
      Icons.palette_rounded: 'palette_rounded',
      Icons.music_note_rounded: 'music_note_rounded',
      Icons.sports_esports_rounded: 'sports_esports_rounded',
      Icons.restaurant_rounded: 'restaurant_rounded',
      Icons.flight_rounded: 'flight_rounded',
      Icons.shopping_bag_rounded: 'shopping_bag_rounded',
    };
    return iconMap[icon] ?? 'folder_rounded';
  }

  Future<void> _showCreateSubfolderDialog(String? parentFolderId) async {
    final nameController = TextEditingController();
    final colorNotifier = ValueNotifier<Color>(AppColors.primary);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Nueva subcarpeta',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nombre de la subcarpeta',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<Color>(
              valueListenable: colorNotifier,
              builder: (context, color, _) => Row(
                children: [
                  const Text(
                    'Color: ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final newColor = await _showColorPicker(color);
                      if (newColor != null) {
                        colorNotifier.value = newColor;
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final folderData = {
          'name': nameController.text.trim(),
          'icon': 'folder',
          'color': colorNotifier.value.toARGB32(),
          'noteIds': <String>[],
          'parentFolderId': parentFolderId,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'order': _folders.length,
        };

        await FirestoreService.instance.createFolder(
          uid: getUid(),
          data: folderData,
        );
        await _loadFolders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Subcarpeta "${nameController.text.trim()}" creada',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear subcarpeta: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<Color?> _showColorPicker(Color currentColor) async {
    return showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Seleccionar color',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: 250,
          height: 150,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 18,
            itemBuilder: (context, index) {
              final colors = [
                AppColors.primary,
                Colors.red,
                Colors.green,
                Colors.blue,
                Colors.orange,
                Colors.purple,
                Colors.teal,
                Colors.pink,
                Colors.indigo,
                Colors.cyan,
                Colors.lime,
                Colors.amber,
                Colors.brown,
                Colors.grey,
                Colors.deepOrange,
                Colors.lightBlue,
                Colors.lightGreen,
                Colors.deepPurple,
              ];
              final color = colors[index];
              return InkWell(
                onTap: () => Navigator.pop(context, color),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color == currentColor
                          ? Colors.white
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _duplicateFolder(String folderId) async {
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);

      final folderData = {
        'name': '${folder.name} (copia)',
        'icon': _iconToString(folder.icon),
        'color': folder.color.toARGB32(),
        'noteIds': folder.noteIds
            .toList(), // Copia las referencias a las mismas notas
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'order': _folders.length,
      };

      await FirestoreService.instance.createFolder(
        uid: getUid(),
        data: folderData,
      );
      await _loadFolders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Carpeta "${folder.name}" duplicada con ${folder.noteIds.length} notas',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al duplicar carpeta: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _copyFolderLink(String folderId) {
    final folder = _folders.firstWhere((f) => f.id == folderId);
    final link = 'nootes://folder/$folderId';

    Clipboard.setData(ClipboardData(text: link));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enlace de "${folder.name}" copiado al portapapeles'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
