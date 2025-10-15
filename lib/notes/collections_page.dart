import 'package:flutter/material.dart';
import '../widgets/glass.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  late Future<void> _init;
  List<Map<String, dynamic>> _collections = [];
  bool _busy = false;
  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _init = _load();
  }

  Future<void> _load() async {
    final cols = await FirestoreService.instance.listCollections(uid: _uid);
    setState(() => _collections = cols);
  }

  Future<void> _create() async {
    final nameController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva colección'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nombre'),
          autofocus: true,
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
    if (ok != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      await FirestoreService.instance.createCollection(
        uid: _uid,
        data: {'name': name},
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(Map<String, dynamic> c) async {
    final nameController = TextEditingController(
      text: c['name']?.toString() ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar colección'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nombre'),
          autofocus: true,
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
    if (ok != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      await FirestoreService.instance.updateCollection(
        uid: _uid,
        collectionId: c['id'].toString(),
        data: {'name': name},
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar colección'),
        content: Text(
          '¿Eliminar "${c['name'] ?? c['id']}"? No se borran notas, solo la colección.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await FirestoreService.instance.deleteCollection(
        uid: _uid,
        collectionId: c['id'].toString(),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Colecciones'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.create_new_folder_rounded),
            tooltip: 'Nueva colección',
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
            if (_collections.isEmpty) {
              return const Center(child: Text('Sin colecciones'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, i) {
                final c = _collections[i];
                return ListTile(
                  leading: const Icon(Icons.folder_rounded),
                  title: Text(c['name']?.toString() ?? c['id'].toString()),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'rename') _rename(c);
                      if (v == 'delete') _delete(c);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: _collections.length,
            );
          },
        ),
      ),
    );
  }
}
