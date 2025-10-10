import 'package:flutter/material.dart';
import '../services/note_links_parser.dart';
import '../widgets/note_autocomplete_overlay.dart';
import '../services/firestore_service.dart';
import 'markdown_editor.dart';

/// Wrapper del MarkdownEditor que agrega funcionalidad de autocompletado [[nota]]
class MarkdownEditorWithLinks extends StatefulWidget {
  const MarkdownEditorWithLinks({
    super.key,
    required this.controller,
    required this.uid,
    this.onChanged,
    this.onLinksChanged,
    this.onNoteOpen,
    this.minLines = 18,
    this.splitEnabled = true,
    this.forceSplit = false,
    this.showSplitToggle = true,
    this.previewTitle,
  });

  final TextEditingController controller;
  final String uid;
  final ValueChanged<String>? onChanged;
  final ValueChanged<List<String>>? onLinksChanged; // Callback cuando cambian los links
  final void Function(String noteId)? onNoteOpen; // Callback para abrir nota
  final int minLines;
  final bool splitEnabled;
  final bool forceSplit;
  final bool showSplitToggle;
  final String? previewTitle;

  @override
  State<MarkdownEditorWithLinks> createState() => _MarkdownEditorWithLinksState();
}

class _MarkdownEditorWithLinksState extends State<MarkdownEditorWithLinks> {
  OverlayEntry? _overlayEntry;
  bool _showingAutocomplete = false;
  List<NoteSuggestion> _suggestions = [];
  List<NoteSuggestion> _allNotes = [];
  String _currentQuery = '';
  int? _linkStartPosition;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _loadAllNotes();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _hideAutocomplete();
    super.dispose();
  }

  Future<void> _loadAllNotes() async {
    try {
      final notes = await FirestoreService.instance.listNotesSummary(uid: widget.uid);
      if (!mounted) return;
      setState(() {
        _allNotes = notes.map((n) => NoteSuggestion.fromMap(n)).toList();
      });
    } catch (e) {
      debugPrint('❌ Error cargando notas para autocompletado: $e');
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    // Verificar si hay un link incompleto
    if (NoteLinksParser.hasIncompleteLink(text) && NoteLinksParser.isCursorInLink(text, cursorPos)) {
      final query = NoteLinksParser.getIncompleteLinkQuery(text) ?? '';
      _linkStartPosition = NoteLinksParser.getCurrentLinkStart(text, cursorPos);
      _showAutocomplete(query);
    } else {
      _hideAutocomplete();
    }

    // Notificar cambios en los links
    _notifyLinksChanged(text);
  }

  void _notifyLinksChanged(String text) {
    // Extraer todos los [[enlaces]] y buscar sus IDs
    final linkedNames = NoteLinksParser.extractUniqueLinkedNoteNames(text);
    final linkedIds = <String>[];

    for (final name in linkedNames) {
      // Buscar la nota por título
      final note = _allNotes.where((n) => n.title.toLowerCase() == name.toLowerCase()).firstOrNull;
      if (note != null) {
        linkedIds.add(note.id);
      }
    }

    widget.onLinksChanged?.call(linkedIds);
  }

  void _showAutocomplete(String query) {
    setState(() {
      _currentQuery = query;
      _suggestions = _filterSuggestions(query);
    });

    if (!_showingAutocomplete) {
      _showingAutocomplete = true;
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _hideAutocomplete() {
    if (_showingAutocomplete) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _showingAutocomplete = false;
      setState(() {
        _suggestions = [];
        _currentQuery = '';
        _linkStartPosition = null;
      });
    }
  }

  List<NoteSuggestion> _filterSuggestions(String query) {
    if (query.isEmpty) {
      return _allNotes.take(10).toList();
    }

    final q = query.toLowerCase();
    final filtered = _allNotes.where((note) {
      return note.title.toLowerCase().contains(q) ||
             note.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();

    // Ordenar por relevancia (coincidencia al inicio)
    filtered.sort((a, b) {
      final aStarts = a.title.toLowerCase().startsWith(q);
      final bStarts = b.title.toLowerCase().startsWith(q);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return filtered.take(10).toList();
  }

  void _onSelectSuggestion(NoteSuggestion suggestion) {
    if (_linkStartPosition == null) {
      _hideAutocomplete();
      return;
    }

    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    // Encontrar el final del link incompleto
    final afterStart = text.substring(_linkStartPosition!);
    final closePos = afterStart.indexOf(']]');
    final endPos = closePos == -1 ? cursorPos : _linkStartPosition! + closePos;

    // Reemplazar [[texto_incompleto con [[título_nota]]
    final replacement = '[[${suggestion.title}]]';
    final newText = text.replaceRange(_linkStartPosition!, endPos, replacement);

    widget.controller.value = widget.controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: _linkStartPosition! + replacement.length),
      composing: TextRange.empty,
    );

    _hideAutocomplete();
  }

  OverlayEntry _createOverlayEntry() {
    // Calcular posición del overlay cerca del cursor
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return OverlayEntry(builder: (_) => const SizedBox.shrink());
    }

    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx + 50,
        top: offset.dy + 100, // Ajustar según necesidad
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: NoteAutocompleteOverlay(
            query: _currentQuery,
            suggestions: _suggestions,
            onSelect: _onSelectSuggestion,
            onDismiss: _hideAutocomplete,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Crear índice de títulos -> IDs para los links
    final wikiIndex = <String, String>{};
    for (final note in _allNotes) {
      wikiIndex[note.title] = note.id;
    }

    return MarkdownEditor(
      controller: widget.controller,
      onChanged: widget.onChanged,
      minLines: widget.minLines,
      splitEnabled: widget.splitEnabled,
      forceSplit: widget.forceSplit,
      showSplitToggle: widget.showSplitToggle,
      previewTitle: widget.previewTitle,
      wikiIndex: wikiIndex,
      onOpenNote: widget.onNoteOpen,
    );
  }
}
