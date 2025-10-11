import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/advanced_sharing_service.dart';

// Diálogo completo para editar eventos del calendario
class EditEventDialog extends StatefulWidget {
  final CalendarEvent event;
  final Function(CalendarEvent) onSave;

  const EditEventDialog({super.key, required this.event, required this.onSave});

  @override
  State<EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<EditEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late DateTime _startTime;
  DateTime? _endTime;
  late CalendarEventType _eventType;
  late bool _isAllDay;
  late List<String> _reminders;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(
      text: widget.event.description,
    );
    _locationController = TextEditingController(
      text: widget.event.location ?? '',
    );
    _startTime = widget.event.startTime;
    _endTime = widget.event.endTime;
    _eventType = widget.event.type;
    _isAllDay = widget.event.isAllDay;
    _reminders = List.from(widget.event.reminders);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.edit_calendar_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Editar Evento',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Título del evento
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título del evento',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'El título es requerido' : null,
                ),
                const SizedBox(height: 16),

                // Descripción
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description_rounded),
                    hintText: 'Describe los detalles del evento...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Tipo de evento
                DropdownButtonFormField<CalendarEventType>(
                  value: _eventType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de evento',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: CalendarEventType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(_getEventTypeIcon(type), size: 20),
                          const SizedBox(width: 8),
                          Text(_getEventTypeLabel(type)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _eventType = value!),
                ),
                const SizedBox(height: 16),

                // Todo el día
                Card(
                  child: SwitchListTile(
                    title: const Text('Todo el día'),
                    subtitle: const Text('El evento durará todo el día'),
                    value: _isAllDay,
                    onChanged: (value) => setState(() {
                      _isAllDay = value;
                      if (value) {
                        _endTime = null;
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // Fecha y hora de inicio
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.schedule_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text('Fecha y hora de inicio'),
                    subtitle: Text(_formatDateTime(_startTime)),
                    trailing: const Icon(Icons.edit_rounded),
                    onTap: _selectStartDateTime,
                  ),
                ),

                // Fecha y hora de fin (solo si no es todo el día)
                if (!_isAllDay) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.event_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text('Fecha y hora de fin'),
                      subtitle: Text(
                        _endTime != null
                            ? _formatDateTime(_endTime!)
                            : 'No especificado',
                      ),
                      trailing: const Icon(Icons.edit_rounded),
                      onTap: _selectEndDateTime,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Ubicación
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación (opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_rounded),
                    hintText: 'Sala de juntas, enlace de videoconferencia...',
                  ),
                ),
                const SizedBox(height: 16),

                // Recordatorios
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notifications_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Recordatorios',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildReminderChip('15 min antes', '15'),
                            _buildReminderChip('1 hora antes', '60'),
                            _buildReminderChip('1 día antes', '1440'),
                            _buildReminderChip('1 semana antes', '10080'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _loading ? null : _saveEvent,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Guardar cambios'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReminderChip(String label, String value) {
    final isSelected = _reminders.contains(value);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _reminders.add(value);
          } else {
            _reminders.remove(value);
          }
        });
      },
    );
  }

  IconData _getEventTypeIcon(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.meeting:
        return Icons.video_call_rounded;
      case CalendarEventType.deadline:
        return Icons.schedule_rounded;
      case CalendarEventType.reminder:
        return Icons.notifications_rounded;
      case CalendarEventType.review:
        return Icons.rate_review_rounded;
    }
  }

  String _getEventTypeLabel(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.meeting:
        return 'Reunión';
      case CalendarEventType.deadline:
        return 'Fecha límite';
      case CalendarEventType.reminder:
        return 'Recordatorio';
      case CalendarEventType.review:
        return 'Revisión';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} a las ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectStartDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      if (!_isAllDay) {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_startTime),
        );
        if (time != null) {
          setState(() {
            _startTime = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
          });
        }
      } else {
        setState(() {
          _startTime = DateTime(date.year, date.month, date.day);
        });
      }
    }
  }

  Future<void> _selectEndDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endTime ?? _startTime.add(const Duration(hours: 1)),
      firstDate: _startTime,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _endTime ?? _startTime.add(const Duration(hours: 1)),
        ),
      );
      if (time != null) {
        setState(() {
          _endTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final updatedEvent = CalendarEvent(
        id: widget.event.id,
        noteId: widget.event.noteId,
        noteTitle: widget.event.noteTitle,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _eventType,
        startTime: _startTime,
        endTime: _endTime,
        attendeeIds: widget.event.attendeeIds,
        attendeeNames: widget.event.attendeeNames,
        createdBy: widget.event.createdBy,
        createdAt: widget.event.createdAt,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        isAllDay: _isAllDay,
        reminders: _reminders,
      );

      widget.onSave(updatedEvent);
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}
