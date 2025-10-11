import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/glass.dart';

/// Dashboard de productividad con métricas y estadísticas
class ProductivityDashboard extends StatefulWidget {
  const ProductivityDashboard({super.key});

  @override
  State<ProductivityDashboard> createState() => _ProductivityDashboardState();
}

class _ProductivityDashboardState extends State<ProductivityDashboard> {
  late Future<void> _init;
  Map<String, dynamic> _stats = {};
  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _init = _loadData();
  }

  Future<void> _loadData() async {
    final notes = await FirestoreService.instance.listNotes(uid: _uid);
    setState(() {
      _stats = _calculateStats(notes);
    });
  }

  Map<String, dynamic> _calculateStats(List<Map<String, dynamic>> notes) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = today.subtract(const Duration(days: 30));

    // Notas creadas
    int notesToday = 0;
    int notesThisWeek = 0;
    int notesThisMonth = 0;

    // Palabras escritas
    int totalWords = 0;
    int wordsToday = 0;
    int wordsThisWeek = 0;

    // Racha de escritura (días consecutivos)
    Set<String> daysWritten = {};

    // Notas por día (últimos 30 días)
    Map<String, int> notesByDay = {};

    // Tags más usados
    Map<String, int> tagFrequency = {};

    // Tiempo promedio entre notas
    List<DateTime> createdDates = [];

    for (var note in notes) {
      final createdAt = note['createdAt'];
      DateTime? date;

      if (createdAt is String) {
        date = DateTime.tryParse(createdAt);
      }

      if (date != null) {
        createdDates.add(date);
        final dateOnly = DateTime(date.year, date.month, date.day);
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        // Contar notas por período
        if (dateOnly.isAtSameMomentAs(today) || dateOnly.isAfter(today)) {
          notesToday++;
        }
        if (dateOnly.isAfter(weekAgo) || dateOnly.isAtSameMomentAs(weekAgo)) {
          notesThisWeek++;
        }
        if (dateOnly.isAfter(monthAgo) || dateOnly.isAtSameMomentAs(monthAgo)) {
          notesThisMonth++;
          notesByDay[dateKey] = (notesByDay[dateKey] ?? 0) + 1;
        }

        daysWritten.add(dateKey);
      }

      // Contar palabras
      final content = note['content']?.toString() ?? '';
      final title = note['title']?.toString() ?? '';
      final words = _countWords(content) + _countWords(title);
      totalWords += words;

      if (date != null) {
        final dateOnly = DateTime(date.year, date.month, date.day);
        if (dateOnly.isAtSameMomentAs(today) || dateOnly.isAfter(today)) {
          wordsToday += words;
        }
        if (dateOnly.isAfter(weekAgo) || dateOnly.isAtSameMomentAs(weekAgo)) {
          wordsThisWeek += words;
        }
      }

      // Contar tags
      final tags = note['tags'] as List?;
      if (tags != null) {
        for (var tag in tags) {
          if (tag is String) {
            tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
          }
        }
      }
    }

    // Calcular racha actual
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;

    final sortedDays = daysWritten.toList()..sort();
    DateTime? lastDate;

    for (var i = sortedDays.length - 1; i >= 0; i--) {
      final parts = sortedDays[i].split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );

      if (lastDate == null) {
        tempStreak = 1;
        if (date.isAfter(today.subtract(const Duration(days: 1))) ||
            date.isAtSameMomentAs(today)) {
          currentStreak = 1;
        }
      } else {
        final diff = lastDate.difference(date).inDays;
        if (diff == 1) {
          tempStreak++;
          if (currentStreak > 0) currentStreak++;
        } else {
          if (tempStreak > longestStreak) longestStreak = tempStreak;
          tempStreak = 1;
          currentStreak = 0;
        }
      }

      lastDate = date;
    }

    if (tempStreak > longestStreak) longestStreak = tempStreak;

    // Top tags
    final topTags = tagFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalNotes': notes.length,
      'notesToday': notesToday,
      'notesThisWeek': notesThisWeek,
      'notesThisMonth': notesThisMonth,
      'totalWords': totalWords,
      'wordsToday': wordsToday,
      'wordsThisWeek': wordsThisWeek,
      'avgWordsPerNote': notes.isEmpty
          ? 0
          : (totalWords / notes.length).round(),
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'notesByDay': notesByDay,
      'topTags': topTags.take(5).toList(),
      'pinnedCount': notes.where((n) => n['pinned'] == true).length,
    };
  }

  int _countWords(String text) {
    return text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard de Productividad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              final future = _loadData();
              setState(() {
                _init = future;
              });
            },
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

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverviewCards(),
                  const SizedBox(height: 24),
                  _buildStreakSection(),
                  const SizedBox(height: 24),
                  _buildWordsSection(),
                  const SizedBox(height: 24),
                  _buildHeatmap(),
                  const SizedBox(height: 24),
                  _buildTopTags(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _MetricCard(
              icon: Icons.note_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: 'Total Notas',
              value: '${_stats['totalNotes'] ?? 0}',
              subtitle: '${_stats['notesToday'] ?? 0} hoy',
            ),
            _MetricCard(
              icon: Icons.today_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Esta Semana',
              value: '${_stats['notesThisWeek'] ?? 0}',
              subtitle: 'notas',
            ),
            _MetricCard(
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Este Mes',
              value: '${_stats['notesThisMonth'] ?? 0}',
              subtitle: 'notas',
            ),
            _MetricCard(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Fijadas',
              value: '${_stats['pinnedCount'] ?? 0}',
              subtitle: 'importantes',
            ),
          ],
        );
      },
    );
  }

  Widget _buildStreakSection() {
    final currentStreak = _stats['currentStreak'] ?? 0;
    final longestStreak = _stats['longestStreak'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                Text(
                  'Racha de Escritura',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StreakCard(
                    label: 'Racha Actual',
                    days: currentStreak,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StreakCard(
                    label: 'Récord',
                    days: longestStreak,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            if (currentStreak > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tips_and_updates_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentStreak >= 7
                            ? '¡Increíble! Llevas una semana escribiendo. ¡Sigue así!'
                            : '¡Sigue escribiendo para mantener tu racha!',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWordsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.text_fields_rounded, color: Color(0xFF06B6D4)),
                const SizedBox(width: 8),
                Text(
                  'Palabras Escritas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _WordCard(
                    label: 'Total',
                    words: _stats['totalWords'] ?? 0,
                    icon: Icons.description_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WordCard(
                    label: 'Hoy',
                    words: _stats['wordsToday'] ?? 0,
                    icon: Icons.today_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WordCard(
                    label: 'Esta Semana',
                    words: _stats['wordsThisWeek'] ?? 0,
                    icon: Icons.calendar_view_week_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_graph_rounded,
                    color: Color(0xFF06B6D4),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Promedio: ${_stats['avgWordsPerNote'] ?? 0} palabras/nota',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap() {
    final notesByDay = _stats['notesByDay'] as Map<String, int>? ?? {};

    if (notesByDay.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_view_month_rounded,
                  color: Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Actividad (Últimos 30 días)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _HeatmapGrid(data: notesByDay),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTags() {
    final topTags = _stats['topTags'] as List<MapEntry<String, int>>? ?? [];

    if (topTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_rounded, color: Color(0xFFF43F5E)),
                const SizedBox(width: 8),
                Text(
                  'Tags Más Usados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...topTags.map((entry) {
              final maxCount = topTags.first.value;
              final percentage = (entry.value / maxCount * 100).round();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${entry.value} notas',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: const Color(0xFFF43F5E),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const Spacer(),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final String label;
  final int days;
  final Color color;

  const _StreakCard({
    required this.label,
    required this.days,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$days',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            days == 1 ? 'día' : 'días',
            style: TextStyle(fontSize: 12, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final String label;
  final int words;
  final IconData icon;

  const _WordCard({
    required this.label,
    required this.words,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF06B6D4), size: 24),
          const SizedBox(height: 8),
          Text(
            _formatNumber(words),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF06B6D4),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }
}

class _HeatmapGrid extends StatelessWidget {
  final Map<String, int> data;

  const _HeatmapGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(
      30,
      (i) => today.subtract(Duration(days: 29 - i)),
    );

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: days.map((day) {
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final count = data[key] ?? 0;
        final intensity = count == 0 ? 0.0 : (count / 5).clamp(0.2, 1.0);

        return Tooltip(
          message:
              '${day.day}/${day.month}: $count ${count == 1 ? 'nota' : 'notas'}',
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: count == 0
                  ? Colors.white.withValues(alpha: 0.1)
                  : Color(0xFF10B981).withValues(alpha: intensity),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }).toList(),
    );
  }
}
