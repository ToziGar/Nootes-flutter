import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nootes/services/providers.dart';

/// A simple page that shows the current sync queue and dead-letter items and
/// allows manual retry/remove and clearing persisted storage.
class SyncQueuePage extends ConsumerStatefulWidget {
  const SyncQueuePage({super.key});

  @override
  ConsumerState<SyncQueuePage> createState() => _SyncQueuePageState();
}

class _SyncQueuePageState extends ConsumerState<SyncQueuePage> {
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _dead = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sync = ref.read(syncServiceProvider) as dynamic;
    try {
      final q = await sync.getQueue();
      final d = await sync.getDeadLetterInMemory();
      setState(() {
        _queue = List<Map<String, dynamic>>.from(q);
        _dead = List<Map<String, dynamic>>.from(d);
      });
    } catch (_) {
      // ignore
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _retryFromDead(int index) async {
    final sync = ref.read(syncServiceProvider) as dynamic;
    await sync.retryDeadLetter(index);
    await _load();
  }

  Future<void> _removeFromDead(int index) async {
    final sync = ref.read(syncServiceProvider) as dynamic;
    await sync.removeDeadLetter(index);
    await _load();
  }

  Future<void> _clearStorage() async {
    final sync = ref.read(syncServiceProvider) as dynamic;
    await sync.clearAllStorage();
    await _load();
  }

  Widget _buildQueueTile(Map<String, dynamic> item, int index) {
    final note = item['note'] as Map<String, dynamic>?;
    final retries = item['retries'] ?? 0;
    final nextAttempt = item['nextAttempt'] ?? '';
    String nextString = '';
    try {
      final dt = DateTime.tryParse(nextAttempt.toString());
      if (dt != null) nextString = dt.toLocal().toString();
    } catch (_) {}
    return ListTile(
      title: Text(note?['title']?.toString() ?? 'Untitled'),
      subtitle: Text('retries: $retries • next: ${nextString.isEmpty ? '-' : nextString}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Process now',
            onPressed: () async {
              final sync = ref.read(syncServiceProvider) as dynamic;
              await sync.processItemNow(index);
              await _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeadTile(Map<String, dynamic> item, int index) {
    final note = item['note'] as Map<String, dynamic>?;
    final retries = item['retries'] ?? 0;
    final failedAt = item['failedAt'] ?? '';
    String failedString = '';
    try {
      final dt = DateTime.tryParse(failedAt.toString());
      if (dt != null) failedString = dt.toLocal().toString();
    } catch (_) {}
    return ListTile(
      title: Text(note?['title']?.toString() ?? 'Untitled'),
      subtitle: Text('retries: $retries • failedAt: ${failedString.isEmpty ? '-' : failedString}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Retry',
            onPressed: () => _retryFromDead(index),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Remove',
            onPressed: () => _removeFromDead(index),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear stored queue',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Clear stored queue?'),
                  content: const Text('This will remove all persisted queue and dead-letter items.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Clear')),
                  ],
                ),
              );
              if (ok == true) await _clearStorage();
            },
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  ListTile(title: const Text('Queued items')),
                  if (_queue.isEmpty)
                    const ListTile(title: Text('No queued items'))
                  else
                    ..._queue.asMap().entries.map((e) => _buildQueueTile(e.value, e.key)),
                  const Divider(),
                  ListTile(title: const Text('Dead-letter')),
                  if (_dead.isEmpty)
                    const ListTile(title: Text('No dead-letter items'))
                  else
                    ..._dead.asMap().entries.map((e) => _buildDeadTile(e.value, e.key)),
                ],
              ),
            ),
    );
  }
}
