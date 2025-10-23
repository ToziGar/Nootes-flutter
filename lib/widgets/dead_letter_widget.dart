import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nootes/services/providers.dart';

class DeadLetterWidget extends ConsumerWidget {
  const DeadLetterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(syncServiceProvider).getDeadLetter(),
      builder: (context, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        final list = snap.data!;
        if (list.isEmpty) return const Text('No dead-letter items');
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (c, i) {
            final item = list[i];
            final note = item['note'] as Map<String, dynamic>;
            return ListTile(
              title: Text(note['title'] ?? 'untitled'),
              subtitle: Text('retries: ${item['retries'] ?? 0}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await ref.read(syncServiceProvider).retryDeadLetter(i);
                      (context as Element).markNeedsBuild();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      await ref.read(syncServiceProvider).removeDeadLetter(i);
                      (context as Element).markNeedsBuild();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
