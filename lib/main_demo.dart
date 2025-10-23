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
    // Ensure the SyncService provider is instantiated. The provider's
    // initialization will asynchronously load persisted queue and start the
    // background worker (see `providers.dart`). No manual start is required.
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
        appBar: AppBar(title: const Text('Sync Demo')),
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
            BottomNavigationBarItem(icon: Icon(Icons.sync), label: 'Status'),
            BottomNavigationBarItem(icon: Icon(Icons.error), label: 'Dead Letter'),
          ],
        ),
      ),
    );
  }
}
