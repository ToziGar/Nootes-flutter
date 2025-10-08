import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme/app_theme.dart';
import '../services/export_import_service.dart';
// Conditional imports para soporte multiplataforma
import '../services/export_import_service_stub.dart'
    if (dart.library.html) '../services/export_import_service_web.dart'
    if (dart.library.io) '../services/export_import_service_io.dart' as platform;

/// Diálogo para exportar e importar notas
class ExportImportDialog extends StatefulWidget {
  const ExportImportDialog({
    super.key,
    required this.notes,
    required this.onImport,
  });

  final List<Map<String, dynamic>> notes;
  final Function(List<Map<String, dynamic>>) onImport;

  @override
  State<ExportImportDialog> createState() => _ExportImportDialogState();
}

class _ExportImportDialogState extends State<ExportImportDialog> {
  bool _isProcessing = false;
  String? _statusMessage;
  Map<String, dynamic>? _statistics;

  @override
  void initState() {
    super.initState();
    _statistics = ExportImportService.getNotesStatistics(widget.notes);
  }

  Future<void> _exportToJson() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      await ExportImportService.exportToJson(widget.notes);
      setState(() {
        _statusMessage = '✓ Notas exportadas a JSON correctamente';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Error al exportar: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  Future<void> _exportToMarkdown() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      await ExportImportService.exportToMarkdown(widget.notes);
      setState(() {
        _statusMessage = '✓ ${widget.notes.length} notas exportadas a Markdown';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Error al exportar: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  Future<void> _importFromJson() async {
    if (!kIsWeb) {
      setState(() {
        _statusMessage = '✗ Importar no disponible en esta plataforma todavía';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final content = await platform.PlatformExportImport.pickAndReadFile();
      if (content == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }
        
      final importedNotes = await ExportImportService.importFromJson(content);
      
      if (mounted) {
        setState(() {
          _statusMessage = '✓ ${importedNotes.length} notas importadas correctamente';
          _isProcessing = false;
        });
        
        widget.onImport(importedNotes);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '✗ Error al importar: ${e.toString()}';
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      await ExportImportService.createAutoBackup(widget.notes);
      setState(() {
        _statusMessage = '✓ Backup creado correctamente';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Error al crear backup: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(AppColors.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppColors.space12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.gradientPrimary,
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  ),
                  child: const Icon(Icons.import_export_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: AppColors.space16),
                const Expanded(
                  child: Text(
                    'Exportar/Importar',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppColors.space24),

            // Statistics
            Container(
              padding: const EdgeInsets.all(AppColors.space16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.secondary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        Icons.description_rounded,
                        _statistics?['totalNotes']?.toString() ?? '0',
                        'Notas',
                      ),
                      _buildStatItem(
                        Icons.label_rounded,
                        _statistics?['totalTags']?.toString() ?? '0',
                        'Etiquetas',
                      ),
                      _buildStatItem(
                        Icons.text_fields_rounded,
                        _statistics?['totalWords']?.toString() ?? '0',
                        'Palabras',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppColors.space24),

            // Export section
            _buildSectionTitle('Exportar notas', Icons.file_download_rounded),
            const SizedBox(height: AppColors.space12),
            _buildActionCard(
              icon: Icons.data_object_rounded,
              title: 'Exportar como JSON',
              subtitle: 'Formato completo con todos los datos',
              color: AppColors.primary,
              onTap: _isProcessing ? null : _exportToJson,
            ),
            const SizedBox(height: AppColors.space8),
            _buildActionCard(
              icon: Icons.article_rounded,
              title: 'Exportar como Markdown',
              subtitle: 'Un archivo .md por cada nota',
              color: AppColors.accent,
              onTap: _isProcessing ? null : _exportToMarkdown,
            ),
            const SizedBox(height: AppColors.space24),

            // Import section
            _buildSectionTitle('Importar notas', Icons.file_upload_rounded),
            const SizedBox(height: AppColors.space12),
            _buildActionCard(
              icon: Icons.upload_file_rounded,
              title: 'Importar desde JSON',
              subtitle: 'Cargar notas desde archivo de respaldo',
              color: AppColors.success,
              onTap: _isProcessing ? null : _importFromJson,
            ),
            const SizedBox(height: AppColors.space24),

            // Backup section
            _buildSectionTitle('Backup automático', Icons.backup_rounded),
            const SizedBox(height: AppColors.space12),
            _buildActionCard(
              icon: Icons.save_rounded,
              title: 'Crear backup ahora',
              subtitle: 'Guardar copia de seguridad con fecha',
              color: AppColors.warning,
              onTap: _isProcessing ? null : _createBackup,
            ),

            // Status message
            if (_statusMessage != null) ...[
              const SizedBox(height: AppColors.space16),
              Container(
                padding: const EdgeInsets.all(AppColors.space12),
                decoration: BoxDecoration(
                  color: _statusMessage!.startsWith('✓')
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusMessage!.startsWith('✓') ? Icons.check_circle_rounded : Icons.error_rounded,
                      color: _statusMessage!.startsWith('✓') ? AppColors.success : AppColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: AppColors.space12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _statusMessage!.startsWith('✓') ? AppColors.success : AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Processing indicator
            if (_isProcessing) ...[
              const SizedBox(height: AppColors.space16),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: AppColors.space8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppColors.space16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppColors.space12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: AppColors.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppColors.space4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: AppColors.space8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
