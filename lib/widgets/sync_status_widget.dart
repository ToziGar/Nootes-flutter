import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nootes/services/providers.dart';

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
        ],
      ),
      loading: () => const CircularProgressIndicator(),
  error: (error, stack) => const Icon(Icons.error),
    );
  }
}
