import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/preferences_service.dart';
import '../services/app_service.dart';
import '../widgets/export_import_dialog.dart';

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
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    // Cargar configuraciones reales desde PreferencesService
    final themeMode = await PreferencesService.getThemeModeString();
    final language = await PreferencesService.getLanguageString();
    
    if (mounted) {
      setState(() {
        _themeMode = themeMode;
        _language = language;
      });
    }
  }
  
  Future<void> _saveSettings() async {
    // TODO: Guardar configuraciones en Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Configuración guardada'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  Future<void> _exportData() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;
      
      final notes = await FirestoreService.instance.listNotes(uid: uid);
      
      if (!mounted) return;
      
      await showDialog(
        context: context,
        builder: (context) => ExportImportDialog(
          notes: notes,
          onImport: _handleImport,
        ),
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
          content: Text('${importedNotes.length} notas importadas correctamente'),
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Ajustes',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
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
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            onTap: () => _showThemeDialog(),
          ),
          const SizedBox(height: AppColors.space12),
          _buildSettingCard(
            title: 'Idioma',
            subtitle: _language,
            icon: Icons.language_rounded,
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            onTap: () => _showLanguageDialog(),
          ),
          const SizedBox(height: AppColors.space12),
          _buildSettingCard(
            title: 'Vista predeterminada',
            subtitle: _defaultView,
            icon: Icons.view_module_rounded,
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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
              onChanged: (value) => setState(() => _notifications = value),
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
              onChanged: (value) => setState(() => _autoSave = value),
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
              onChanged: (value) => setState(() => _backupEnabled = value),
              activeThumbColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppColors.space12),
          _buildSettingCard(
            title: 'Exportar datos',
            subtitle: 'Descargar todas tus notas',
            icon: Icons.download_rounded,
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            onTap: _exportData,
          ),
          const SizedBox(height: AppColors.space12),
          _buildSettingCard(
            title: 'Importar datos',
            subtitle: 'Cargar notas desde un archivo',
            icon: Icons.upload_rounded,
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.danger),
            onTap: _confirmLogout,
            textColor: AppColors.danger,
          ),
          const SizedBox(height: AppColors.space48),
          
          // Botón Guardar
          FilledButton(
            onPressed: _saveSettings,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: AppColors.space16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
            ),
            child: const Text(
              'Guardar Cambios',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
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
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
  
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(AppColors.space20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppTheme.gradientPrimary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: AppColors.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _authService.currentUser?.email ?? 'Usuario',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppColors.space4),
                const Text(
                  'Cuenta Premium',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Editar perfil
            },
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
          ),
        ],
      ),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppColors.space8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: Icon(icon, color: textColor ?? AppColors.primary, size: 20),
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
                      color: textColor ?? AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppColors.space4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
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
        backgroundColor: AppColors.surface,
        title: const Text('Seleccionar tema', style: TextStyle(color: AppColors.textPrimary)),
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
      title: Text(name, style: const TextStyle(color: AppColors.textPrimary)),
      trailing: _themeMode == name
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: () async {
        setState(() => _themeMode = name);
        Navigator.pop(context);
        
        // Aplicar el cambio de tema inmediatamente
        AppService.changeTheme(mode);
      },
    );
  }
  
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Seleccionar idioma', style: TextStyle(color: AppColors.textPrimary)),
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
      title: Text(name, style: const TextStyle(color: AppColors.textPrimary)),
      trailing: _language == name
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: () async {
        setState(() => _language = name);
        Navigator.pop(context);
        
        // Aplicar el cambio de idioma inmediatamente
        final locale = Locale(code, '');
        AppService.changeLocale(locale);
      },
    );
  }
  
  void _showDefaultViewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Vista predeterminada', style: TextStyle(color: AppColors.textPrimary)),
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
      title: Text(name, style: const TextStyle(color: AppColors.textPrimary)),
      trailing: _defaultView == name
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: () {
        setState(() => _defaultView = name);
        Navigator.pop(context);
      },
    );
  }
  
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cerrar sesión', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          '¿Estás seguro que deseas cerrar sesión?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
