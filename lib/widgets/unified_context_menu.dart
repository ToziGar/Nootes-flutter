import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Menú contextual unificado para notas, carpetas y workspace
class UnifiedContextMenu extends StatelessWidget {
  final Offset position;
  final List<ContextMenuAction> actions;

  const UnifiedContextMenu({
    super.key,
    required this.position,
    required this.actions,
  });

  /// Mostrar menú contextual en una posición específica
  static Future<T?> show<T>({
    required BuildContext context,
    required Offset position,
    required List<ContextMenuAction> actions,
  }) {
    return showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: actions.map<PopupMenuEntry<T>>((action) {
        if (action.isDivider) {
          return const PopupMenuDivider();
        }
        
        return PopupMenuItem<T>(
          value: action.value as T?,
          enabled: action.enabled,
          child: Row(
            children: [
              Icon(
                action.icon,
                size: 20,
                color: action.isDanger 
                    ? AppColors.danger 
                    : action.enabled 
                        ? AppColors.textPrimary 
                        : AppColors.textMuted,
              ),
              const SizedBox(width: AppColors.space12),
              Expanded(
                child: Text(
                  action.label,
                  style: TextStyle(
                    color: action.isDanger 
                        ? AppColors.danger 
                        : action.enabled 
                            ? AppColors.textPrimary 
                            : AppColors.textMuted,
                    fontWeight: action.isDanger ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (action.shortcut != null) ...[
                const SizedBox(width: AppColors.space12),
                Text(
                  action.shortcut!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      elevation: 8,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        side: BorderSide(color: AppColors.borderColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Acción del menú contextual
class ContextMenuAction {
  final String label;
  final IconData icon;
  final dynamic value;
  final bool isDanger;
  final bool isDivider;
  final bool enabled;
  final String? shortcut;

  const ContextMenuAction({
    required this.label,
    required this.icon,
    this.value,
    this.isDanger = false,
    this.isDivider = false,
    this.enabled = true,
    this.shortcut,
  });

  /// Crear divisor
  static const ContextMenuAction divider = ContextMenuAction(
    label: '',
    icon: Icons.remove,
    isDivider: true,
  );
}

/// Tipo de acción del menú contextual
enum ContextMenuActionType {
  // Acciones de nota
  newNote,
  editNote,
  duplicateNote,
  deleteNote,
  exportNote,
  shareNote,
  moveToFolder,
  removeFromFolder,
  pinNote,
  unpinNote,
  favoriteNote,
  unfavoriteNote,
  archiveNote,
  unarchiveNote,
  addTags,
  copyNoteLink,
  viewHistory,
  
  // Acciones de carpeta
  newFolder,
  editFolder,
  deleteFolder,
  exportFolder,
  colorFolder,
  
  // Acciones de plantilla
  newFromTemplate,
  
  // Acciones de inserción
  insertImage,
  insertAudio,
  insertLink,
  insertTable,
  insertCodeBlock,
  
  // Otras acciones
  openDashboard,
  refresh,
  selectAll,
  properties,
}

/// Builder de menús contextuales predefinidos
class ContextMenuBuilder {
  /// Menú para área vacía del workspace
  static List<ContextMenuAction> workspace() {
    return [
      ContextMenuAction(
        label: 'Nueva nota',
        icon: Icons.note_add_rounded,
        value: ContextMenuActionType.newNote,
      ),
      ContextMenuAction(
        label: 'Nueva carpeta',
        icon: Icons.create_new_folder_rounded,
        value: ContextMenuActionType.newFolder,
      ),
      ContextMenuAction(
        label: 'Desde plantilla',
        icon: Icons.description_rounded,
        value: ContextMenuActionType.newFromTemplate,
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Dashboard',
        icon: Icons.analytics_rounded,
        value: ContextMenuActionType.openDashboard,
      ),
      ContextMenuAction(
        label: 'Actualizar',
        icon: Icons.refresh_rounded,
        value: ContextMenuActionType.refresh,
      ),
    ];
  }

  /// Menú para nota individual
  static List<ContextMenuAction> note({
    required bool isInFolder,
    bool isPinned = false,
    bool isFavorite = false,
    bool isArchived = false,
  }) {
    return [
      ContextMenuAction(
        label: 'Editar',
        icon: Icons.edit_rounded,
        value: ContextMenuActionType.editNote,
        shortcut: 'Enter',
      ),
      ContextMenuAction(
        label: 'Duplicar',
        icon: Icons.content_copy_rounded,
        value: ContextMenuActionType.duplicateNote,
        shortcut: 'Ctrl+D',
      ),
      ContextMenuAction(
        label: isPinned ? 'Desfijar' : 'Fijar',
        icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        value: isPinned ? ContextMenuActionType.unpinNote : ContextMenuActionType.pinNote,
      ),
      ContextMenuAction(
        label: isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
        icon: isFavorite ? Icons.star : Icons.star_border_rounded,
        value: isFavorite ? ContextMenuActionType.unfavoriteNote : ContextMenuActionType.favoriteNote,
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: isInFolder ? 'Quitar de carpeta' : 'Mover a carpeta',
        icon: isInFolder ? Icons.folder_off_rounded : Icons.folder_rounded,
        value: isInFolder 
            ? ContextMenuActionType.removeFromFolder 
            : ContextMenuActionType.moveToFolder,
      ),
      ContextMenuAction(
        label: 'Añadir etiquetas',
        icon: Icons.label_rounded,
        value: ContextMenuActionType.addTags,
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Exportar',
        icon: Icons.download_rounded,
        value: ContextMenuActionType.exportNote,
      ),
      ContextMenuAction(
        label: 'Copiar enlace',
        icon: Icons.link_rounded,
        value: ContextMenuActionType.copyNoteLink,
      ),
      ContextMenuAction(
        label: 'Ver historial',
        icon: Icons.history_rounded,
        value: ContextMenuActionType.viewHistory,
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: isArchived ? 'Desarchivar' : 'Archivar',
        icon: isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
        value: isArchived ? ContextMenuActionType.unarchiveNote : ContextMenuActionType.archiveNote,
      ),
      ContextMenuAction(
        label: 'Eliminar',
        icon: Icons.delete_rounded,
        value: ContextMenuActionType.deleteNote,
        isDanger: true,
        shortcut: 'Del',
      ),
    ];
  }

  /// Menú para carpeta
  static List<ContextMenuAction> folder() {
    return [
      ContextMenuAction(
        label: 'Editar',
        icon: Icons.edit_rounded,
        value: ContextMenuActionType.editFolder,
      ),
      ContextMenuAction(
        label: 'Cambiar color',
        icon: Icons.palette_rounded,
        value: ContextMenuActionType.colorFolder,
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Exportar carpeta',
        icon: Icons.download_rounded,
        value: ContextMenuActionType.exportFolder,
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Eliminar carpeta',
        icon: Icons.delete_rounded,
        value: ContextMenuActionType.deleteFolder,
        isDanger: true,
      ),
    ];
  }

  /// Menú para editor (cuando hay nota abierta)
  static List<ContextMenuAction> editor() {
    return [
      ContextMenuAction(
        label: 'Insertar imagen',
        icon: Icons.image_rounded,
        value: ContextMenuActionType.insertImage,
        shortcut: 'Ctrl+Shift+I',
      ),
      ContextMenuAction(
        label: 'Grabar audio',
        icon: Icons.mic_rounded,
        value: ContextMenuActionType.insertAudio,
        shortcut: 'Ctrl+Shift+A',
      ),
      ContextMenuAction(
        label: 'Insertar enlace',
        icon: Icons.link_rounded,
        value: ContextMenuActionType.insertLink,
        shortcut: 'Ctrl+K',
      ),
      ContextMenuAction(
        label: 'Insertar tabla',
        icon: Icons.table_chart_rounded,
        value: ContextMenuActionType.insertTable,
      ),
      ContextMenuAction(
        label: 'Bloque de código',
        icon: Icons.code_rounded,
        value: ContextMenuActionType.insertCodeBlock,
        shortcut: 'Ctrl+Shift+C',
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Propiedades',
        icon: Icons.info_rounded,
        value: ContextMenuActionType.properties,
      ),
      ContextMenuAction(
        label: 'Exportar nota',
        icon: Icons.download_rounded,
        value: ContextMenuActionType.exportNote,
      ),
    ];
  }
}
