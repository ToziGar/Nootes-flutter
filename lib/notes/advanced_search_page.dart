import 'package:flutter/material.dart';
import '../widgets/glass.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Búsqueda avanzada global con filtros múltiples
class AdvancedSearchPage extends StatefulWidget {
  const AdvancedSearchPage({super.key});

  @override
  State<AdvancedSearchPage> createState() => _AdvancedSearchPageState();
}

class _AdvancedSearchPageState extends State<AdvancedSearchPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allNotes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  bool _isLoading = false;

  // Filtros
  String _searchQuery = '';
  final Set<String> _selectedTags = {};
  DateTimeRange? _dateRange;
  String _sortBy = 'updated'; // updated, created, title, relevance
  bool _caseSensitive = false;
  bool _wholeWord = false;

  // Estadísticas
  int _totalWords = 0;
  int _totalCharacters = 0;

  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadAllNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllNotes() async {
    setState(() => _isLoading = true);

    try {
      final notes = await FirestoreService.instance.listNotes(uid: _uid);
      setState(() {
        _allNotes = notes;
        _filteredNotes = notes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar notas: $e')));
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredNotes = _allNotes.where((note) {
        // Filtro de texto
        if (_searchQuery.isNotEmpty) {
          final title = note['title']?.toString() ?? '';
          final content = note['content']?.toString() ?? '';
          final searchIn = '$title $content';

          String query = _searchQuery;
          String text = searchIn;

          if (!_caseSensitive) {
            query = query.toLowerCase();
            text = text.toLowerCase();
          }

          if (_wholeWord) {
            final regex = RegExp(r'\b' + RegExp.escape(query) + r'\b');
            if (!regex.hasMatch(text)) return false;
          } else {
            if (!text.contains(query)) return false;
          }
        }

        // Filtro de tags
        if (_selectedTags.isNotEmpty) {
          final noteTags =
              (note['tags'] as List?)?.map((t) => t.toString()).toSet() ?? {};
          if (!_selectedTags.any((tag) => noteTags.contains(tag))) {
            return false;
          }
        }

        // Filtro de fecha
        if (_dateRange != null) {
          final updated = note['updated'] as DateTime?;
          if (updated == null) return false;
          if (updated.isBefore(_dateRange!.start) ||
              updated.isAfter(_dateRange!.end)) {
            return false;
          }
        }

        return true;
      }).toList();

      // Ordenar
      _filteredNotes.sort((a, b) {
        if (_sortBy == 'title') {
          final titleA = a['title']?.toString() ?? '';
          final titleB = b['title']?.toString() ?? '';
          return titleA.compareTo(titleB);
        } else if (_sortBy == 'created') {
          final createdA = a['created'] as DateTime?;
          final createdB = b['created'] as DateTime?;
          if (createdA == null || createdB == null) return 0;
          return createdB.compareTo(createdA);
        } else if (_sortBy == 'relevance' && _searchQuery.isNotEmpty) {
          final scoreA = _calculateRelevance(a);
          final scoreB = _calculateRelevance(b);
          return scoreB.compareTo(scoreA);
        } else {
          // updated
          final updatedA = a['updated'] as DateTime?;
          final updatedB = b['updated'] as DateTime?;
          if (updatedA == null || updatedB == null) return 0;
          return updatedB.compareTo(updatedA);
        }
      });

      // Calcular estadísticas
      _totalWords = 0;
      _totalCharacters = 0;
      for (var note in _filteredNotes) {
        final content = note['content']?.toString() ?? '';
        _totalCharacters += content.length;
        _totalWords += content
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .length;
      }
    });
  }

  int _calculateRelevance(Map<String, dynamic> note) {
    final title = note['title']?.toString().toLowerCase() ?? '';
    final content = note['content']?.toString().toLowerCase() ?? '';
    final query = _searchQuery.toLowerCase();

    int score = 0;

    // Título tiene más peso
    if (title.contains(query)) {
      score += 10;
      if (title == query) score += 20;
      if (title.startsWith(query)) score += 5;
    }

    // Contar ocurrencias en contenido
    final occurrences = query.allMatches(content).length;
    score += occurrences;

    return score;
  }

  Set<String> _getAllTags() {
    final tags = <String>{};
    for (var note in _allNotes) {
      final noteTags = note['tags'] as List?;
      if (noteTags != null) {
        tags.addAll(noteTags.map((t) => t.toString()));
      }
    }
    return tags;
  }

  String _highlightText(String text, String query) {
    if (query.isEmpty) return text;

    // Limitar a primeros 200 caracteres
    if (text.length > 200) {
      final index = text.toLowerCase().indexOf(query.toLowerCase());
      if (index != -1) {
        final start = (index - 50).clamp(0, text.length);
        final end = (index + query.length + 50).clamp(0, text.length);
        text = '...${text.substring(start, end)}...';
      } else {
        text = '${text.substring(0, 200)}...';
      }
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Búsqueda Avanzada'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAllNotes,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: GlassBackground(
        child: Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar en títulos y contenido...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _applyFilters();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _applyFilters();
                    },
                  ),
                  const SizedBox(height: 12),

                  // Filtros rápidos
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Filtros'),
                          avatar: const Icon(
                            Icons.filter_list_rounded,
                            size: 18,
                          ),
                          onSelected: (_) => _showFiltersDialog(),
                        ),
                        const SizedBox(width: 8),

                        if (_dateRange != null)
                          FilterChip(
                            label: Text(
                              '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}',
                            ),
                            onSelected: (_) {},
                            onDeleted: () {
                              setState(() => _dateRange = null);
                              _applyFilters();
                            },
                            deleteIcon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                            ),
                          ),

                        if (_selectedTags.isNotEmpty)
                          ..._selectedTags.map(
                            (tag) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: FilterChip(
                                label: Text('#$tag'),
                                onSelected: (_) {},
                                onDeleted: () {
                                  setState(() => _selectedTags.remove(tag));
                                  _applyFilters();
                                },
                                deleteIcon: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Estadísticas
                  if (_filteredNotes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatChip(
                            icon: Icons.description_rounded,
                            label: '${_filteredNotes.length} notas',
                          ),
                          _StatChip(
                            icon: Icons.text_fields_rounded,
                            label: '$_totalWords palabras',
                          ),
                          _StatChip(
                            icon: Icons.font_download_rounded,
                            label: '$_totalCharacters chars',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Resultados
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredNotes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text('No se encontraron resultados'),
                          const SizedBox(height: 8),
                          Text(
                            'Intenta con otros términos o filtros',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = _filteredNotes[index];
                        return _buildNoteCard(note);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final title = note['title']?.toString() ?? 'Sin título';
    final content = note['content']?.toString() ?? '';
    final tags =
        (note['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];
    final updated = note['updated'] as DateTime?;
    final id = note['id'] as String;

    final preview = _highlightText(content, _searchQuery);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pushNamed(context, '/note-editor', arguments: id);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_sortBy == 'relevance' && _searchQuery.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_calculateRelevance(note)} pts',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),

              if (preview.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  preview,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],

              if (updated != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.update_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(updated),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 30) return 'Hace ${diff.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showFiltersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtros Avanzados'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ordenar por
                const Text(
                  'Ordenar por:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Actualización'),
                      selected: _sortBy == 'updated',
                      onSelected: (_) => setState(() => _sortBy = 'updated'),
                    ),
                    ChoiceChip(
                      label: const Text('Creación'),
                      selected: _sortBy == 'created',
                      onSelected: (_) => setState(() => _sortBy = 'created'),
                    ),
                    ChoiceChip(
                      label: const Text('Título'),
                      selected: _sortBy == 'title',
                      onSelected: (_) => setState(() => _sortBy = 'title'),
                    ),
                    ChoiceChip(
                      label: const Text('Relevancia'),
                      selected: _sortBy == 'relevance',
                      onSelected: (_) => setState(() => _sortBy = 'relevance'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),

                // Opciones de búsqueda
                const Text(
                  'Opciones:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                CheckboxListTile(
                  title: const Text('Sensible a mayúsculas'),
                  value: _caseSensitive,
                  onChanged: (value) =>
                      setState(() => _caseSensitive = value ?? false),
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Palabra completa'),
                  value: _wholeWord,
                  onChanged: (value) =>
                      setState(() => _wholeWord = value ?? false),
                  dense: true,
                ),

                const SizedBox(height: 16),
                const Divider(),

                // Tags
                const Text(
                  'Tags:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _getAllTags()
                      .map(
                        (tag) => FilterChip(
                          label: Text('#$tag'),
                          selected: _selectedTags.contains(tag),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: 16),
                const Divider(),

                // Rango de fechas
                const Text(
                  'Rango de fechas:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(
                    _dateRange == null
                        ? 'Seleccionar rango'
                        : '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}',
                  ),
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _dateRange,
                    );
                    if (range != null) {
                      setState(() => _dateRange = range);
                    }
                  },
                ),
                if (_dateRange != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Limpiar'),
                    onPressed: () => setState(() => _dateRange = null),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedTags.clear();
                _dateRange = null;
                _sortBy = 'updated';
                _caseSensitive = false;
                _wholeWord = false;
              });
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Limpiar todo'),
          ),
          FilledButton(
            onPressed: () {
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
