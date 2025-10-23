// No changes needed as there are no leading or trailing triple-backtick fences.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nootes/services/providers.dart';
import 'package:nootes/widgets/index.dart';
import 'services/firestore_dev.dart';
import 'domain/note.dart';

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
    // Ensure the SyncService provider is created under this ProviderScope so
    // background processing begins using the DevFirestoreService override.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Demo de sincronización')),
        body: _index == 0 ? const Center(child: SyncStatusWidget()) : const DeadLetterWidget(),
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
