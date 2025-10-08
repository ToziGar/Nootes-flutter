import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/glass.dart';

/// Sistema de gestión de tareas con checkboxes en notas
class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with SingleTickerProviderStateMixin {
  late Future<void> _init;
  List<Task> _tasks = [];
  late TabController _tabController;
  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _init = _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final notes = await FirestoreService.instance.listNotes(uid: _uid);
    final tasks = <Task>[];
    
    for (var note in notes) {
      final content = note['content']?.toString() ?? '';
      final noteId = note['id'].toString();
      final noteTitle = note['title']?.toString() ?? 'Sin título';
      
      // Buscar checkboxes en el contenido
      final checkboxes = _extractCheckboxes(content);
      
      for (var cb in checkboxes) {
        tasks.add(Task(
          id: '${noteId}_${tasks.length}',
          noteId: noteId,
          noteTitle: noteTitle,
          description: cb['text'] ?? '',
          completed: cb['checked'] ?? false,
          line: cb['line'] ?? 0,
        ));
      }
    }
    
    setState(() => _tasks = tasks);
  }

  List<Map<String, dynamic>> _extractCheckboxes(String content) {
    final lines = content.split('\n');
    final checkboxes = <Map<String, dynamic>>[];
    
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Detectar checkbox markdown: - [ ] o - [x]
      if (line.contains(RegExp(r'^\s*-\s*\[[ xX]\]'))) {
        final checked = line.contains(RegExp(r'\[[xX]\]'));
        final text = line.replaceAll(RegExp(r'^\s*-\s*\[[ xX]\]\s*'), '').trim();
        
        if (text.isNotEmpty) {
          checkboxes.add({
            'text': text,
            'checked': checked,
            'line': i,
          });
        }
      }
    }
    
    return checkboxes;
  }

  List<Task> get _pendingTasks => _tasks.where((t) => !t.completed).toList();
  List<Task> get _completedTasks => _tasks.where((t) => t.completed).toList();
  List<Task> get _allTasks => _tasks;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.pending_actions_rounded),
              text: 'Pendientes',
              iconMargin: const EdgeInsets.only(bottom: 4),
            ),
            Tab(
              icon: const Icon(Icons.check_circle_rounded),
              text: 'Completadas',
              iconMargin: const EdgeInsets.only(bottom: 4),
            ),
            Tab(
              icon: const Icon(Icons.list_rounded),
              text: 'Todas',
              iconMargin: const EdgeInsets.only(bottom: 4),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() => _init = _loadTasks()),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: GlassBackground(
        child: FutureBuilder(
          future: _init,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            
            return TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(_pendingTasks, showCompleted: false),
                _buildTaskList(_completedTasks, showCompleted: true),
                _buildTaskList(_allTasks, showAll: true),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showStats,
        icon: const Icon(Icons.analytics_rounded),
        label: const Text('Estadísticas'),
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks, {bool showCompleted = false, bool showAll = false}) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              showCompleted ? Icons.celebration_rounded : Icons.inbox_rounded,
              size: 64,
              color: Colors.white30,
            ),
            const SizedBox(height: 16),
            Text(
              showCompleted
                  ? '¡Sin tareas completadas aún!'
                  : '¡No hay tareas pendientes!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showCompleted
                  ? 'Las tareas completadas aparecerán aquí'
                  : 'Crea checkboxes en tus notas con - [ ]',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // Agrupar por nota
    final groupedTasks = <String, List<Task>>{};
    for (var task in tasks) {
      if (!groupedTasks.containsKey(task.noteId)) {
        groupedTasks[task.noteId] = [];
      }
      groupedTasks[task.noteId]!.add(task);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedTasks.length,
      itemBuilder: (context, index) {
        final noteId = groupedTasks.keys.elementAt(index);
        final noteTasks = groupedTasks[noteId]!;
        final noteTitle = noteTasks.first.noteTitle;
        
        final completedCount = noteTasks.where((t) => t.completed).length;
        final totalCount = noteTasks.length;
        final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: CircularProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                color: progress == 1.0 ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
              ),
              title: Text(
                noteTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '$completedCount/$totalCount completadas',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              children: noteTasks.map((task) {
                return _TaskTile(
                  task: task,
                  onChanged: (value) {
                    // Aquí se implementaría la actualización real en Firestore
                    setState(() {
                      task.completed = value ?? false;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showStats() {
    final total = _tasks.length;
    final completed = _completedTasks.length;
    final pending = _pendingTasks.length;
    final completionRate = total > 0 ? (completed / total * 100).toStringAsFixed(1) : '0';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics_rounded, color: Color(0xFF3B82F6)),
            SizedBox(width: 8),
            Text('Estadísticas de Tareas'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatRow(
              icon: Icons.list_rounded,
              label: 'Total de tareas',
              value: '$total',
              color: const Color(0xFF6366F1),
            ),
            const SizedBox(height: 12),
            _StatRow(
              icon: Icons.check_circle_rounded,
              label: 'Completadas',
              value: '$completed',
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 12),
            _StatRow(
              icon: Icons.pending_actions_rounded,
              label: 'Pendientes',
              value: '$pending',
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    const Color(0xFF10B981).withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.trending_up_rounded, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    'Tasa de completitud: $completionRate%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class Task {
  final String id;
  final String noteId;
  final String noteTitle;
  final String description;
  bool completed;
  final int line;

  Task({
    required this.id,
    required this.noteId,
    required this.noteTitle,
    required this.description,
    required this.completed,
    required this.line,
  });
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final ValueChanged<bool?> onChanged;

  const _TaskTile({
    required this.task,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Checkbox(
        value: task.completed,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      title: Text(
        task.description,
        style: TextStyle(
          decoration: task.completed ? TextDecoration.lineThrough : null,
          color: task.completed ? Colors.white60 : Colors.white,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        tooltip: 'Abrir nota',
        onPressed: () {
          // Aquí se abriría la nota específica
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Abrir: ${task.noteTitle}')),
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
