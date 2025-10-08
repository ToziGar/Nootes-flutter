import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Sidebar moderno para lista de notas con soporte de drag & drop
class NotesSidebarCard extends StatelessWidget {
  const NotesSidebarCard({
    super.key,
    required this.note,
    required this.isSelected,
    required this.onTap,
    required this.onPin,
    required this.onDelete,
    this.enableDrag = false,
    this.compact = false,
  });

  final Map<String, dynamic> note;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final bool enableDrag;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = (note['title']?.toString() ?? '').isEmpty 
        ? 'Sin título' 
        : note['title'].toString();
    final isPinned = note['pinned'] == true;
    final preview = (note['content']?.toString() ?? '').isEmpty
        ? 'Nota vacía'
        : note['content'].toString();
    final noteId = note['id']?.toString() ?? '';

    final cardWidget = Container(
      margin: const EdgeInsets.only(bottom: AppColors.space8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.activeNote : Colors.transparent,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: isSelected
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          hoverColor: AppColors.surfaceHover,
          child: Padding(
            padding: EdgeInsets.all(compact ? AppColors.space8 : AppColors.space12),
            child: Row(
              children: [
                // Pin indicator
                if (!compact)
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isPinned ? AppColors.warning : Colors.transparent),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (!compact) const SizedBox(width: AppColors.space12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontSize: compact ? 14 : null,
                                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!compact && isPinned)
                            const Icon(
                              Icons.push_pin_rounded,
                              size: 14,
                              color: AppColors.warning,
                            ),
                        ],
                      ),
                      if (!compact) const SizedBox(height: AppColors.space4),
                      if (!compact)
                        Text(
                          preview,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                
                // Actions
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: isSelected ? AppColors.textSecondary : AppColors.textMuted,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  ),
                  color: AppColors.surface,
                  onSelected: (value) {
                    if (value == 'pin') {
                      onPin();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(
                            isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: AppColors.space8),
                          Text(isPinned ? 'Desanclar' : 'Anclar'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                          SizedBox(width: AppColors.space8),
                          Text('Eliminar', style: TextStyle(color: AppColors.danger)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Envolver con LongPressDraggable si está habilitado
    if (enableDrag && noteId.isNotEmpty) {
      return LongPressDraggable<String>(
        data: noteId,
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Opacity(
            opacity: 0.8,
            child: Container(
              width: 250,
              constraints: const BoxConstraints(maxWidth: 250), // Restricción de ancho
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                boxShadow: AppTheme.shadowXl,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppColors.space12),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Evitar overflow
                  children: [
                    const Icon(Icons.drag_indicator_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppColors.space8),
                    Flexible( // Cambio de Expanded a Flexible
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: cardWidget,
        ),
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}

/// Header profesional para el workspace
class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.saving,
    required this.richMode,
    this.focusMode = false,
    required this.onToggleMode,
    this.onToggleFocus,
    required this.onSave,
    this.onSettings,
    this.saveScale,
  });

  final bool saving;
  final bool richMode;
  final bool focusMode;
  final ValueChanged<bool> onToggleMode;
  final VoidCallback? onToggleFocus;
  final VoidCallback onSave;
  final VoidCallback? onSettings;
  final Animation<double>? saveScale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppColors.space20,
        vertical: AppColors.space16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Row(
        children: [
          // Logo/Title
          Row(
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                child: Image.asset(
                  'LOGO.webp',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(AppColors.space8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.gradientPrimary,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppColors.space12),
              Text(
                'Nootes',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Mode Toggle
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Markdown', style: TextStyle(fontSize: 12)),
                  icon: Icon(Icons.code_rounded, size: 16),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Rich', style: TextStyle(fontSize: 12)),
                  icon: Icon(Icons.format_paint_rounded, size: 16),
                ),
              ],
              selected: {richMode},
              onSelectionChanged: (s) => onToggleMode(s.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary;
                  }
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return AppColors.textSecondary;
                }),
              ),
            ),
          ),
          
          const SizedBox(width: AppColors.space16),
          
          // Save button
          if (saving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (saveScale != null)
            ScaleTransition(
              scale: saveScale!,
              child: IconButton(
                tooltip: 'Guardar cambios',
                onPressed: onSave,
                icon: const Icon(Icons.save_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.success.withValues(alpha: 0.15),
                  foregroundColor: AppColors.success,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Guardar cambios',
              onPressed: onSave,
              icon: const Icon(Icons.save_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.success.withValues(alpha: 0.15),
                foregroundColor: AppColors.success,
              ),
            ),
          
          const SizedBox(width: AppColors.space8),
          
          // Focus mode
          IconButton(
            tooltip: focusMode ? 'Salir del modo enfoque' : 'Modo enfoque',
            onPressed: onToggleFocus,
            icon: Icon(focusMode ? Icons.fullscreen_exit_rounded : Icons.center_focus_strong_rounded),
            style: IconButton.styleFrom(
              backgroundColor: focusMode ? AppColors.primary.withValues(alpha: 0.15) : null,
              foregroundColor: focusMode ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          
          // More menu
          const SizedBox(width: AppColors.space8),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_vert_rounded),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            onSelected: (value) {
              if (value == 'search') {
                Navigator.of(context).pushNamed('/advanced-search');
              } else if (value == 'graph') {
                Navigator.of(context).pushNamed('/graph');
              } else if (value == 'tasks') {
                Navigator.of(context).pushNamed('/tasks');
              } else if (value == 'export') {
                Navigator.of(context).pushNamed('/export');
              } else if (value == 'shared') {
                Navigator.of(context).pushNamed('/shared-notes');
              } else if (value == 'settings' && onSettings != null) {
                onSettings!();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Búsqueda Avanzada', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('Filtros y estadísticas', style: TextStyle(fontSize: 11, color: Colors.white60)),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'graph',
                child: Row(
                  children: [
                    Icon(Icons.psychology_rounded, size: 18, color: Color(0xFF8B5CF6)),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🧠 Mapa Mental IA', style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF8B5CF6))),
                        Text('Grafo inteligente con conexiones IA', style: TextStyle(fontSize: 11, color: Colors.white60)),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'tasks',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.task_alt_rounded, color: Color(0xFF10B981)),
                  title: Text('Mis Tareas'),
                  subtitle: Text('Ver todas las tareas', style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.file_download_rounded, color: Color(0xFF3B82F6)),
                  title: Text('Exportar'),
                  subtitle: Text('Guardar tus notas', style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuItem(
                value: 'shared',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.share_rounded, color: Color(0xFFFF8A65)),
                  title: Text('Notas Compartidas'),
                  subtitle: Text('Ver contenido compartido', style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuDivider(),
              if (onSettings != null)
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.settings_rounded),
                    title: Text('Ajustes'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Empty state moderno
class EmptyNotesState extends StatelessWidget {
  const EmptyNotesState({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppColors.space32),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.note_add_rounded, size: 48, color: Colors.white),
          ),
          const SizedBox(height: AppColors.space24),
          Text(
            'Comienza a escribir',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppColors.space8),
          Text(
            'Crea tu primera nota y organiza tus ideas',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppColors.space32),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nueva Nota'),
          ),
        ],
      ),
    );
  }
}
