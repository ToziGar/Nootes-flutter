import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nootes/services/providers.dart';
import 'package:nootes/widgets/sync_status_widget.dart';
import 'package:nootes/services/firestore_dev.dart';
import 'package:nootes/domain/note.dart';

void main() {
  runApp(const ProviderScope(child: DemoApp()));
}

class DemoApp extends ConsumerWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // override firestore provider with dev implementation
    return ProviderScope(
      overrides: [
        firestoreServiceProvider.overrideWithValue(DevFirestoreService()),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Sync Demo')),
          body: const Center(child: SyncStatusWidget()),
          floatingActionButton: Builder(builder: (c) {
            return FloatingActionButton(
              onPressed: () async {
                final id = DateTime.now().millisecondsSinceEpoch.toString();
                final note = Note(id: id, title: 'Demo $id', content: 'demo');
                final sync = ProviderScope.containerOf(c).read(syncServiceProvider);
                await sync.enqueue(note);
              },
              child: const Icon(Icons.add),
            );
          }),
        ),
      ),
    );
  }
}
