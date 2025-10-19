import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SyncDebugPage extends StatelessWidget {
  const SyncDebugPage({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notes');
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Debug')),
      body: StreamBuilder<QuerySnapshot>(
        stream: ref.snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final lastClient = data['lastClientUpdateAt'];
              final pending = d.metadata.hasPendingWrites;
              return ListTile(
                title: Text(data['title'] ?? '(no title)'),
                subtitle: Text(
                  'pending: $pending • lastClient: ${lastClient ?? 'n/a'}',
                ),
                trailing: Text(d.id),
              );
            },
          );
        },
      ),
    );
  }
}
