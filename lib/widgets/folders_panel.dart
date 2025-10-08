import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../notes/folder_model.dart';
import '../notes/folder_dialog.dart';

/// Panel de carpetas con funcionalidad drag & drop
class FoldersPanel extends StatelessWidget {
  const FoldersPanel({
    super.key,
    required this.folders,
    this.selectedFolderId,
    required this.onFolderSelected,
    required this.onFolderCreated,
    required this.onFolderUpdated,
    required this.onFolderDeleted,
    required this.onNoteDropped,
  });

  final List<Folder> folders;
  final String? selectedFolderId;
  final ValueChanged<String?> onFolderSelected;
  final ValueChanged<Folder> onFolderCreated;
  final ValueChanged<Folder> onFolderUpdated;
  final ValueChanged<String> onFolderDeleted;
  final Function(String noteId, String folderId) onNoteDropped;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header con botón mejorado
        Padding(
          padding: const EdgeInsets.all(AppColors.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppColors.space8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                    child: const Icon(Icons.folder_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: AppColors.space12),
                  const Expanded(
                    child: Text(
                      'Carpetas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppColors.space12),
              // Botón de crear carpeta más visible
              FilledButton.icon(
                onPressed: () => _showFolderDialog(context),
                icon: const Icon(Icons.create_new_folder_rounded, size: 18),
                label: const Text('Nueva carpeta'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppColors.space12,
                    vertical: AppColors.space8,
                  ),
                ),
              ),
              const SizedBox(height: AppColors.space8),
              // Hint de drag & drop
              Container(
                padding: const EdgeInsets.all(AppColors.space8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded, size: 14, color: AppColors.accent),
                    const SizedBox(width: AppColors.space8),
                    const Expanded(
                      child: Text(
                        'Mantén presionada una nota para arrastrarla',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // All notes option
        _buildFolderTile(
          context: context,
          folder: null,
          isSelected: selectedFolderId == null,
          onTap: () => onFolderSelected(null),
        ),
        
        const Divider(color: AppColors.borderColor, height: 1),
        
        // Folders list
        Expanded(
          child: folders.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppColors.space24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: AppColors.space12),
                        Text(
                          'No hay carpetas',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: AppColors.space8),
                        Text(
                          'Crea una carpeta para organizar tus notas',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: AppColors.space16),
                  itemCount: folders.length,
                  onReorder: (oldIndex, newIndex) {
                    // TODO: Implementar reordenamiento
                  },
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return _buildFolderTile(
                      key: ValueKey(folder.id),
                      context: context,
                      folder: folder,
                      isSelected: folder.id == selectedFolderId,
                      onTap: () => onFolderSelected(folder.id),
                      onEdit: () => _showFolderDialog(context, folder: folder),
                      onDelete: () => _confirmDelete(context, folder),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFolderTile({
    Key? key,
    required BuildContext context,
    required Folder? folder,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final icon = folder?.icon ?? Icons.description_rounded;
    final color = folder?.color ?? AppColors.primary;
    final name = folder?.name ?? 'Todas las notas';
    final count = folder?.noteIds.length ?? 0;

    return DragTarget<String>(
      key: key,
      onWillAcceptWithDetails: (details) => folder != null,
      onAcceptWithDetails: (details) {
        if (folder != null) {
          onNoteDropped(details.data, folder.id);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(
            horizontal: AppColors.space8,
            vertical: AppColors.space4,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : isHovering
                    ? AppColors.success.withValues(alpha: 0.15)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: isHovering
                ? Border.all(
                    color: AppColors.success,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  )
                : isSelected
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                    : null,
            boxShadow: isHovering
                ? [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                    )
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppColors.space12,
                  vertical: AppColors.space12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppColors.space8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: AppColors.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isHovering 
                                  ? AppColors.success
                                  : isSelected 
                                      ? AppColors.primary 
                                      : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (folder != null) ...[
                            const SizedBox(height: AppColors.space4),
                            Text(
                              isHovering 
                                  ? '¡Suelta aquí!' 
                                  : '$count nota${count != 1 ? "s" : ""}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isHovering 
                                    ? AppColors.success 
                                    : AppColors.textMuted,
                                fontWeight: isHovering 
                                    ? FontWeight.w600 
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Mostrar icono de drop cuando se arrastra
                    if (isHovering)
                      Container(
                        padding: const EdgeInsets.all(AppColors.space8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        ),
                        child: const Icon(
                          Icons.add_circle_rounded, 
                          size: 20, 
                          color: AppColors.success,
                        ),
                      ),
                    if (folder != null && !isHovering)
                      PopupMenuButton(
                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textSecondary),
                        color: AppColors.surface,
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            onTap: onEdit,
                            child: const Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18, color: AppColors.textPrimary),
                                SizedBox(width: AppColors.space12),
                                Text('Editar', style: TextStyle(color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            onTap: onDelete,
                            child: const Row(
                              children: [
                                Icon(Icons.delete_rounded, size: 18, color: AppColors.danger),
                                SizedBox(width: AppColors.space12),
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
      },
    );
  }

  Future<void> _showFolderDialog(BuildContext context, {Folder? folder}) async {
    final result = await showDialog<Folder>(
      context: context,
      builder: (context) => FolderDialog(folder: folder),
    );

    if (result != null) {
      if (folder == null) {
        onFolderCreated(result);
      } else {
        onFolderUpdated(result);
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Folder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar carpeta', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '¿Estás seguro que deseas eliminar "${folder.name}"?\n\nLas notas no se eliminarán, solo se quitarán de la carpeta.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onFolderDeleted(folder.id);
    }
  }
}
