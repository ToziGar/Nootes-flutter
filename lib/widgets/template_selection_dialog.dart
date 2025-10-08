import 'package:flutter/material.dart';
import '../services/template_service.dart';
import '../theme/app_theme.dart';

/// Dialog para seleccionar y usar plantillas de notas
class TemplateSelectionDialog extends StatefulWidget {
  final Function(String content) onTemplateSelected;
  
  const TemplateSelectionDialog({
    super.key,
    required this.onTemplateSelected,
  });

  @override
  State<TemplateSelectionDialog> createState() => _TemplateSelectionDialogState();
}

class _TemplateSelectionDialogState extends State<TemplateSelectionDialog> {
  final TemplateService _templateService = TemplateService();
  List<NoteTemplate> _templates = [];
  List<NoteTemplate> _filteredTemplates = [];
  String _selectedCategory = 'Todas';
  String _searchQuery = '';
  bool _isLoading = true;

  final List<String> _categories = [
    'Todas',
    'Trabajo',
    'Personal',
    'Productividad',
    'Aprendizaje',
    'Creatividad',
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final templates = await _templateService.getAllTemplates();
    if (mounted) {
      setState(() {
        _templates = templates;
        _filteredTemplates = templates;
        _isLoading = false;
      });
    }
  }

  void _filterTemplates() {
    List<NoteTemplate> filtered = _templates;

    // Filtrar por categoría
    if (_selectedCategory != 'Todas') {
      filtered = filtered.where((template) => template.category == _selectedCategory).toList();
    }

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((template) {
        return template.name.toLowerCase().contains(query) ||
               template.description.toLowerCase().contains(query) ||
               template.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    setState(() {
      _filteredTemplates = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Seleccionar Plantilla',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search and filters
            Row(
              children: [
                // Search bar
                Expanded(
                  flex: 2,
                  child: TextField(
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Buscar plantillas...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _filterTemplates();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                
                // Category filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                        _filterTemplates();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Templates grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTemplates.isEmpty
                      ? const Center(
                          child: Text(
                            'No se encontraron plantillas',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: _filteredTemplates.length,
                          itemBuilder: (context, index) {
                            final template = _filteredTemplates[index];
                            return _TemplateCard(
                              template: template,
                              onTap: () => _selectTemplate(template),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectTemplate(NoteTemplate template) {
    // Si la plantilla tiene variables, mostrar dialog para completarlas
    if (template.variables.isNotEmpty) {
      _showVariableDialog(template);
    } else {
      // Usar plantilla directamente
      final content = _templateService.createNoteFromTemplate(template, {});
      widget.onTemplateSelected(content);
      Navigator.of(context).pop();
    }
  }

  void _showVariableDialog(NoteTemplate template) {
    showDialog(
      context: context,
      builder: (context) => _VariableDialog(
        template: template,
        onConfirm: (values) {
          final content = _templateService.createNoteFromTemplate(template, values);
          widget.onTemplateSelected(content);
          Navigator.of(context).pop(); // Close variable dialog
          Navigator.of(context).pop(); // Close template dialog
        },
      ),
    );
  }
}

/// Card para mostrar una plantilla
class _TemplateCard extends StatelessWidget {
  final NoteTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and category
              Row(
                children: [
                  Text(
                    template.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      template.category,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Template name
              Text(
                template.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              
              // Description
              Expanded(
                child: Text(
                  template.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // Tags
              if (template.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: template.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: AppColors.textMuted,
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
      ),
    );
  }
}

/// Dialog para completar variables de la plantilla
class _VariableDialog extends StatefulWidget {
  final NoteTemplate template;
  final Function(Map<String, String>) onConfirm;

  const _VariableDialog({
    required this.template,
    required this.onConfirm,
  });

  @override
  State<_VariableDialog> createState() => _VariableDialogState();
}

class _VariableDialogState extends State<_VariableDialog> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final variable in widget.template.variables) {
      _controllers[variable] = TextEditingController();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        'Completar plantilla: ${widget.template.name}',
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.template.variables.map((variable) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _controllers[variable],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: _getVariableLabel(variable),
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: () {
            final values = <String, String>{};
            for (final variable in widget.template.variables) {
              values[variable] = _controllers[variable]?.text ?? '';
            }
            widget.onConfirm(values);
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Crear nota'),
        ),
      ],
    );
  }

  String _getVariableLabel(String variable) {
    // Convertir nombres de variables a etiquetas legibles
    switch (variable) {
      case 'fecha':
        return 'Fecha';
      case 'titulo':
        return 'Título';
      case 'nombre_proyecto':
        return 'Nombre del proyecto';
      case 'objetivo':
        return 'Objetivo';
      case 'presupuesto':
        return 'Presupuesto';
      case 'titulo_libro':
        return 'Título del libro';
      case 'autor':
        return 'Autor';
      default:
        return variable.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}