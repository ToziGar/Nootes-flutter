import 'package:flutter/material.dart';
import '../theme/color_utils.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';

/// Panel que muestra las notas que enlazan a la nota actual (backlinks)
class BacklinksPanel extends StatefulWidget {
  final String uid;
  final String noteId;
  final Function(String noteId) onNoteOpen;

  const BacklinksPanel({
    super.key,
    required this.uid,
    required this.noteId,
    required this.onNoteOpen,
  });

  @override
  State<BacklinksPanel> createState() => _BacklinksPanelState();
}

class _BacklinksPanelState extends State<BacklinksPanel> {
  List<Map<String, dynamic>> _backlinks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBacklinks();
  }

  @override
  void didUpdateWidget(BacklinksPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId) {
      _loadBacklinks();
    }
  }

  Future<void> _loadBacklinks() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // Obtener IDs de notas que enlazan a esta
      final linkedNoteIds = await FirestoreService.instance.listIncomingLinks(
        uid: widget.uid,
        noteId: widget.noteId,
      );

      // Cargar información completa de las notas
      final backlinksData = <Map<String, dynamic>>[];
      for (final id in linkedNoteIds) {
        final note = await FirestoreService.instance.getNote(
          uid: widget.uid,
          noteId: id,
        );
        if (note != null) {
          backlinksData.add(note);
        }
      }

      if (!mounted) return;
      setState(() {
        _backlinks = backlinksData;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error cargando backlinks: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppColors.space24),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_backlinks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppColors.space16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppColors.space12),
            Text(
              'Sin backlinks',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: AppColors.space4),
            Text(
              'Ninguna nota enlaza aquí',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppColors.space12),
          child: Row(
            children: [
              Icon(
                Icons.link_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppColors.space8),
              Text(
                'Backlinks (${_backlinks.length})',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.borderColor),
        Expanded(
          child: ListView.builder(
            itemCount: _backlinks.length,
            itemBuilder: (context, index) {
              final backlink = _backlinks[index];
              return _buildBacklinkItem(backlink);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBacklinkItem(Map<String, dynamic> note) {
    final title = (note['title'] as String?) ?? 'Sin título';
    final noteId = note['id'] as String;
    final tags = List<String>.from((note['tags'] as List?)?.whereType<String>() ?? []);
    final content = (note['content'] as String?) ?? '';
    
    // Extraer un pequeño preview del contenido
    final preview = content.length > 100 ? '${content.substring(0, 100)}...' : content;

    return InkWell(
      onTap: () => widget.onNoteOpen(noteId),
      child: Container(
        padding: const EdgeInsets.all(AppColors.space12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.borderColor.withOpacityCompat(0.3),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.note_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: AppColors.space8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AppColors.textMuted,
                ),
              ],
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: AppColors.space8),
              Text(
                preview,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: AppColors.space8),
              Wrap(
                spacing: AppColors.space4,
                runSpacing: AppColors.space4,
                children: tags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppColors.space8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacityCompat(0.1),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(
                        color: AppColors.primary.withOpacityCompat(0.2),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
