import 'package:flutter/material.dart';
import '../services/editor_config_service.dart';
import '../theme/app_colors.dart';
import '../theme/color_utils.dart';

/// Diálogo de configuración del editor avanzado
class EditorSettingsDialog extends StatefulWidget {
  final EditorConfig initialConfig;
  final Function(EditorConfig) onConfigChanged;

  const EditorSettingsDialog({
    super.key,
    required this.initialConfig,
    required this.onConfigChanged,
  });

  @override
  State<EditorSettingsDialog> createState() => _EditorSettingsDialogState();
}

class _EditorSettingsDialogState extends State<EditorSettingsDialog> {
  late EditorConfig _config;
  final EditorConfigService _configService = EditorConfigService();

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
  }

  void _updateConfig(EditorConfig newConfig) {
    setState(() {
      _config = newConfig;
    });
  }

  Future<void> _saveConfig() async {
    await _configService.setEditorConfig(_config);
    widget.onConfigChanged(_config);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _resetToDefaults() async {
    final defaultConfig = EditorConfig.defaultConfig();
    await _configService.setEditorConfig(defaultConfig);
    _updateConfig(defaultConfig);
    widget.onConfigChanged(defaultConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Configuración del Editor',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Contenido
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Funciones del Editor'),
                    _buildToggleOption(
                      'Resaltado de sintaxis',
                      'Colorear código y Markdown automáticamente',
                      Icons.palette,
                      _config.syntaxHighlighting,
                      (value) => _updateConfig(_config.copyWith(syntaxHighlighting: value)),
                    ),
                    _buildToggleOption(
                      'Autocompletado',
                      'Sugerencias inteligentes mientras escribes',
                      Icons.auto_awesome,
                      _config.autoComplete,
                      (value) => _updateConfig(_config.copyWith(autoComplete: value)),
                    ),
                    _buildToggleOption(
                      'Números de línea',
                      'Mostrar numeración en el lateral izquierdo',
                      Icons.format_list_numbered,
                      _config.showLineNumbers,
                      (value) => _updateConfig(_config.copyWith(showLineNumbers: value)),
                    ),
                    _buildToggleOption(
                      'Minimap',
                      'Vista general del documento en el lateral',
                      Icons.map,
                      _config.showMinimap,
                      (value) => _updateConfig(_config.copyWith(showMinimap: value)),
                    ),
                    _buildToggleOption(
                      'Ajuste de línea',
                      'Envolver texto largo automáticamente',
                      Icons.wrap_text,
                      _config.wordWrap,
                      (value) => _updateConfig(_config.copyWith(wordWrap: value)),
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('Formato de Texto'),
                    _buildSliderOption(
                      'Tamaño de fuente',
                      Icons.text_fields,
                      _config.fontSize,
                      10.0,
                      24.0,
                      1.0,
                      '${_config.fontSize.toInt()}px',
                      (value) => _updateConfig(_config.copyWith(fontSize: value)),
                    ),
                    _buildDropdownOption(
                      'Familia de fuente',
                      Icons.font_download,
                      _config.fontFamily,
                      ['monospace', 'serif', 'sans-serif', 'Courier New', 'Roboto Mono'],
                      (value) => _updateConfig(_config.copyWith(fontFamily: value)),
                    ),
                    _buildSliderOption(
                      'Tamaño de tabulación',
                      Icons.keyboard_tab,
                      _config.tabSize.toDouble(),
                      2.0,
                      8.0,
                      1.0,
                      '${_config.tabSize} espacios',
                      (value) => _updateConfig(_config.copyWith(tabSize: value.toInt())),
                    ),
                    _buildToggleOption(
                      'Insertar espacios',
                      'Usar espacios en lugar de tabulaciones',
                      Icons.space_bar,
                      _config.insertSpaces,
                      (value) => _updateConfig(_config.copyWith(insertSpaces: value)),
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('Funciones Automáticas'),
                    _buildToggleOption(
                      'Autoguardado',
                      'Guardar cambios automáticamente',
                      Icons.save,
                      _config.autoSave,
                      (value) => _updateConfig(_config.copyWith(autoSave: value)),
                    ),
                    if (_config.autoSave)
                      _buildSliderOption(
                        'Retraso del autoguardado',
                        Icons.timer,
                        _config.autoSaveDelay.toDouble(),
                        500.0,
                        10000.0,
                        500.0,
                        '${(_config.autoSaveDelay / 1000).toStringAsFixed(1)}s',
                        (value) => _updateConfig(_config.copyWith(autoSaveDelay: value.toInt())),
                      ),
                    _buildToggleOption(
                      'Coincidencia de corchetes',
                      'Resaltar corchetes correspondientes',
                      Icons.code,
                      _config.bracketMatching,
                      (value) => _updateConfig(_config.copyWith(bracketMatching: value)),
                    ),
                    _buildToggleOption(
                      'Mostrar espacios en blanco',
                      'Ver espacios y tabulaciones como puntos',
                      Icons.visibility,
                      _config.showWhitespace,
                      (value) => _updateConfig(_config.copyWith(showWhitespace: value)),
                    ),
                    _buildToggleOption(
                      'Eliminar espacios finales',
                      'Limpiar espacios al final de línea al guardar',
                      Icons.cleaning_services,
                      _config.trimTrailingWhitespace,
                      (value) => _updateConfig(_config.copyWith(trimTrailingWhitespace: value)),
                    ),
                  ],
                ),
              ),
            ),
            
            // Botones
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.restore),
                  label: const Text('Restaurar valores por defecto'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildToggleOption(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: value ? AppColors.primary : Colors.grey,
        ),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
        onTap: () => onChanged(!value),
      ),
    );
  }

  Widget _buildSliderOption(
    String title,
    IconData icon,
    double value,
    double min,
    double max,
    double divisions,
    String valueText,
    Function(double) onChanged,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacityCompat(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    valueText,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider.adaptive(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) / divisions).round(),
              onChanged: onChanged,
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownOption(
    String title,
    IconData icon,
    String value,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            DropdownButton<String>(
              value: value,
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
              items: options.map((option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              underline: Container(
                height: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}