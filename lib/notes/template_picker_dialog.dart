import 'package:flutter/material.dart';
import 'note_templates.dart';

/// Diálogo para seleccionar una plantilla de nota
class TemplatePickerDialog extends StatefulWidget {
  const TemplatePickerDialog({super.key});

  @override
  State<TemplatePickerDialog> createState() => _TemplatePickerDialogState();
}

class _TemplatePickerDialogState extends State<TemplatePickerDialog> {
  NoteTemplate? _selected;
  final Map<String, TextEditingController> _variables = {};

  @override
  void dispose() {
    for (var controller in _variables.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note_add_rounded, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Crear desde Plantilla',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _selected == null
                  ? _buildTemplateGrid()
                  : _buildVariablesForm(),
            ),
            
            // Actions
            if (_selected != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _selected = null;
                        _variables.clear();
                      }),
                      child: const Text('Atrás'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _createNote,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Crear Nota'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: BuiltInTemplates.all.length,
      itemBuilder: (context, index) {
        final template = BuiltInTemplates.all[index];
        return _TemplateCard(
          template: template,
          onTap: () {
            setState(() {
              _selected = template;
              // Inicializar controllers para las variables
              for (var varName in template.variables.keys) {
                _variables[varName] = TextEditingController();
              }
            });
          },
        );
      },
    );
  }

  Widget _buildVariablesForm() {
    final template = _selected!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Template info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: template.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(template.icon, color: template.color, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      template.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Variables form
          if (template.variables.isNotEmpty) ...[
            Text(
              'Personalizar Plantilla',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Completa los campos para personalizar tu nota:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            
            ...template.variables.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: _variables[entry.key],
                  decoration: InputDecoration(
                    labelText: entry.value,
                    hintText: 'Ej: ${_getExampleFor(entry.key)}',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(_getIconFor(entry.key)),
                  ),
                  maxLines: entry.key.contains('description') ? 3 : 1,
                ),
              );
            }).toList(),
          ],
          
          // Preview
          const SizedBox(height: 24),
          Text(
            'Vista Previa',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              _getPreview(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.white70,
              ),
              maxLines: 10,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getPreview() {
    final values = <String, String>{};
    _variables.forEach((key, controller) {
      values[key] = controller.text.isEmpty ? '{{$key}}' : controller.text;
    });
    return _selected!.applyVariables(values);
  }

  void _createNote() {
    final values = <String, String>{};
    _variables.forEach((key, controller) {
      values[key] = controller.text.isEmpty ? _getExampleFor(key) : controller.text;
    });
    
    final result = {
      'title': _getTitleFor(_selected!),
      'content': _selected!.applyVariables(values),
      'tags': _selected!.tags,
    };
    
    Navigator.pop(context, result);
  }

  String _getTitleFor(NoteTemplate template) {
    switch (template.id) {
      case 'daily':
        final now = DateTime.now();
        return 'Diario ${now.day}/${now.month}/${now.year}';
      case 'meeting':
        final project = _variables['project']?.text ?? 'Reunión';
        return project;
      case 'todo':
        final context = _variables['context']?.text ?? 'Tareas';
        return context;
      case 'recipe':
        return _variables['recipeName']?.text ?? 'Receta';
      case 'project':
        return _variables['projectName']?.text ?? 'Proyecto';
      case 'learning':
        return _variables['topic']?.text ?? 'Aprendizaje';
      case 'weekly':
        final now = DateTime.now();
        return 'Semana ${_getWeekNumber(now)} - ${now.year}';
      default:
        return template.name;
    }
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return (days / 7).ceil() + 1;
  }

  String _getExampleFor(String key) {
    switch (key) {
      case 'mood':
        return '😊 Feliz';
      case 'weather':
        return '☀️ Soleado';
      case 'project':
        return 'Proyecto X';
      case 'organizer':
        return 'Juan Pérez';
      case 'context':
        return 'Trabajo';
      case 'recipeName':
        return 'Paella';
      case 'servings':
        return '4';
      case 'projectName':
        return 'App Móvil';
      case 'deadline':
        return '31/12/2025';
      case 'topic':
        return 'Flutter';
      case 'source':
        return 'Documentación oficial';
      case 'challenge':
        return '¿Cómo mejorar la productividad?';
      case 'weekNumber':
        return '${_getWeekNumber(DateTime.now())}';
      default:
        return '';
    }
  }

  IconData _getIconFor(String key) {
    switch (key) {
      case 'mood':
        return Icons.mood_rounded;
      case 'weather':
        return Icons.wb_sunny_rounded;
      case 'project':
      case 'projectName':
        return Icons.work_rounded;
      case 'organizer':
        return Icons.person_rounded;
      case 'context':
        return Icons.label_rounded;
      case 'recipeName':
        return Icons.restaurant_rounded;
      case 'servings':
        return Icons.people_rounded;
      case 'deadline':
        return Icons.event_rounded;
      case 'topic':
        return Icons.topic_rounded;
      case 'source':
        return Icons.link_rounded;
      case 'challenge':
        return Icons.help_outline_rounded;
      case 'weekNumber':
        return Icons.calendar_view_week_rounded;
      default:
        return Icons.edit_rounded;
    }
  }
}

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                template.color.withValues(alpha: 0.1),
                template.color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(template.icon, color: template.color, size: 32),
              const Spacer(),
              Text(
                template.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                template.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: template.tags.take(2).map((tag) {
                  return Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
