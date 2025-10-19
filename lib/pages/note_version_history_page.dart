import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/versioning_service.dart';
import '../services/logging_service.dart';
import '../widgets/glass.dart';

/// Página que muestra el historial de versiones de una nota
class NoteVersionHistoryPage extends StatefulWidget {
  final String noteId;
  final String noteTitle;

  const NoteVersionHistoryPage({
    super.key,
    required this.noteId,
    required this.noteTitle,
  });

  @override
  State<NoteVersionHistoryPage> createState() =>
      _NoteVersionHistoryPageState();
}

class _NoteVersionHistoryPageState extends State<NoteVersionHistoryPage> {
  final _versioningService = VersioningService();
  List<Map<String, dynamic>>? _versions;
  bool _loading = true;
  String? _error;
  DateTime? _lastFetchedCreatedAt;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadVersions();
    LoggingService.logUserAction(
      'version_history_opened',
      parameters: {'noteId': widget.noteId},
    );
  }

  Future<void> _loadVersions({bool loadMore = false}) async {
    if (loadMore) {
      setState(() {
        _loadingMore = true;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final versions = await _versioningService.listVersions(
        noteId: widget.noteId,
        limit: 50,
        startAfter: loadMore ? _lastFetchedCreatedAt : null,
      );

      if (mounted) {
        setState(() {
          if (loadMore) {
            _versions = [...?_versions, ...versions];
          } else {
            _versions = versions;
          }
          if (versions.isNotEmpty) {
            final last = versions.last;
            _lastFetchedCreatedAt =
                (last['createdAt'] as Timestamp).toDate();
          }
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error al cargar historial de versiones',
        tag: 'VersionHistory',
        error: e,
        stackTrace: stackTrace,
        data: {'noteId': widget.noteId},
      );

      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
          _loadingMore = false;
        });

        // Mostrar SnackBar de error cuando ya hay datos en pantalla
        if (_versions != null && _versions!.isNotEmpty) {
          final msg = loadMore
              ? 'Error al cargar más versiones'
              : 'Error al actualizar historial';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _restoreVersion(Map<String, dynamic> version) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Restaurar versión?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esto sobrescribirá el contenido actual de la nota.',
            ),
            const SizedBox(height: 12),
            Text(
              'Versión: ${DateFormat.yMd().add_jm().format((version['createdAt'] as Timestamp).toDate())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if ((version['metadata'] as Map?)?['reason'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Razón: ${(version['metadata'] as Map)['reason']}',
                style: Theme.of(context).textTheme.bodySmall,
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
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Mostrar indicador de carga
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final restored = await _versioningService.restoreVersion(
        noteId: widget.noteId,
        versionId: version['id'],
      );

      if (restored != null) {
        // La versión ya fue restaurada en Firestore por el servicio

        LoggingService.info(
          'Versión restaurada exitosamente',
          tag: 'VersionHistory',
          data: {
            'noteId': widget.noteId,
            'versionId': version['id'],
          },
        );

        if (mounted) {
          Navigator.pop(context); // Cerrar diálogo de carga
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Versión restaurada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Regresar con resultado
        }
      } else {
        throw Exception('Versión no encontrada');
      }
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error al restaurar versión',
        tag: 'VersionHistory',
        error: e,
        stackTrace: stackTrace,
        data: {
          'noteId': widget.noteId,
          'versionId': version['id'],
        },
      );

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _previewVersion(Map<String, dynamic> version) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vista previa - ${version['title'] ?? 'Sin título'}'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Fecha', DateFormat.yMd().add_jm().format(
                  (version['createdAt'] as Timestamp).toDate(),
                )),
                if ((version['metadata'] as Map?)?['reason'] != null)
                  _buildInfoRow('Razón', (version['metadata'] as Map)['reason']),
                const Divider(height: 24),
                Text(
                  'Contenido:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    version['content']?.toString() ?? 'Sin contenido',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                if (version['tags'] != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Etiquetas:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: (version['tags'] as List?)
                            ?.map((tag) => Chip(label: Text(tag.toString())))
                            .toList() ??
                        [],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _restoreVersion(version);
            },
            icon: const Icon(Icons.restore),
            label: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if ((_versions == null || _versions!.isEmpty) && _loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && (_versions == null || _versions!.isEmpty)) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadVersions,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else if (_versions == null || _versions!.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay versiones guardadas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Las versiones se crean automáticamente\ncuando guardas cambios importantes',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    } else {
      final listView = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _versions!.length + 1,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _versions!.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : OutlinedButton.icon(
                        onPressed: () => _loadVersions(loadMore: true),
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Cargar más'),
                      ),
              ),
            );
          }
          final version = _versions![index];
          final date = (version['createdAt'] as Timestamp).toDate();
          final title = version['title']?.toString() ?? 'Sin título';
          final reason = (version['metadata'] as Map?)?['reason'] ?? 'Versión automática';
          final contentPreview = version['content']?.toString() ?? '';
          final previewText = contentPreview.length > 100
              ? '${contentPreview.substring(0, 100)}...'
              : contentPreview;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              child: Text('${index + 1}'),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  DateFormat.yMd().add_jm().format(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (previewText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    previewText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility),
                  tooltip: 'Vista previa',
                  onPressed: () => _previewVersion(version),
                ),
                IconButton(
                  icon: const Icon(Icons.restore),
                  tooltip: 'Restaurar esta versión',
                  onPressed: () => _restoreVersion(version),
                ),
              ],
            ),
            onTap: () => _previewVersion(version),
          );
        },
      );

      body = RefreshIndicator(
        onRefresh: () => _loadVersions(),
        child: listView,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historial de Versiones'),
            Text(
              widget.noteTitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadVersions,
          ),
        ],
      ),
      body: GlassBackground(
        child: Stack(
          children: [
            Positioned.fill(child: body),
            // Overlay de carga en refresh (mantiene lista visible)
            if (_loading && _versions != null && _versions!.isNotEmpty)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
