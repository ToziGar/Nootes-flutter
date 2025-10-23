import 'package:flutter/material.dart';
import '../widgets/glass.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});
  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  late Future<void> _init;
  List<Map<String, dynamic>> _items = [];
  String get _uid => AuthService.instance.currentUser!.uid;
  @override
  void initState() {
    super.initState();
    _init = _load();
  }

  Future<void> _load() async {
    final list = await FirestoreService.instance.listTrashedNotesSummary(
      uid: _uid,
    );
    setState(() => _items = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Papelera'),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Vaciar papelera'),
                    content: const Text(
                      '¿Eliminar permanentemente todas las notas de la papelera?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Vaciar'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  for (final n in _items) {
                    await FirestoreService.instance.purgeNote(
                      uid: _uid,
                      noteId: n['id'].toString(),
                    );
                  }
                  await _load();
                }
              },
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('Vaciar'),
            ),
        ],
      ),
      body: GlassBackground(
        child: FutureBuilder<void>(
          future: _init,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_items.isEmpty) {
              return const Center(child: Text('Papelera vacía'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = _items[i];
                final title = (n['title']?.toString() ?? '').isEmpty
                    ? n['id'].toString()
                    : n['title'].toString();
                return ListTile(
                  leading: const Icon(Icons.note_rounded),
                  title: Text(title),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await FirestoreService.instance.restoreNote(
                            uid: _uid,
                            noteId: n['id'].toString(),
                          );
                          await _load();
                        },
                        child: const Text('Restaurar'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          await FirestoreService.instance.purgeNote(
                            uid: _uid,
                            noteId: n['id'].toString(),
                          );
                          await _load();
                        },
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
