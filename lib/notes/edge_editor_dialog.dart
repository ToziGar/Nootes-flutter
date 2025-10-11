import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class EdgeEditorResult {
  final String? edgeId;
  final bool deleted;
  EdgeEditorResult({this.edgeId, this.deleted = false});
}

class EdgeEditorDialog extends StatefulWidget {
  final String uid;
  final String? edgeId; // null for create
  final String? fromNoteId;
  final String? toNoteId;

  const EdgeEditorDialog({
    super.key,
    required this.uid,
    this.edgeId,
    this.fromNoteId,
    this.toNoteId,
  });

  @override
  State<EdgeEditorDialog> createState() => _EdgeEditorDialogState();
}

class _EdgeEditorDialogState extends State<EdgeEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _labelCtrl = TextEditingController();
  double _strength = 0.8;
  String _type = 'manual';
  bool _bidirectional = false;
  bool _syncWithLegacyLinks = true; // New option
  bool _loading = false;
  List<Map<String, dynamic>> _availableNotes = [];
  String? _selectedFromId;
  String? _selectedToId;

  @override
  void initState() {
    super.initState();
    _selectedFromId = widget.fromNoteId;
    _selectedToId = widget.toNoteId;
    if (widget.fromNoteId != null) _fromCtrl.text = widget.fromNoteId!;
    if (widget.toNoteId != null) _toCtrl.text = widget.toNoteId!;
    _loadNotes();
    if (widget.edgeId != null) _loadEdge();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    try {
      final notes = await FirestoreService.instance.listNotes(uid: widget.uid);
      setState(() => _availableNotes = notes);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadEdge() async {
    setState(() => _loading = true);
    try {
      final docs = await FirestoreService.instance.listEdgeDocs(
        uid: widget.uid,
      );
      final match = docs.firstWhere(
        (d) => d['id'] == widget.edgeId,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        _fromCtrl.text = match['from']?.toString() ?? _fromCtrl.text;
        _toCtrl.text = match['to']?.toString() ?? _toCtrl.text;
        _labelCtrl.text = match['label']?.toString() ?? '';
        _strength = (match['strength'] is num)
            ? (match['strength'] as num).toDouble()
            : _strength;
        _type = match['type']?.toString() ?? _type;
        _bidirectional = match['bidirectional'] == true;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final fromId = _selectedFromId ?? _fromCtrl.text.trim();
    final toId = _selectedToId ?? _toCtrl.text.trim();

    final data = {
      'from': fromId,
      'to': toId,
      'label': _labelCtrl.text.trim(),
      'strength': _strength,
      'type': _type,
      'bidirectional': _bidirectional,
    };

    try {
      if (widget.edgeId == null) {
        final id = await FirestoreService.instance.createEdgeDoc(
          uid: widget.uid,
          data: data,
        );

        // Sync with legacy links if enabled
        if (_syncWithLegacyLinks) {
          await FirestoreService.instance.addLink(
            uid: widget.uid,
            fromNoteId: fromId,
            toNoteId: toId,
          );
          if (_bidirectional) {
            await FirestoreService.instance.addLink(
              uid: widget.uid,
              fromNoteId: toId,
              toNoteId: fromId,
            );
          }
        }

        if (mounted)
          Navigator.of(
            context,
          ).pop(EdgeEditorResult(edgeId: id, deleted: false));
      } else {
        await FirestoreService.instance.updateEdgeDoc(
          uid: widget.uid,
          edgeId: widget.edgeId!,
          data: data,
        );
        if (mounted)
          Navigator.of(
            context,
          ).pop(EdgeEditorResult(edgeId: widget.edgeId, deleted: false));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error guardando arista: $e')));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete() async {
    if (widget.edgeId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar arista'),
        content: const Text('¿Eliminar esta arista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      await FirestoreService.instance.deleteEdgeDoc(
        uid: widget.uid,
        edgeId: widget.edgeId!,
      );

      // Also remove from legacy links if sync enabled
      if (_syncWithLegacyLinks) {
        final fromId = _selectedFromId ?? _fromCtrl.text.trim();
        final toId = _selectedToId ?? _toCtrl.text.trim();
        await FirestoreService.instance.removeLink(
          uid: widget.uid,
          fromNoteId: fromId,
          toNoteId: toId,
        );
        if (_bidirectional) {
          await FirestoreService.instance.removeLink(
            uid: widget.uid,
            fromNoteId: toId,
            toNoteId: fromId,
          );
        }
      }

      if (mounted)
        Navigator.of(
          context,
        ).pop(EdgeEditorResult(edgeId: widget.edgeId, deleted: true));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error eliminando: $e')));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.edgeId == null ? 'Crear enlace' : 'Editar enlace'),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // From note selection
                    DropdownButtonFormField<String>(
                      initialValue: _selectedFromId,
                      decoration: const InputDecoration(labelText: 'Desde'),
                      items: _availableNotes.map((note) {
                        final id = note['id'].toString();
                        final title = note['title']?.toString() ?? 'Sin título';
                        return DropdownMenuItem(
                          value: id,
                          child: Text(title, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() {
                        _selectedFromId = v;
                        _fromCtrl.text = v ?? '';
                      }),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 8),

                    // To note selection
                    DropdownButtonFormField<String>(
                      initialValue: _selectedToId,
                      decoration: const InputDecoration(labelText: 'Hacia'),
                      items: _availableNotes.map((note) {
                        final id = note['id'].toString();
                        final title = note['title']?.toString() ?? 'Sin título';
                        return DropdownMenuItem(
                          value: id,
                          child: Text(title, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() {
                        _selectedToId = v;
                        _toCtrl.text = v ?? '';
                      }),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _labelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Etiqueta (opcional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Fuerza'),
                        Expanded(
                          child: Slider(
                            value: _strength,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (v) => setState(() => _strength = v),
                          ),
                        ),
                        Text('${(_strength * 100).toInt()}%'),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      items: [
                        const DropdownMenuItem(
                          value: 'manual',
                          child: Text('🔗 Manual'),
                        ),
                        const DropdownMenuItem(
                          value: 'semantic',
                          child: Text('🧠 Semántico'),
                        ),
                        const DropdownMenuItem(
                          value: 'thematic',
                          child: Text('📝 Temático'),
                        ),
                        const DropdownMenuItem(
                          value: 'strong',
                          child: Text('💪 Fuerte'),
                        ),
                        const DropdownMenuItem(
                          value: 'weak',
                          child: Text('🔸 Débil'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? _type),
                      decoration: const InputDecoration(labelText: 'Tipo'),
                    ),
                    CheckboxListTile(
                      value: _bidirectional,
                      onChanged: (v) =>
                          setState(() => _bidirectional = v ?? false),
                      title: const Text('Bidireccional'),
                    ),
                    CheckboxListTile(
                      value: _syncWithLegacyLinks,
                      onChanged: (v) =>
                          setState(() => _syncWithLegacyLinks = v ?? true),
                      title: const Text('Sincronizar con enlaces legacy'),
                      subtitle: const Text(
                        'Mantiene compatibilidad con sistema anterior',
                      ),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        if (widget.edgeId != null)
          TextButton(
            onPressed: _delete,
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
