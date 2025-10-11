import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/color_utils.dart';

/// Widget mejorado que maneja el menú contextual evitando el menú nativo
class EnhancedContextMenuRegion extends StatelessWidget {
  final Widget child;
  final List<ContextMenuAction> Function(BuildContext context)? actions;
  final void Function(ContextMenuAction action)? onActionSelected;
  final bool enabled;

  const EnhancedContextMenuRegion({
    super.key,
    required this.child,
    this.actions,
    this.onActionSelected,
    this.enabled = true,
  });

  // Prevenir activaciones múltiples con debounce
  static DateTime? _lastMenuTime;
  static const _debounceDelay = Duration(milliseconds: 300);

  /// Resetear el estado del debounce (útil para testing o casos especiales)
  static void resetDebounceState() {
    _lastMenuTime = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onSecondaryTapDown: enabled
          ? (details) {
              // Solo procesar si no hay otros gestores activos
              _handleRightClick(context, details.globalPosition);
            }
          : null,
      onLongPress: enabled
          ? () {
              // Para dispositivos táctiles - solo en móviles
              final RenderBox box = context.findRenderObject() as RenderBox;
              final Offset position = box.localToGlobal(
                box.size.center(Offset.zero),
              );
              _handleRightClick(context, position);
            }
          : null,
      child: child,
    );
  }

  void _handleRightClick(BuildContext context, Offset position) async {
    if (!enabled || actions == null) return;

    // Prevenir activaciones múltiples con debounce
    final now = DateTime.now();
    if (_lastMenuTime != null &&
        now.difference(_lastMenuTime!) < _debounceDelay) {
      return;
    }
    _lastMenuTime = now;

    // Feedback háptico
    HapticFeedback.lightImpact();

    final contextActions = actions!(context);
    if (contextActions.isEmpty) return;

    try {
      final selectedAction = await _showEnhancedMenu(
        context: context,
        position: position,
        actions: contextActions,
      );

      if (selectedAction != null && onActionSelected != null) {
        onActionSelected!(selectedAction);
      }
    } catch (e) {
      // Manejo silencioso de errores del menú
      debugPrint('Error mostrando menú contextual: $e');
    }
  }

  static Future<ContextMenuAction?> _showEnhancedMenu({
    required BuildContext context,
    required Offset position,
    required List<ContextMenuAction> actions,
  }) async {
    // Verificar que el context aún sea válido
    if (!context.mounted) return null;

    return showMenu<ContextMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: actions.map<PopupMenuEntry<ContextMenuAction>>((action) {
        if (action.isDivider) {
          return PopupMenuDivider(height: 1);
        }

        return PopupMenuItem<ContextMenuAction>(
          value: action,
          enabled: action.enabled,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: action.isDanger
                        ? AppColors.danger.withOpacityCompat(0.1)
                        : AppColors.primary.withOpacityCompat(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    action.icon,
                    size: 18,
                    color: action.isDanger
                        ? AppColors.danger
                        : action.enabled
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    action.label,
                    style: TextStyle(
                      color: action.isDanger
                          ? AppColors.danger
                          : action.enabled
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontWeight: action.isDanger
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (action.shortcut != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.borderColor,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      action.shortcut!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
      elevation: 12,
      color: AppColors.surface,
      shadowColor: AppColors.primary.withOpacityCompat(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderColor, width: 0.5),
      ),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
    );
  }
}

/// Acción mejorada del menú contextual
class ContextMenuAction {
  final String label;
  final IconData icon;
  final dynamic value;
  final bool isDanger;
  final bool isDivider;
  final bool enabled;
  final String? shortcut;
  final String? description;

  const ContextMenuAction({
    required this.label,
    required this.icon,
    this.value,
    this.isDanger = false,
    this.isDivider = false,
    this.enabled = true,
    this.shortcut,
    this.description,
  });

  /// Crear divisor con estilo mejorado
  static const ContextMenuAction divider = ContextMenuAction(
    label: '',
    icon: Icons.remove,
    isDivider: true,
  );
}

/// Builder mejorado de menús contextuales
class EnhancedContextMenuBuilder {
  /// Menú para notas fuera de carpetas
  static List<ContextMenuAction> noteMenu({
    bool isInFolder = false,
    bool isPinned = false,
    bool isFavorite = false,
    bool isArchived = false,
    bool hasIcon = false,
  }) {
    return [
      ContextMenuAction(
        label: 'Abrir',
        icon: Icons.open_in_new_rounded,
        value: 'open',
        shortcut: 'Enter',
      ),
      ContextMenuAction(
        label: 'Renombrar',
        icon: Icons.edit_rounded,
        value: 'rename',
        shortcut: 'F2',
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Duplicar',
        icon: Icons.content_copy_rounded,
        value: 'duplicate',
        shortcut: 'Ctrl+D',
      ),
      if (!isInFolder)
        ContextMenuAction(
          label: 'Mover a carpeta',
          icon: Icons.folder_open_rounded,
          value: 'moveToFolder',
        ),
      if (isInFolder)
        ContextMenuAction(
          label: 'Quitar de carpeta',
          icon: Icons.folder_off_rounded,
          value: 'removeFromFolder',
        ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: isPinned ? 'Desfijar' : 'Fijar',
        icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        value: 'togglePin',
        shortcut: 'Ctrl+P',
      ),
      ContextMenuAction(
        label: isFavorite ? 'Quitar favorito' : 'Marcar favorito',
        icon: isFavorite ? Icons.favorite : Icons.favorite_outline,
        value: 'toggleFavorite',
        shortcut: 'Ctrl+F',
      ),
      ContextMenuAction(
        label: isArchived ? 'Desarchivar' : 'Archivar',
        icon: isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
        value: 'toggleArchive',
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Cambiar icono',
        icon: Icons.brush_rounded,
        value: 'changeNoteIcon',
      ),
      ContextMenuAction(
        label: 'Quitar icono',
        icon: Icons.delete_outline_rounded,
        value: 'clearNoteIcon',
        isDanger: true,
        enabled: hasIcon,
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Exportar',
        icon: Icons.download_rounded,
        value: 'export',
        shortcut: 'Ctrl+E',
      ),
      ContextMenuAction(
        label: 'Compartir',
        icon: Icons.share_rounded,
        value: 'share',
      ),
      ContextMenuAction(
        label: 'Enlace público',
        icon: Icons.public_rounded,
        value: 'generatePublicLink',
        description: 'Generar enlace para compartir públicamente',
      ),
      ContextMenuAction(
        label: 'Copiar enlace',
        icon: Icons.link_rounded,
        value: 'copyLink',
        shortcut: 'Ctrl+L',
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Propiedades',
        icon: Icons.info_outline_rounded,
        value: 'properties',
        shortcut: 'Alt+Enter',
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Eliminar',
        icon: Icons.delete_rounded,
        value: 'delete',
        isDanger: true,
        shortcut: 'Del',
      ),
    ];
  }

  /// Menú para carpetas
  static List<ContextMenuAction> folderMenu({int noteCount = 0}) {
    return [
      ContextMenuAction(
        label: 'Abrir',
        icon: Icons.folder_open_rounded,
        value: 'open',
        shortcut: 'Enter',
      ),
      ContextMenuAction(
        label: 'Renombrar',
        icon: Icons.edit_rounded,
        value: 'rename',
        shortcut: 'F2',
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Nueva nota aquí',
        icon: Icons.note_add_rounded,
        value: 'newNote',
        shortcut: 'Ctrl+N',
      ),
      ContextMenuAction(
        label: 'Nueva subcarpeta',
        icon: Icons.create_new_folder_rounded,
        value: 'newSubfolder',
        shortcut: 'Ctrl+Shift+N',
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Duplicar carpeta',
        icon: Icons.content_copy_rounded,
        value: 'duplicate',
        description: noteCount > 0
            ? 'Duplicar con $noteCount notas'
            : 'Duplicar carpeta vacía',
      ),
      ContextMenuAction(
        label: 'Cambiar icono y color',
        icon: Icons.brush_rounded,
        value: 'changeIcon',
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Exportar carpeta',
        icon: Icons.download_rounded,
        value: 'export',
        description: noteCount > 0 ? '$noteCount notas' : 'Carpeta vacía',
      ),
      ContextMenuAction(
        label: 'Compartir carpeta',
        icon: Icons.share_rounded,
        value: 'share',
      ),
      ContextMenuAction(
        label: 'Copiar enlace',
        icon: Icons.link_rounded,
        value: 'copyLink',
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Propiedades',
        icon: Icons.info_outline_rounded,
        value: 'properties',
        shortcut: 'Alt+Enter',
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: noteCount > 0
            ? 'Eliminar carpeta (mover notas)'
            : 'Eliminar carpeta',
        icon: Icons.delete_rounded,
        value: 'delete',
        isDanger: true,
        shortcut: 'Del',
        description: noteCount > 0
            ? 'Las notas se moverán fuera de la carpeta'
            : null,
      ),
    ];
  }

  /// Menú para área vacía del workspace
  static List<ContextMenuAction> workspaceMenu() {
    return [
      ContextMenuAction(
        label: 'Nueva nota',
        icon: Icons.note_add_rounded,
        value: 'newNote',
        shortcut: 'Ctrl+N',
      ),
      ContextMenuAction(
        label: 'Nueva carpeta',
        icon: Icons.create_new_folder_rounded,
        value: 'newFolder',
        shortcut: 'Ctrl+Shift+N',
      ),
      ContextMenuAction(
        label: 'Desde plantilla',
        icon: Icons.description_rounded,
        value: 'newFromTemplate',
        shortcut: 'Ctrl+T',
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Pegar',
        icon: Icons.paste_rounded,
        value: 'paste',
        shortcut: 'Ctrl+V',
        enabled: false, // Se habilitaría si hay contenido en clipboard
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Seleccionar todo',
        icon: Icons.select_all_rounded,
        value: 'selectAll',
        shortcut: 'Ctrl+A',
      ),
      ContextMenuAction.divider,
      ContextMenuAction(
        label: 'Actualizar',
        icon: Icons.refresh_rounded,
        value: 'refresh',
        shortcut: 'F5',
      ),
      ContextMenuAction(
        label: 'Abrir Dashboard',
        icon: Icons.dashboard_rounded,
        value: 'openDashboard',
        shortcut: 'Ctrl+D',
      ),
    ];
  }
}
