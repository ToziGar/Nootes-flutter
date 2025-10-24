import 'package:flutter/material.dart';
import '../widgets/glass.dart';
import '../services/firestore_service.dart';

class ProfilesListPage extends StatefulWidget {
  const ProfilesListPage({super.key});

  @override
  State<ProfilesListPage> createState() => _ProfilesListPageState();
}

class _ProfilesListPageState extends State<ProfilesListPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = FirestoreService.instance.listUserProfiles(limit: 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfiles')),
      body: GlassBackground(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!;
            if (items.isEmpty) return const Center(child: Text('Sin perfiles'));
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final p = items[index];
                final name = (p['fullName'] ?? '').toString();
                final user = (p['username'] ?? '').toString();
                final email = (p['email'] ?? '').toString();
                return ListTile(
                  title: Text(name.isEmpty ? email : name),
                  subtitle: Text('@$user  •  $email'),
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline_rounded),
                  ),
                );
              },
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemCount: items.length,
            );
          },
        ),
      ),
    );
  }
}
