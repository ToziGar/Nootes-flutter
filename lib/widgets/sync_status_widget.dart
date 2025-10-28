import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nootes/services/providers.dart';
import 'package:nootes/widgets/dead_letter_widget.dart';

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
                // open a dialog with queue and dead-letter
                showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    child: SizedBox(
                      width: 600,
                      height: 500,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Sync Queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: FutureBuilder<List<Map<String, dynamic>>>(
                                      future: ref.read(queueStorageProvider).loadQueue(),
                                      builder: (c, snap) {
                                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                                        final q = snap.data!;
                                        if (q.isEmpty) return const Text('Queue is empty');
                                        return ListView.separated(
                                          itemCount: q.length,
                                          separatorBuilder: (context, index) => const Divider(height: 1),
                                          itemBuilder: (c2, i) {
                                            final item = q[i];
                                            final note = item['note'] as Map<String, dynamic>;
                                            return ListTile(
                                              title: Text(note['title'] ?? 'untitled'),
                                              subtitle: Text('retries: ${item['retries'] ?? 0}'),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.play_arrow),
                                                onPressed: () async {
                                                  // move this item to front and process once
                                                  await ref.read(syncServiceProvider).processOnce(ignoreSchedule: true);
                                                  (context as Element).markNeedsBuild();
                                                },
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  const VerticalDivider(width: 12),
                                  Expanded(child: SizedBox(child: DeadLetterWidget())),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
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
