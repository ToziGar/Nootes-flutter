import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/preferences_service.dart';
import '../services/app_service.dart';
import '../widgets/export_import_dialog.dart';
import '../widgets/gradient_button.dart';
// import 'profile_page.dart'; // Navegación directa reemplazada por editor inline

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _authService = AuthService.instance;

  String _themeMode = 'Sistema'; // Claro, Oscuro, Sistema
  bool _notifications = true;
  bool _autoSave = true;
  bool _backupEnabled = false;
  String _language = 'Español';
  String _defaultView = 'Workspace';
  Timer? _saveDebounce;
  bool _saving = false;
  DateTime? _lastSaved;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Preferencias locales para fallback inmediato
    final themeMode = await PreferencesService.getThemeModeString();
    final language = await PreferencesService.getLanguageString();

    // Cargar remotas desde Firestore (si existen)
    final uid = _authService.currentUser?.uid;
    Map<String, dynamic>? remote;
    if (uid != null) {
      try {
        remote = await FirestoreService.instance.getUserSettings(uid: uid);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _themeMode = remote?['themeMode'] as String? ?? themeMode;
      _language = remote?['language'] as String? ?? language;
      _notifications = (remote?['notifications'] as bool?) ?? _notifications;
      _autoSave = (remote?['autoSave'] as bool?) ?? _autoSave;
      _backupEnabled = (remote?['backupEnabled'] as bool?) ?? _backupEnabled;
      _defaultView = (remote?['defaultView'] as String?) ?? _defaultView;
    });
  }

  Future<void> _saveSettings() async {
    final uid = _authService.currentUser?.uid;
    try {
      // Persistir localmente para arranque rápido
      switch (_themeMode) {
        case 'Claro':
          await PreferencesService.setThemeMode(ThemeMode.light);
          break;
        case 'Oscuro':
          await PreferencesService.setThemeMode(ThemeMode.dark);
          break;
        case 'Sistema':
        default:
          await PreferencesService.setThemeMode(ThemeMode.system);
      }
      await PreferencesService.setLocale(
        Locale(_language == 'English' ? 'en' : 'es', ''),
      );

      // Persistir en Firestore (si hay usuario)
      if (uid != null) {
        await FirestoreService.instance.updateUserSettings(
          uid: uid,
          data: {
            'themeMode': _themeMode,
            'language': _language,
            'notifications': _notifications,
            'autoSave': _autoSave,
            'backupEnabled': _backupEnabled,
            'defaultView': _defaultView,
          },
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Configuración guardada'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _exportData() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;

      final notes = await FirestoreService.instance.listNotes(uid: uid);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) =>
            ExportImportDialog(notes: notes, onImport: _handleImport),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _handleImport(List<Map<String, dynamic>> importedNotes) async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;

      // Importar todas las notas
      for (final note in importedNotes) {
        await FirestoreService.instance.createNote(
          uid: uid,
          data: {
            'title': note['title'] ?? '',
            'content': note['content'] ?? '',
            'tags': note['tags'] ?? [],
            'pinned': note['pinned'] ?? false,
          },
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${importedNotes.length} notas importadas correctamente',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al importar: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _importData() async {
    await _exportData(); // Abre el mismo diálogo que tiene ambas opciones
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceLight2,
        elevation: 0,
        title: const Text(
          'Ajustes',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryLight,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimaryLight,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppColors.space16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _saving
                  ? Row(
                      key: const ValueKey('saving'),
                      children: const [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Guardando...',
                          style: TextStyle(color: AppColors.textSecondaryLight),
                        ),
                      ],
                    )
                  : (_lastSaved != null)
                  ? Row(
                      key: const ValueKey('saved'),
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Guardado',
                          style: const TextStyle(
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey('idle')),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppColors.space24),
        children: [
          // Sección: Perfil
          _buildSectionHeader('Perfil', Icons.person_rounded),
          const SizedBox(height: AppColors.space16),
          _buildProfileCard(),
          const SizedBox(height: AppColors.space32),

          // Sección: Apariencia
          _buildSectionHeader('Apariencia', Icons.palette_rounded),
          const SizedBox(height: AppColors.space16),
          _buildSettingCard(
            title: 'Tema',
            subtitle: _themeMode,
            icon: Icons.palette_rounded,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryLight,
            ),
            onTap: () => _showThemeDialog(),
          ),
          const SizedBox(height: AppColors.space12),
          _buildSettingCard(
            title: 'Idioma',
            subtitle: _language,
            icon: Icons.language_rounded,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryLight,
            ),
            onTap: () => _showLanguageDialog(),
          ),
          const SizedBox(height: AppColors.space12),
          _buildSettingCard(
            title: 'Vista predeterminada',
            subtitle: _defaultView,
            icon: Icons.view_module_rounded,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryLight,
            ),
            onTap: () => _showDefaultViewDialog(),
          ),
          const SizedBox(height: AppColors.space32),

          // Sección: Notificaciones
          _buildSectionHeader('Notificaciones', Icons.notifications_rounded),
          const SizedBox(height: AppColors.space16),
          _buildSettingCard(
            title: 'Notificaciones push',
            subtitle: 'Recibe notificaciones importantes',
            icon: Icons.notifications_active_rounded,
            trailing: Switch(
              value: _notifications,
              onChanged: (value) {
                setState(() => _notifications = value);
                _scheduleSave();
              },
              activeThumbColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppColors.space32),

          // Sección: Editor
          _buildSectionHeader('Editor', Icons.edit_rounded),
          const SizedBox(height: AppColors.space16),
          _buildSettingCard(
            title: 'Autoguardado',
            subtitle: 'Guardar automáticamente cada 30 segundos',
            icon: Icons.save_rounded,
            trailing: Switch(
              value: _autoSave,
              onChanged: (value) {
                setState(() => _autoSave = value);
                _scheduleSave();
              },
              activeThumbColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppColors.space32),

          // Sección: Datos
          _buildSectionHeader('Datos', Icons.storage_rounded),
          const SizedBox(height: AppColors.space16),
          _buildSettingCard(
            title: 'Backup automático',
            subtitle: 'Respaldar datos cada día',
            icon: Icons.backup_rounded,
            trailing: Switch(
              value: _backupEnabled,
              onChanged: (value) {
                setState(() => _backupEnabled = value);
                _scheduleSave();
              },
              activeThumbColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppColors.space12),
          _buildSettingCard(
            title: 'Exportar datos',
            subtitle: 'Descargar todas tus notas',
            icon: Icons.download_rounded,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryLight,
            ),
            onTap: _exportData,
          ),
          const SizedBox(height: AppColors.space12),
          _buildSettingCard(
            title: 'Importar datos',
            subtitle: 'Cargar notas desde un archivo',
            icon: Icons.upload_rounded,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryLight,
            ),
            onTap: _importData,
          ),
          const SizedBox(height: AppColors.space32),

          // Sección: Cuenta
          _buildSectionHeader('Cuenta', Icons.account_circle_rounded),
          const SizedBox(height: AppColors.space16),
          _buildSettingCard(
            title: 'Cerrar sesión',
            subtitle: 'Salir de tu cuenta',
            icon: Icons.logout_rounded,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.danger,
            ),
            onTap: _confirmLogout,
            textColor: AppColors.danger,
          ),
          const SizedBox(height: AppColors.space12),
          _buildSettingCard(
            title: 'Restablecer ajustes',
            subtitle: 'Vuelve a los valores predeterminados',
            icon: Icons.restore_rounded,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryLight,
            ),
            onTap: _confirmResetSettings,
          ),
          const SizedBox(height: AppColors.space48),

          // Botón Guardar
          GradientButton(
            onPressed: _saveSettings,
            icon: Icons.check_circle_rounded,
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppColors.space8),
          decoration: BoxDecoration(
            gradient: AppTheme.gradientPrimary,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: AppColors.space12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final email = _authService.currentUser?.email ?? 'Usuario';
    return Container(
      padding: const EdgeInsets.all(AppColors.space20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight2,
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        border: Border.all(color: AppColors.borderColorLight),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppTheme.gradientPrimary,
              shape: BoxShape.circle,
              boxShadow: AppTheme.shadowSm,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: AppColors.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryLight,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.gradientAccent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: AppTheme.shadowSm,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppColors.space8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _profileChip(icon: Icons.badge_rounded, label: 'Perfil'),
                    _profileChip(
                      icon: Icons.translate_rounded,
                      label: _language,
                    ),
                    _profileChip(
                      icon: Icons.palette_rounded,
                      label: _themeMode,
                    ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _openInlineProfileEditor,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  // Pequeño chip de información visual
  // ignore: unused_element
  static Widget _profileChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight3,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderColorLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondaryLight),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  void _openInlineProfileEditor() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    // Cargar perfil actual
    Map<String, dynamic>? data;
    try {
      data = await FirestoreService.instance.getUserProfile(uid: uid);
    } catch (_) {}

    final fullNameCtrl = TextEditingController(
      text: (data?['fullName'] ?? '').toString(),
    );
    final usernameCtrl = TextEditingController(
      text: (data?['username'] ?? '').toString(),
    );
    final organizationCtrl = TextEditingController(
      text: (data?['organization'] ?? '').toString(),
    );
    final roleCtrl = TextEditingController(
      text: (data?['role'] ?? '').toString(),
    );
    String selectedLanguage = (data?['language'] ?? _language);
    // Normaliza a valores permitidos por el Dropdown
    if (selectedLanguage != 'Español' && selectedLanguage != 'English') {
      final lower = selectedLanguage.toString().toLowerCase();
      if (lower == 'es' || lower.startsWith('es')) {
        selectedLanguage = 'Español';
      } else if (lower == 'en' || lower.startsWith('en')) {
        selectedLanguage = 'English';
      } else {
        selectedLanguage = (_language == 'Español' || _language == 'English')
            ? _language
            : 'Español';
      }
    }
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppColors.radiusXl),
        ),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppColors.space20,
            right: AppColors.space20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppColors.space20,
            top: AppColors.space20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.gradientPrimary,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Editar perfil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _InlineField(
                  controller: fullNameCtrl,
                  label: 'Nombre completo',
                  icon: Icons.person_outline_rounded,
                  requiredField: true,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                _InlineField(
                  controller: usernameCtrl,
                  label: 'Usuario (handle)',
                  icon: Icons.alternate_email_rounded,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null; // opcional
                    final ok =
                        RegExp(r'^[a-z0-9._]{3,20} ? ? ?$').hasMatch(value) ||
                        RegExp(r'^[a-z0-9._]{3,20} ?$').hasMatch(value) ||
                        RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(value);
                    return ok ? null : 'Solo minúsculas, números, . y _ (3-20)';
                  },
                ),
                const SizedBox(height: 10),
                _InlineField(
                  controller: organizationCtrl,
                  label: 'Organización',
                  icon: Icons.business_outlined,
                ),
                const SizedBox(height: 10),
                _InlineField(
                  controller: roleCtrl,
                  label: 'Rol',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Idioma',
                    prefixIcon: Icon(Icons.translate_rounded),
                  ),
                  initialValue: selectedLanguage,
                  items: const [
                    DropdownMenuItem(value: 'Español', child: Text('Español')),
                    DropdownMenuItem(value: 'English', child: Text('English')),
                  ],
                  onChanged: (v) => selectedLanguage = v ?? selectedLanguage,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false))
                            return;
                          final fullName = fullNameCtrl.text.trim();
                          final newUsername = usernameCtrl.text.trim();
                          try {
                            // Si cambió el handle y no está vacío, intentar reservarlo/cambiarlo
                            final prevUsername = (data?['username'] ?? '')
                                .toString();
                            if (newUsername.isNotEmpty &&
                                newUsername != prevUsername) {
                              await FirestoreService.instance.changeHandle(
                                uid: uid,
                                newUsername: newUsername,
                              );
                            }

                            await FirestoreService.instance.updateUserProfile(
                              uid: uid,
                              data: {
                                'fullName': fullName,
                                'username': newUsername,
                                'organization': organizationCtrl.text.trim(),
                                'role': roleCtrl.text.trim(),
                                'language': selectedLanguage,
                                'updatedAt': DateTime.now().toIso8601String(),
                              },
                            );

                            // Aplicar idioma inmediatamente
                            if (selectedLanguage != _language) {
                              final locale = selectedLanguage == 'English'
                                  ? const Locale('en', '')
                                  : const Locale('es', '');
                              AppService.changeLocale(locale);
                              await PreferencesService.setLocale(locale);
                            }
                            // Asegura que ambos contextos sigan montados
                            if (!mounted) return;
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Perfil actualizado'),
                              ),
                            );
                            // Refrescar cabecera de perfil
                            _loadSettings();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget trailing,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppColors.space16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight2,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.borderColorLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppColors.space8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: Icon(
                icon,
                color: textColor ?? AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppColors.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: AppColors.space4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceLight2,
        title: const Text(
          'Seleccionar tema',
          style: TextStyle(color: AppColors.textPrimaryLight),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption('Claro', ThemeMode.light),
            _buildThemeOption('Oscuro', ThemeMode.dark),
            _buildThemeOption('Sistema', ThemeMode.system),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String name, ThemeMode mode) {
    return ListTile(
      title: Text(
        name,
        style: const TextStyle(color: AppColors.textPrimaryLight),
      ),
      trailing: _themeMode == name
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: () async {
        setState(() => _themeMode = name);
        Navigator.pop(context);

        // Aplicar el cambio de tema inmediatamente
        AppService.changeTheme(mode);
        _scheduleSave();
      },
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceLight2,
        title: const Text(
          'Seleccionar idioma',
          style: TextStyle(color: AppColors.textPrimaryLight),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('Español', 'es'),
            _buildLanguageOption('English', 'en'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String name, String code) {
    return ListTile(
      title: Text(
        name,
        style: const TextStyle(color: AppColors.textPrimaryLight),
      ),
      trailing: _language == name
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: () async {
        setState(() => _language = name);
        Navigator.pop(context);

        // Aplicar el cambio de idioma inmediatamente
        final locale = Locale(code, '');
        AppService.changeLocale(locale);
        await PreferencesService.setLocale(locale);
        _scheduleSave();
      },
    );
  }

  void _showDefaultViewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceLight2,
        title: const Text(
          'Vista predeterminada',
          style: TextStyle(color: AppColors.textPrimaryLight),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildViewOption('Workspace', Icons.dashboard_rounded),
            _buildViewOption('Lista', Icons.list_rounded),
            _buildViewOption('Colecciones', Icons.folder_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildViewOption(String name, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        name,
        style: const TextStyle(color: AppColors.textPrimaryLight),
      ),
      trailing: _defaultView == name
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: () {
        setState(() => _defaultView = name);
        Navigator.pop(context);
        _scheduleSave();
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight2,
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(color: AppColors.textPrimaryLight),
        ),
        content: const Text(
          '¿Estás seguro que deseas cerrar sesión?',
          style: TextStyle(color: AppColors.textSecondaryLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              // Guardar el contexto antes del await
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              try {
                await _authService.signOut();
                // También cerrar sesión en FirebaseAuth si está en uso (AuthGate)
                try {
                  await fb.FirebaseAuth.instance.signOut();
                } catch (_) {}
                if (!ctx.mounted) return;
                // Cerrar diálogo
                Navigator.pop(ctx);
                // Navegar a login y limpiar toda la pila de navegación
                if (mounted) {
                  navigator.pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al cerrar sesión: $e'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    setState(() {
      _saving = true;
    });
    _saveDebounce = Timer(const Duration(milliseconds: 800), () async {
      await _saveSettings();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _lastSaved = DateTime.now();
      });
    });
  }

  Future<void> _confirmResetSettings() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight2,
        title: const Text(
          'Restablecer ajustes',
          style: TextStyle(color: AppColors.textPrimaryLight),
        ),
        content: const Text(
          'Esto restaurará los valores predeterminados de apariencia y preferencias.',
          style: TextStyle(color: AppColors.textSecondaryLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _themeMode = 'Sistema';
      _language = 'Español';
      _notifications = true;
      _autoSave = true;
      _backupEnabled = false;
      _defaultView = 'Workspace';
    });

    // Aplicar inmediatamente
    AppService.changeTheme(ThemeMode.system);
    AppService.changeLocale(const Locale('es', ''));
    await PreferencesService.setThemeMode(ThemeMode.system);
    await PreferencesService.setLocale(const Locale('es', ''));
    await _saveSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ajustes restablecidos')));
  }
}

// Campo reutilizable para el editor inline del perfil
class _InlineField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool requiredField;
  final String? Function(String?)? validator;

  const _InlineField({
    required this.controller,
    required this.label,
    required this.icon,
    this.requiredField = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}
