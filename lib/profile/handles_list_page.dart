import 'package:flutter/material.dart';
import '../widgets/glass.dart';
import '../services/firestore_service.dart';

class HandlesListPage extends StatefulWidget {
  const HandlesListPage({super.key});

  @override
  State<HandlesListPage> createState() => _HandlesListPageState();
}

class _HandlesListPageState extends State<HandlesListPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = FirestoreService.instance.listHandles(limit: 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Handles')),
      body: GlassBackground(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!;
            if (items.isEmpty) return const Center(child: Text('Sin handles'));
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final h = items[index];
                final user = (h['username'] ?? '').toString();
                final uid = (h['uid'] ?? '').toString();
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.alternate_email_rounded),
                  ),
                  title: Text('@$user'),
                  subtitle: Text(uid),
                );
              },
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemCount: items.length,
            );
          },
        ),
      ),
    );
  }
}
