import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nootes/services/providers.dart';
import 'package:nootes/pages/sync_queue_page.dart';

class SyncStatusWidget extends ConsumerWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(syncStatusProvider);
    return async.when(
      data: (s) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sync),
          const SizedBox(width: 8),
          Text('Queue: ${s.queueLength}'),
          const SizedBox(width: 12),
          Text('Dead: ${s.deadLetterCount}'),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (v) async {
              final sync = ref.read(syncServiceProvider);
              if (v == 'start') {
                sync.start();
              } else if (v == 'stop') {
                sync.stop();
              } else if (v == 'once') {
                await sync.processOnce(ignoreSchedule: true);
              } else if (v == 'open') {
                Navigator.of(context).push(MaterialPageRoute(builder: (c) => const SyncQueuePage()));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'start', child: Text('Start Worker')),
              const PopupMenuItem(value: 'stop', child: Text('Stop Worker')),
              const PopupMenuItem(value: 'once', child: Text('Process Once')),
              const PopupMenuItem(value: 'open', child: Text('Open Queue')),
            ],
          ),
        ],
      ),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => const Icon(Icons.error),
    );
  }
}
