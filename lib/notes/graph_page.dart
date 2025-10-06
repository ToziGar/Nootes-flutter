import 'package:flutter/material.dart';
import '../widgets/glass.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class GraphPage extends StatefulWidget {
  const GraphPage({super.key});

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  late Future<void> _init;
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, String>> _edges = [];
  String? _selected;

  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _init = _load();
  }

  Future<void> _load() async {
    final svc = FirestoreService.instance;
    final notes = await svc.listNotes(uid: _uid);
    final edges = await svc.listEdges(uid: _uid);
    setState(() {
      _notes = notes;
      _edges = edges;
    });
  }

  @override
  Widget build(BuildContext context) {
    final idToTitle = {for (final n in _notes) n['id'].toString(): (n['title']?.toString() ?? n['id'].toString())};
    final filteredEdges = _selected == null
        ? _edges
        : _edges.where((e) => e['from'] == _selected || e['to'] == _selected).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Grafo de notas')),
      body: GlassBackground(
        child: FutureBuilder<void>(
          future: _init,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  DropdownButtonFormField<String?>(
                        initialValue: _selected,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por nota',
                      prefixIcon: Icon(Icons.filter_alt_outlined),
                    ),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                      ..._notes.map((n) => DropdownMenuItem<String?>(
                            value: n['id'].toString(),
                            child: Text(idToTitle[n['id'].toString()] ?? n['id'].toString()),
                          )),
                    ],
                    onChanged: (v) => setState(() => _selected = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredEdges.isEmpty
                        ? const Center(child: Text('Sin enlaces'))
                        : ListView.separated(
                            itemCount: filteredEdges.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final e = filteredEdges[i];
                              final from = idToTitle[e['from']] ?? e['from'];
                              final to = idToTitle[e['to']] ?? e['to'];
                              return ListTile(
                                leading: const Icon(Icons.linear_scale_rounded),
                                title: Text('$from -> $to'),
                                subtitle: Text('(${e['from']}) -> (${e['to']})'),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}




