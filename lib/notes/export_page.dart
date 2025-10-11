import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/glass.dart';

/// Sistema de exportación avanzada de notas
class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  late Future<void> _init;
  List<Map<String, dynamic>> _notes = [];
  Set<String> _selectedNoteIds = {};
  bool _selectAll = false;
  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _init = _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await FirestoreService.instance.listNotes(uid: _uid);
    setState(() => _notes = notes);
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedNoteIds = _notes.map((n) => n['id'].toString()).toSet();
      } else {
        _selectedNoteIds.clear();
      }
    });
  }

  void _toggleNote(String id) {
    setState(() {
      if (_selectedNoteIds.contains(id)) {
        _selectedNoteIds.remove(id);
      } else {
        _selectedNoteIds.add(id);
      }
      _selectAll = _selectedNoteIds.length == _notes.length;
    });
  }

  Future<void> _exportMarkdown() async {
    if (_selectedNoteIds.isEmpty) {
      _showMessage('Selecciona al menos una nota');
      return;
    }

    final selectedNotes = _notes
        .where((n) => _selectedNoteIds.contains(n['id'].toString()))
        .toList();
    final buffer = StringBuffer();

    buffer.writeln('# Exportación de Notas - Nootes');
    buffer.writeln('Fecha de exportación: ${DateTime.now().toString()}');
    buffer.writeln('Total de notas: ${selectedNotes.length}');
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('');

    for (var note in selectedNotes) {
      final title = note['title']?.toString() ?? 'Sin título';
      final content = note['content']?.toString() ?? '';
      final tags = note['tags'] as List?;
      final createdAt = note['createdAt']?.toString() ?? '';

      buffer.writeln('## $title');
      buffer.writeln('');
      if (tags != null && tags.isNotEmpty) {
        buffer.writeln('**Etiquetas:** ${tags.join(", ")}');
      }
      if (createdAt.isNotEmpty) {
        buffer.writeln('**Creada:** $createdAt');
      }
      buffer.writeln('');
      buffer.writeln(content);
      buffer.writeln('');
      buffer.writeln('---');
      buffer.writeln('');
    }

    _showExportDialog(
      title: 'Exportar como Markdown',
      content: buffer.toString(),
      filename: 'notas_${DateTime.now().millisecondsSinceEpoch}.md',
    );
  }

  Future<void> _exportJSON() async {
    if (_selectedNoteIds.isEmpty) {
      _showMessage('Selecciona al menos una nota');
      return;
    }

    final selectedNotes = _notes
        .where((n) => _selectedNoteIds.contains(n['id'].toString()))
        .toList();

    final exportData = {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'noteCount': selectedNotes.length,
      'notes': selectedNotes
          .map(
            (note) => {
              'id': note['id'],
              'title': note['title'],
              'content': note['content'],
              'tags': note['tags'],
              'createdAt': note['createdAt'],
              'updatedAt': note['updatedAt'],
              'pinned': note['pinned'],
              'links': note['links'],
            },
          )
          .toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    _showExportDialog(
      title: 'Exportar como JSON',
      content: jsonString,
      filename: 'backup_notas_${DateTime.now().millisecondsSinceEpoch}.json',
    );
  }

  Future<void> _exportHTML() async {
    if (_selectedNoteIds.isEmpty) {
      _showMessage('Selecciona al menos una nota');
      return;
    }

    final selectedNotes = _notes
        .where((n) => _selectedNoteIds.contains(n['id'].toString()))
        .toList();
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="es">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8">');
    buffer.writeln(
      '  <meta name="viewport" content="width=device-width, initial-scale=1.0">',
    );
    buffer.writeln('  <title>Notas Exportadas - Nootes</title>');
    buffer.writeln('  <style>');
    buffer.writeln(
      '    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 900px; margin: 0 auto; padding: 20px; background: #0f172a; color: #e2e8f0; }',
    );
    buffer.writeln(
      '    .header { border-bottom: 2px solid #3b82f6; padding-bottom: 20px; margin-bottom: 30px; }',
    );
    buffer.writeln(
      '    .note { background: #1e293b; border-radius: 8px; padding: 24px; margin-bottom: 24px; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }',
    );
    buffer.writeln(
      '    .note-title { color: #3b82f6; font-size: 24px; font-weight: bold; margin: 0 0 12px 0; }',
    );
    buffer.writeln(
      '    .note-meta { color: #94a3b8; font-size: 14px; margin-bottom: 16px; }',
    );
    buffer.writeln(
      '    .note-tags { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 16px; }',
    );
    buffer.writeln(
      '    .tag { background: #3b82f6; color: white; padding: 4px 12px; border-radius: 16px; font-size: 12px; }',
    );
    buffer.writeln(
      '    .note-content { line-height: 1.6; white-space: pre-wrap; }',
    );
    buffer.writeln(
      '    pre { background: #0f172a; padding: 12px; border-radius: 4px; overflow-x: auto; }',
    );
    buffer.writeln(
      '    code { background: #0f172a; padding: 2px 6px; border-radius: 3px; }',
    );
    buffer.writeln('  </style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('  <div class="header">');
    buffer.writeln('    <h1>📝 Notas Exportadas</h1>');
    buffer.writeln('    <p>Fecha de exportación: ${DateTime.now()}</p>');
    buffer.writeln('    <p>Total de notas: ${selectedNotes.length}</p>');
    buffer.writeln('  </div>');

    for (var note in selectedNotes) {
      final title = note['title']?.toString() ?? 'Sin título';
      final content = note['content']?.toString() ?? '';
      final tags = note['tags'] as List?;
      final createdAt = note['createdAt']?.toString() ?? '';

      buffer.writeln('  <div class="note">');
      buffer.writeln('    <h2 class="note-title">$title</h2>');

      if (tags != null && tags.isNotEmpty) {
        buffer.writeln('    <div class="note-tags">');
        for (var tag in tags) {
          buffer.writeln('      <span class="tag">$tag</span>');
        }
        buffer.writeln('    </div>');
      }

      if (createdAt.isNotEmpty) {
        buffer.writeln('    <div class="note-meta">Creada: $createdAt</div>');
      }

      buffer.writeln('    <div class="note-content">');
      buffer.writeln(_escapeHtml(content));
      buffer.writeln('    </div>');
      buffer.writeln('  </div>');
    }

    buffer.writeln('</body>');
    buffer.writeln('</html>');

    _showExportDialog(
      title: 'Exportar como HTML',
      content: buffer.toString(),
      filename: 'notas_${DateTime.now().millisecondsSinceEpoch}.html',
    );
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  void _showExportDialog({
    required String title,
    required String content,
    required String filename,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Archivo: $filename',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Tamaño: ${(content.length / 1024).toStringAsFixed(2)} KB',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      content,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF3B82F6),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Copia el contenido y guárdalo en un archivo',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportar Notas'),
        actions: [
          if (_selectedNoteIds.isNotEmpty)
            TextButton.icon(
              onPressed: _toggleSelectAll,
              icon: Icon(
                _selectAll ? Icons.deselect : Icons.select_all_rounded,
              ),
              label: Text(_selectAll ? 'Deseleccionar' : 'Todas'),
            ),
        ],
      ),
      body: GlassBackground(
        child: FutureBuilder(
          future: _init,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                // Formato selection cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Formato de Exportación',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ExportFormatCard(
                              icon: Icons.code_rounded,
                              title: 'Markdown',
                              description: 'Formato universal',
                              color: const Color(0xFF3B82F6),
                              onTap: _exportMarkdown,
                              enabled: _selectedNoteIds.isNotEmpty,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ExportFormatCard(
                              icon: Icons.data_object_rounded,
                              title: 'JSON',
                              description: 'Backup completo',
                              color: const Color(0xFF10B981),
                              onTap: _exportJSON,
                              enabled: _selectedNoteIds.isNotEmpty,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ExportFormatCard(
                              icon: Icons.html_rounded,
                              title: 'HTML',
                              description: 'Vista web',
                              color: const Color(0xFFF59E0B),
                              onTap: _exportHTML,
                              enabled: _selectedNoteIds.isNotEmpty,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Selected count
                if (_selectedNoteIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF3B82F6),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedNoteIds.length} ${_selectedNoteIds.length == 1 ? 'nota seleccionada' : 'notas seleccionadas'}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                // Notes list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      final id = note['id'].toString();
                      final title = note['title']?.toString() ?? 'Sin título';
                      final tags = note['tags'] as List?;
                      final selected = _selectedNoteIds.contains(id);

                      return Card(
                        color: selected
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                            : null,
                        child: CheckboxListTile(
                          value: selected,
                          onChanged: (_) => _toggleNote(id),
                          title: Text(title),
                          subtitle: tags != null && tags.isNotEmpty
                              ? Wrap(
                                  spacing: 4,
                                  children: tags.take(3).map((tag) {
                                    return Chip(
                                      label: Text(
                                        tag.toString(),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExportFormatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _ExportFormatCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: enabled
          ? color.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.05),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: enabled ? color : Colors.white30, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: enabled ? Colors.white : Colors.white60,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: enabled ? Colors.white70 : Colors.white30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
