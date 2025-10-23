// Reconstructed clean implementations after previous corruption.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Adjust these imports to your actual theme/util locations
import '../theme/app_theme.dart' as theme;
import '../theme/color_utils.dart';
import '../theme/icon_registry.dart';

// Custom intent for keyboard delete
class DeleteNoteIntent extends Intent {}

/// Card representing a note in the sidebar / list.
class NotesSidebarCard extends StatelessWidget {
  const NotesSidebarCard({
    super.key,
    required this.note,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onPin,
    this.onSetIcon,
    this.onClearIcon,
    this.enableDrag = false,
    this.noteId = '',
    this.compact = false,
  });

  final Map<String, dynamic> note;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final VoidCallback? onSetIcon;
  final VoidCallback? onClearIcon;
  final bool enableDrag;
  final String noteId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = (note['title']?.toString() ?? '').trim().isEmpty
        ? 'Sin título'
        : note['title'].toString();
    final isPinned = note['pinned'] == true;

    // ✅ Convertir el String del icono a IconData
    final IconData? icon;
    if (note['icon'] is IconData) {
      icon = note['icon'] as IconData;
    } else if (note['icon'] is String) {
      icon = NoteIconRegistry.iconFromName(note['icon'] as String);
    } else {
      icon = null;
    }

    // ✅ Obtener el color del icono desde Firestore
    final Color iconColor;
    if (note['iconColor'] is int) {
      iconColor = Color(note['iconColor'] as int);
    } else {
      iconColor = theme.AppColors.primary;
    }

    final tags = List<String>.from(note['tags'] ?? []);

    final selectedColor = isSelected
        ? theme.AppColors.activeNote
        : theme.AppColors.surfaceOverlay;
    final borderColor = isSelected
        ? theme.AppColors.primary
        : theme.AppColors.borderColor;

    Widget card = FocusableActionDetector(
      enabled: true,
      autofocus: isSelected,
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.delete): DeleteNoteIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            onTap();
            return null;
          },
        ),
        DeleteNoteIntent: CallbackAction<DeleteNoteIntent>(
          onInvoke: (intent) {
            onDelete();
            return null;
          },
        ),
      },
      child: Semantics(
        selected: isSelected,
        button: true,
        label: 'Nota: $title',
        child: Material(
          color: selectedColor,
          borderRadius: BorderRadius.circular(theme.AppColors.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(theme.AppColors.radiusMd),
            onTap: onTap,
            onLongPress: onPin,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact
                    ? theme.AppColors.space8
                    : theme.AppColors.space16,
                vertical: compact
                    ? theme.AppColors.space8
                    : theme.AppColors.space12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: compact ? 18 : 22, color: iconColor),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? theme.AppColors.primary
                                          : theme.AppColors.textPrimary,
                                    ),
                              ),
                            ),
                            if (isPinned)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: theme.AppColors.space4,
                                ),
                                child: Icon(
                                  Icons.push_pin_rounded,
                                  size: 16,
                                  color: theme.AppColors.warning,
                                ),
                              ),
                          ],
                        ),
                        if (tags.isNotEmpty && !compact) ...[
                          SizedBox(height: theme.AppColors.space4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: tags.take(3).map((t) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.AppColors.primary
                                      .withOpacityCompat(0.12),
                                  borderRadius: BorderRadius.circular(
                                    theme.AppColors.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  t,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: theme.AppColors.primary,
                                        fontSize: 10,
                                      ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  _MoreMenu(
                    isPinned: isPinned,
                    hasIcon: icon != null,
                    onPin: onPin,
                    onDelete: onDelete,
                    onSetIcon: onSetIcon,
                    onClearIcon: onClearIcon,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    card = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(theme.AppColors.radiusMd),
      ),
      child: card,
    );

    if (enableDrag && noteId.isNotEmpty) {
      return LongPressDraggable<String>(
        data: noteId,
        feedback: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(theme.AppColors.radiusMd),
          child: Opacity(
            opacity: 0.85,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: theme.AppColors.space32 * 7.5,
              ),
              child: card,
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: card,
      );
    }
    return card;
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.isPinned,
    required this.hasIcon,
    required this.onPin,
    required this.onDelete,
    this.onSetIcon,
    this.onClearIcon,
  });

  final bool isPinned;
  final bool hasIcon;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final VoidCallback? onSetIcon;
  final VoidCallback? onClearIcon;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Opciones',
      onSelected: (value) {
        switch (value) {
          case 'pin':
            onPin();
            break;
          case 'delete':
            onDelete();
            break;
          case 'setIcon':
            onSetIcon?.call();
            break;
          case 'clearIcon':
            onClearIcon?.call();
            break;
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
                color: theme.AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(isPinned ? 'Desanclar' : 'Anclar'),
            ],
          ),
        ),
        if (onSetIcon != null)
          PopupMenuItem(
            value: 'setIcon',
            child: Row(
              children: const [
                Icon(Icons.brush_rounded, size: 18),
                SizedBox(width: 8),
                Text('Cambiar icono'),
              ],
            ),
          ),
        if (hasIcon && onClearIcon != null)
          PopupMenuItem(
            value: 'clearIcon',
            child: Row(
              children: const [
                Icon(Icons.delete_sweep_rounded, size: 18),
                SizedBox(width: 8),
                Text('Quitar icono'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: theme.AppColors.danger,
              ),
              const SizedBox(width: 8),
              const Text('Eliminar'),
            ],
          ),
        ),
      ],
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: theme.AppColors.textSecondary,
      ),
    );
  }
}

/// Workspace header (restored minimal version)
class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.saving,
    this.focusMode = false,
    this.onToggleFocus,
    required this.onSave,
    this.onSettings,
    this.onExport,
    this.onExportAll,
    this.onCopyMarkdown,
    this.saveScale,
  });

  final bool saving;
  final bool focusMode;
  final VoidCallback? onToggleFocus;
  final VoidCallback onSave;
  final VoidCallback? onSettings;
  final VoidCallback?
  onExport; // export current note (markdown / platform-specific)
  final VoidCallback?
  onExportAll; // export all notes (json / platform-specific)
  final VoidCallback?
  onCopyMarkdown; // copy current note as markdown to clipboard
  final Animation<double>? saveScale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.AppColors.space20,
        vertical: theme.AppColors.space12,
      ),
      decoration: BoxDecoration(
        color: theme.AppColors.surface,
        border: Border(
          bottom: BorderSide(color: theme.AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_note_rounded,
            color: theme.AppColors.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            'Nootes',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (saving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (saveScale != null)
            ScaleTransition(scale: saveScale!, child: _saveButton())
          else
            _saveButton(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: focusMode ? 'Salir modo enfoque' : 'Modo enfoque',
            onPressed: onToggleFocus,
            icon: Icon(
              focusMode
                  ? Icons.fullscreen_exit_rounded
                  : Icons.center_focus_strong_rounded,
            ),
          ),
          if (onSettings != null)
            IconButton(
              tooltip: 'Configuración',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_rounded),
            ),
          // Copy current note as Markdown (falls back to clipboard on native)
          if (onCopyMarkdown != null)
            IconButton(
              tooltip: 'Copiar Markdown',
              onPressed: onCopyMarkdown,
              icon: const Icon(Icons.copy_all_rounded),
            ),
          // Export menu (note / all)
          if (onExport != null || onExportAll != null)
            PopupMenuButton<String>(
              tooltip: 'Exportar',
              onSelected: (value) {
                switch (value) {
                  case 'export_note':
                    onExport?.call();
                    break;
                  case 'export_all':
                    onExportAll?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                if (onExport != null)
                  const PopupMenuItem(
                    value: 'export_note',
                    child: Text('Exportar nota (.md)'),
                  ),
                if (onExportAll != null)
                  const PopupMenuItem(
                    value: 'export_all',
                    child: Text('Exportar todo (.json)'),
                  ),
              ],
              icon: const Icon(Icons.download_rounded),
            ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return IconButton(
      tooltip: 'Guardar cambios',
      onPressed: onSave,
      icon: const Icon(Icons.save_rounded),
    );
  }
}

/// Empty state when there are no notes.
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
            padding: EdgeInsets.all(theme.AppColors.space32),
            decoration: BoxDecoration(
              color: theme.AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.note_add_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          SizedBox(height: theme.AppColors.space24),
          Text(
            'Comienza a escribir',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: theme.AppColors.space8),
          Text(
            'Crea tu primera nota y organiza tus ideas',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: theme.AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.AppColors.space32),
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
