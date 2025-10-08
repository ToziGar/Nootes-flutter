import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget para mostrar estadísticas del workspace
class WorkspaceStats extends StatelessWidget {
  const WorkspaceStats({
    super.key,
    required this.notes,
    required this.folders,
  });
  
  final List<Map<String, dynamic>> notes;
  final int folders;
  
  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.borderColor),
      ),
      padding: const EdgeInsets.all(AppColors.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppColors.space8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppColors.space12),
              Text(
                'Estadísticas del Workspace',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppColors.space20),
          
          // Grid de estadísticas
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: AppColors.space12,
            crossAxisSpacing: AppColors.space12,
            childAspectRatio: 2.5,
            children: [
              _buildStatCard(
                context,
                'Notas',
                stats['totalNotes'].toString(),
                Icons.note_rounded,
                AppColors.primary,
              ),
              _buildStatCard(
                context,
                'Carpetas',
                folders.toString(),
                Icons.folder_rounded,
                AppColors.accent,
              ),
              _buildStatCard(
                context,
                'Etiquetas',
                stats['totalTags'].toString(),
                Icons.label_rounded,
                AppColors.success,
              ),
              _buildStatCard(
                context,
                'Fijadas',
                stats['pinnedNotes'].toString(),
                Icons.push_pin_rounded,
                AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: AppColors.space16),
          
          // Estadísticas adicionales
          _buildInfoRow(
            context,
            'Promedio palabras por nota',
            stats['avgWords'].toString(),
          ),
          const SizedBox(height: AppColors.space8),
          _buildInfoRow(
            context,
            'Total de caracteres',
            _formatNumber(stats['totalChars']),
          ),
          const SizedBox(height: AppColors.space8),
          _buildInfoRow(
            context,
            'Nota más reciente',
            stats['lastCreated'],
          ),
        ],
      ),
    );
  }
  
  Map<String, dynamic> _calculateStats() {
    var pinnedNotes = 0;
    var totalWords = 0;
    var totalChars = 0;
    final allTags = <String>{};
    DateTime? lastCreated;
    
    for (final note in notes) {
      // Tags
      final tags = List<String>.from((note['tags'] as List?)?.whereType<String>() ?? []);
      allTags.addAll(tags);
      
      // Pinned
      if (note['pinned'] == true) pinnedNotes++;
      
      // Words and chars
      final content = note['content']?.toString() ?? '';
      final words = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      totalWords += words;
      totalChars += content.length;
      
      // Last created
      final createdAt = note['createdAt'];
      DateTime? noteDate;
      if (createdAt is DateTime) {
        noteDate = createdAt;
      } else if (createdAt is int) {
        noteDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
      }
      
      if (noteDate != null) {
        if (lastCreated == null || noteDate.isAfter(lastCreated)) {
          lastCreated = noteDate;
        }
      }
    }
    
    final avgWords = notes.isEmpty ? 0 : (totalWords / notes.length).round();
    
    String lastCreatedStr = 'N/A';
    if (lastCreated != null) {
      final diff = DateTime.now().difference(lastCreated);
      if (diff.inDays == 0) {
        lastCreatedStr = 'Hoy';
      } else if (diff.inDays == 1) {
        lastCreatedStr = 'Ayer';
      } else if (diff.inDays < 7) {
        lastCreatedStr = 'Hace ${diff.inDays} días';
      } else {
        lastCreatedStr = 'Hace ${(diff.inDays / 7).floor()} semanas';
      }
    }
    
    return {
      'totalNotes': notes.length,
      'totalTags': allTags.length,
      'pinnedNotes': pinnedNotes,
      'avgWords': avgWords,
      'totalChars': totalChars,
      'lastCreated': lastCreatedStr,
    };
  }
  
  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppColors.space12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppColors.space8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: AppColors.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
