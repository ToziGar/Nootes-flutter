import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'services/sharing_service.dart';
import 'services/firestore_service.dart';
import 'theme/app_theme.dart';

class PublicNotePage extends StatefulWidget {
  const PublicNotePage({super.key, required this.token});
  final String token;
  @override
  State<PublicNotePage> createState() => _PublicNotePageState();
}

class _PublicNotePageState extends State<PublicNotePage> {
  Map<String, dynamic>? _note;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resolved = await SharingService().resolvePublicToken(widget.token);
      if (resolved == null) {
        setState(() { _notFound = true; _loading = false; });
        return;
      }
      final note = await FirestoreService.instance.getNote(
        uid: resolved['ownerId']!,
        noteId: resolved['noteId']!,
      );
      if (!mounted) return;
      if (note == null || note['shareEnabled'] != true || note['shareToken'] != widget.token) {
        setState(() { _notFound = true; _loading = false; });
      } else {
        setState(() { _note = note; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _notFound = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _note?['title']?.toString() ?? 'Nota';
    final content = _note?['content']?.toString() ?? '';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_notFound ? 'No disponible' : title),
        actions: [
          if (!_loading && !_notFound)
            IconButton(
              tooltip: 'Recargar',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          if (!_loading && !_notFound)
            IconButton(
              tooltip: 'Compartir nota',
              onPressed: () {
                final title = _note?['title']?.toString() ?? 'Nota';
                final content = _note?['content']?.toString() ?? '';
                SharePlus.instance.share(
                  ShareParams(
                    text: '$title\n\n$content',
                    subject: 'Compartir nota: $title',
                  ),
                );
              },
              icon: const Icon(Icons.share),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notFound
              ? const Center(child: Text('Esta nota pública no está disponible.'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 16),
                        SelectableText(content, style: const TextStyle(fontSize: 15, height: 1.4)),
                        const SizedBox(height: 40),
                        Divider(color: AppColors.borderColor),
                        const SizedBox(height: 8),
                        Text('Vista pública de solo lectura', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
    );
  }
}
