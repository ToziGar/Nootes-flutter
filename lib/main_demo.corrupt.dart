import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nootes/services/providers.dart';
import 'package:nootes/widgets/sync_status_widget.dart';
import 'package:nootes/widgets/dead_letter_widget.dart';
import 'package:nootes/services/firestore_dev.dart';
import 'package:nootes/domain/note.dart';

void main() {
  runApp(ProviderScope(
    overrides: [
      firestoreServiceProvider.overrideWithValue(DevFirestoreService()),
    ],
    child: const DemoApp(),
  ));
}

class DemoApp extends ConsumerStatefulWidget {
  const DemoApp({super.key});

  @override
  ConsumerState<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends ConsumerState<DemoApp> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Asegura que el proveedor SyncService se instancie. La inicialización del
    // proveedor cargará la cola persistida de forma asíncrona y arrancará el
    // worker en segundo plano (ver `providers.dart`). No es necesario arrancar
    // manualmente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // use ref to read the provider so it gets created under the correct
      // ProviderScope (overrides come from main()).
      ref.read(syncServiceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Demo de sincronización')),
  body: _index == 0 ? Center(child: SyncStatusWidget()) : DeadLetterWidget(),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final id = DateTime.now().millisecondsSinceEpoch.toString();
            final note = Note(id: id, title: 'Demo $id', content: 'demo');
            final sync = ref.read(syncServiceProvider);
            await sync.enqueue(note);
          },
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.sync), label: 'Estado'),
            BottomNavigationBarItem(icon: Icon(Icons.error), label: 'Cola de errores'),
          ],
        ),
      ),
    );
  }
}
