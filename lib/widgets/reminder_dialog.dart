import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/toast_service.dart';
import '../theme/app_theme.dart';
import '../theme/color_utils.dart';

/// Widget para programar recordatorios para una nota
class ReminderDialog extends StatefulWidget {
  final String noteId;
  final String noteTitle;
  
  const ReminderDialog({
    super.key,
    required this.noteId,
    required this.noteTitle,
  });

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  final NotificationService _notificationService = NotificationService();
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _messageController = TextEditingController();
  String _selectedPreset = 'custom';

  final Map<String, Duration> _presets = {
    '15m': Duration(minutes: 15),
    '1h': Duration(hours: 1),
    '3h': Duration(hours: 3),
    '1d': Duration(days: 1),
    '1w': Duration(days: 7),
    'custom': Duration.zero,
  };

  final Map<String, String> _presetLabels = {
    '15m': 'En 15 minutos',
    '1h': 'En 1 hora',
    '3h': 'En 3 horas',
    '1d': 'Mañana',
    '1w': 'En 1 semana',
    'custom': 'Personalizado',
  };

  @override
  void initState() {
    super.initState();
    _messageController.text = 'Recordatorio: ${widget.noteTitle}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Programar Recordatorio',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título de la nota
            Text(
              'Para: ${widget.noteTitle}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            
            // Presets de tiempo
            const Text(
              'Cuándo recordar:',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _presets.keys.map((preset) {
                return ChoiceChip(
                  label: Text(_presetLabels[preset]!),
                  selected: _selectedPreset == preset,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPreset = preset;
                        if (preset != 'custom') {
                          final now = DateTime.now();
                          _selectedDate = now.add(_presets[preset]!);
                          _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
                        }
                      });
                    }
                  },
                  selectedColor: AppColors.primary.withOpacityCompat(0.3),
                  labelStyle: TextStyle(
                    color: _selectedPreset == preset 
                        ? AppColors.primary 
                        : AppColors.textSecondary,
                  ),
                );
              }).toList(),
            ),
            
            // Fecha y hora personalizada (solo si es custom)
            if (_selectedPreset == 'custom') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              _selectedDate.hour,
                              _selectedDate.minute,
                            );
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.textSecondary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: const TextStyle(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (time != null) {
                          setState(() {
                            _selectedTime = time;
                            _selectedDate = DateTime(
                              _selectedDate.year,
                              _selectedDate.month,
                              _selectedDate.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.textSecondary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              _selectedTime.format(context),
                              style: const TextStyle(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Mensaje personalizado
            const Text(
              'Mensaje del recordatorio:',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Mensaje del recordatorio...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.textSecondary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              maxLines: 2,
            ),
          ],
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
          onPressed: _scheduleReminder,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('Programar'),
        ),
      ],
    );
  }

  Future<void> _scheduleReminder() async {
    try {
      await _notificationService.scheduleReminder(
        noteId: widget.noteId,
        noteTitle: widget.noteTitle,
        reminderTime: _selectedDate,
        message: _messageController.text.trim().isNotEmpty 
            ? _messageController.text.trim() 
            : null,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        ToastService.success('✓ Recordatorio programado');
      }
    } catch (e) {
      if (mounted) {
        ToastService.error('Error al programar recordatorio: $e');
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}