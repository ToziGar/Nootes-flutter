import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../theme/color_utils.dart';

/// Página del dashboard de estadísticas
class StatsDashboardPage extends StatefulWidget {
  const StatsDashboardPage({super.key});

  @override
  State<StatsDashboardPage> createState() => _StatsDashboardPageState();
}

class _StatsDashboardPageState extends State<StatsDashboardPage> {
  final AnalyticsService _analyticsService = AnalyticsService();
  
  UserStats? _userStats;
  List<DailyActivity> _dailyActivity = [];
  List<FolderStats> _folderStats = [];
  List<TagStats> _tagStats = [];
  List<HourlyActivity> _hourlyActivity = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final results = await Future.wait([
        _analyticsService.getUserStats(),
        _analyticsService.getDailyActivity(),
        _analyticsService.getFolderStats(),
        _analyticsService.getTagStats(),
        _analyticsService.getHourlyActivity(),
      ]);

      if (mounted) {
        setState(() {
          _userStats = results[0] as UserStats;
          _dailyActivity = results[1] as List<DailyActivity>;
          _folderStats = results[2] as List<FolderStats>;
          _tagStats = results[3] as List<TagStats>;
          _hourlyActivity = results[4] as List<HourlyActivity>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar estadísticas: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Estadísticas',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview cards
                  _buildOverviewCards(),
                  const SizedBox(height: 32),
                  
                  // Statistics sections
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildActivityStats(),
                            const SizedBox(height: 24),
                            _buildHourlyStats(),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 24),
                      
                      // Right column
                      Expanded(
                        child: Column(
                          children: [
                            _buildFolderStats(),
                            const SizedBox(height: 24),
                            _buildTagStats(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    if (_userStats == null) return const SizedBox.shrink();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          title: 'Total de Notas',
          value: _userStats!.totalNotes.toString(),
          icon: Icons.note_rounded,
          color: AppColors.primary,
        ),
        _StatCard(
          title: 'Carpetas',
          value: _userStats!.totalFolders.toString(),
          icon: Icons.folder_rounded,
          color: AppColors.secondary,
        ),
        _StatCard(
          title: 'Palabras',
          value: _formatNumber(_userStats!.totalWords),
          icon: Icons.text_fields_rounded,
          color: AppColors.accent,
        ),
        _StatCard(
          title: 'Esta Semana',
          value: _userStats!.notesThisWeek.toString(),
          icon: Icons.trending_up_rounded,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildActivityStats() {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actividad reciente',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (_userStats != null) ...[
              _buildStatRow('Notas hoy', _userStats!.notesToday.toString(), Icons.today),
              _buildStatRow('Notas esta semana', _userStats!.notesThisWeek.toString(), Icons.date_range),
              _buildStatRow('Notas este mes', _userStats!.notesThisMonth.toString(), Icons.calendar_month),
              _buildStatRow('Promedio palabras/nota', _userStats!.averageWordsPerNote.toString(), Icons.text_fields),
              if (_userStats!.firstNoteDate != null)
                _buildStatRow('Días activo', _userStats!.daysSinceFirstNote.toString(), Icons.timeline),
            ],
            if (_dailyActivity.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Últimos 7 días',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildDailyActivityChart(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDailyActivityChart() {
    final maxActivity = _dailyActivity.fold<int>(0, (max, day) => day.totalEvents > max ? day.totalEvents : max);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _dailyActivity.take(7).map((day) {
        final intensity = maxActivity > 0 ? day.totalEvents / maxActivity : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 80 * intensity,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacityCompat(0.3 + (intensity * 0.7)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  day.date.day.toString(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHourlyStats() {
    // Encontrar la hora más activa
    var mostActiveHour = 0;
    var maxActivity = 0;
    for (final hourly in _hourlyActivity) {
      if (hourly.activity > maxActivity) {
        maxActivity = hourly.activity;
        mostActiveHour = hourly.hour;
      }
    }

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patrones de uso',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              'Hora más activa', 
              '$mostActiveHour:00 ($maxActivity eventos)', 
              Icons.schedule
            ),
            const SizedBox(height: 12),
            // Mostrar barras de actividad por hora simplificadas
            SizedBox(
              height: 60,
              child: Row(
                children: _hourlyActivity.map((hourly) {
                  final intensity = maxActivity > 0 ? hourly.activity / maxActivity : 0.0;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: 60 * intensity,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacityCompat(0.3 + (intensity * 0.7)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '0h                    12h                    23h',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderStats() {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Carpetas más activas',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (_folderStats.isEmpty)
              const Text(
                'No hay datos de carpetas',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ..._folderStats.take(5).map((folder) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          folder.folderName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${folder.noteCount} notas',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
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

  Widget _buildTagStats() {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Etiquetas populares',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (_tagStats.isEmpty)
              const Text(
                'No hay etiquetas disponibles',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tagStats.take(10).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacityCompat(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacityCompat(0.3),
                      ),
                    ),
                    child: Text(
                      '${tag.tag} (${tag.count})',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

/// Widget para mostrar una tarjeta de estadística
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}