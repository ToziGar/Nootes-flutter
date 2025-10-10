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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con botón mejorado
          Padding(
            padding: const EdgeInsets.all(AppColors.space8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppColors.space8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.primaryLight.withValues(alpha: 0.05)],
                      ),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.folder_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: AppColors.space12),
                  const Expanded(
                    child: Text(
                      'Carpetas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
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
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppColors.space12,
                    vertical: AppColors.space8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  ),
                ),
              ),
              const SizedBox(height: AppColors.space8),
              
              // Menú de acciones rápidas
              Wrap(
                spacing: AppColors.space4,
                runSpacing: AppColors.space4,
                children: [
                  _buildQuickActionButton(
                    context: context,
                    icon: Icons.add_rounded,
                    label: 'Nota',
                    color: AppColors.secondary,
                    onPressed: () => _showCreateNoteMenu(context),
                  ),
                  _buildQuickActionButton(
                    context: context,
                    icon: Icons.search_rounded,
                    label: 'Buscar',
                    color: AppColors.accent,
                    onPressed: () => _showSearchMenu(context),
                  ),
                  _buildQuickActionButton(
                    context: context,
                    icon: Icons.download_rounded,
                    label: 'Exportar',
                    color: AppColors.info,
                    onPressed: () => _showExportMenu(context),
                  ),
                  _buildQuickActionButton(
                    context: context,
                    icon: Icons.delete_rounded,
                    label: 'Papelera',
                    color: Colors.orange,
                    onPressed: () => _showTrashMenu(context),
                  ),
                ],
              ),
              const SizedBox(height: AppColors.space4),
              // Hint de drag & drop
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppColors.space8,
                  vertical: AppColors.space4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded, size: 12, color: AppColors.accent),
                    const SizedBox(width: AppColors.space4),
                    const Expanded(
                      child: Text(
                        'Mantén presionada una nota para arrastrarla',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
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

        // Shared unified entry: Navigates to dedicated shared workspace
        const SizedBox(height: AppColors.space8),
        _buildVirtualTile(
          context: context,
          id: '__SHARED_CENTER__',
          name: 'Compartidas',
          icon: Icons.group_rounded,
          color: AppColors.info,
          isSelected: selectedFolderId == '__SHARED_CENTER__',
          onTap: () {
            Navigator.of(context).pushNamed('/shared-notes');
          },
        ),
        
        const Divider(color: AppColors.borderColor, height: 1),
        
        // Folders list
        if (folders.isEmpty)
          Padding(
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
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppColors.space8),
                Text(
                  'Crea una carpeta para organizar tus notas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ...folders.map((folder) => _buildFolderTile(
            key: ValueKey(folder.id),
            context: context,
            folder: folder,
            isSelected: folder.id == selectedFolderId,
            onTap: () => onFolderSelected(folder.id),
            onEdit: () => _showFolderDialog(context, folder: folder),
            onDelete: () => _confirmDelete(context, folder),
          )),
        const SizedBox(height: AppColors.space16),
      ],
      ),
    );
  }

  Widget _buildVirtualTile({
    required BuildContext context,
    required String id,
    required String name,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(
        horizontal: AppColors.space8,
        vertical: AppColors.space4,
      ),
      decoration: BoxDecoration(
        gradient: isSelected 
          ? LinearGradient(
              colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primaryLight.withValues(alpha: 0.1)],
            )
          : null,
        color: !isSelected ? Colors.white : null,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2) : null,
        boxShadow: isSelected ? [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
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
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      onWillAcceptWithDetails: (details) => true, // ✅ Aceptar siempre (incluido "Todas las notas")
      onAcceptWithDetails: (details) {
        if (folder != null) {
          onNoteDropped(details.data, folder.id);
        } else {
          // Soltar en "Todas las notas" = remover de todas las carpetas
          onNoteDropped(details.data, '__REMOVE_FROM_ALL__');
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
            gradient: isSelected
                ? LinearGradient(
                    colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primaryLight.withValues(alpha: 0.1)],
                  )
                : isHovering
                    ? LinearGradient(
                        colors: [AppColors.success.withValues(alpha: 0.15), AppColors.success.withValues(alpha: 0.1)],
                      )
                    : null,
            color: !isSelected && !isHovering ? Colors.white : null,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: isHovering
                ? Border.all(
                    color: AppColors.success,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  )
                : isSelected
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2)
                    : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            boxShadow: isHovering || isSelected
                ? [
                    BoxShadow(
                      color: (isHovering ? AppColors.success : AppColors.primary).withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isHovering 
                                  ? AppColors.success
                                  : isSelected 
                                      ? AppColors.primary 
                                      : Colors.black87,
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
                                fontSize: 13,
                                color: isHovering 
                                    ? AppColors.success 
                                    : Colors.black87,
                                fontWeight: isHovering 
                                    ? FontWeight.w700 
                                    : FontWeight.w500,
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
                        icon: Icon(Icons.more_vert_rounded, size: 20, color: Colors.black87),
                        color: Colors.white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            onTap: onEdit,
                            child: const Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18, color: AppColors.textPrimary),
                                SizedBox(width: AppColors.space12),
                                Text('Renombrar', style: TextStyle(color: AppColors.textPrimary)),
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

  Widget _buildQuickActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 65,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: IconButton(
              onPressed: onPressed,
              icon: Icon(icon, color: color, size: 18),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showCreateNoteMenu(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crear nueva nota - funcionalidad pendiente')),
    );
  }

  void _showSearchMenu(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Búsqueda avanzada - funcionalidad pendiente')),
    );
  }

  void _showExportMenu(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exportar notas - funcionalidad pendiente')),
    );
  }

  void _showTrashMenu(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Papelera - funcionalidad pendiente')),
    );
  }
}
