import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/icon_registry.dart';
import 'folder_model.dart';

/// Diálogo para crear o editar una carpeta
class FolderDialog extends StatefulWidget {
  const FolderDialog({super.key, this.folder});

  final Folder? folder;

  @override
  State<FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<FolderDialog> {
  late TextEditingController _nameController;
  late IconData _selectedIcon;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder?.name ?? '');
    _selectedIcon = widget.folder?.icon ?? Icons.folder_rounded;
    _selectedColor = widget.folder?.color ?? NoteIconRegistry.palette[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre de la carpeta no puede estar vacío'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final folder = Folder(
      id: widget.folder?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      icon: _selectedIcon,
      color: _selectedColor,
      noteIds: widget.folder?.noteIds ?? [],
      createdAt: widget.folder?.createdAt ?? now,
      updatedAt: now,
      order: widget.folder?.order ?? 0,
    );

    Navigator.pop(context, folder);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(AppColors.space24),
        child: SingleChildScrollView(
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
                      color: _selectedColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    child: Icon(_selectedIcon, color: _selectedColor, size: 28),
                  ),
                  const SizedBox(width: AppColors.space16),
                  Expanded(
                    child: Text(
                      widget.folder == null
                          ? 'Nueva Carpeta'
                          : 'Editar Carpeta',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppColors.space24),

              // Name input
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  labelText: 'Nombre de la carpeta',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppColors.space24),

              // Icon selector
              Text(
                'Icono',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppColors.space12),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                child: GridView.builder(
                  padding: const EdgeInsets.all(AppColors.space12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: AppColors.space8,
                    crossAxisSpacing: AppColors.space8,
                  ),
                  itemCount: Folder.availableIcons.length,
                  itemBuilder: (context, index) {
                    final icon = Folder.availableIcons[index];
                    final isSelected = icon == _selectedIcon;
                    return InkWell(
                      onTap: () => setState(() => _selectedIcon = icon),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusSm,
                          ),
                          border: isSelected
                              ? Border.all(color: _selectedColor, width: 2)
                              : null,
                        ),
                        child: Icon(
                          icon,
                          color: isSelected
                              ? _selectedColor
                              : AppColors.textSecondary,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppColors.space24),

              // Color selector
              Text(
                'Color',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppColors.space12),
              Wrap(
                spacing: AppColors.space12,
                runSpacing: AppColors.space12,
                children: NoteIconRegistry.palette.map((color) {
                  final isSelected = color == _selectedColor;
                  return InkWell(
                    onTap: () => setState(() => _selectedColor = color),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected ? AppTheme.shadowMd : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 28,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppColors.space32),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppColors.space16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusMd,
                          ),
                        ),
                        side: const BorderSide(color: AppColors.borderColor),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: AppColors.space12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppColors.space16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusMd,
                          ),
                        ),
                      ),
                      child: Text(widget.folder == null ? 'Crear' : 'Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
