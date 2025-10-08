import 'package:flutter/material.dart';
import '../services/toast_service.dart';
import '../theme/app_colors.dart';

/// Página de demostración para las nuevas notificaciones toast
class ToastDemoPage extends StatelessWidget {
  const ToastDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎉 Demo: Notificaciones Toast'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F9FA),
              Color(0xFFE9ECEF),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBasicToasts(),
                  const SizedBox(height: 32),
                  _buildAdvancedToasts(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicToasts() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✨ Notificaciones Básicas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildToastButton(
                'Éxito',
                Icons.check_circle,
                AppColors.success,
                () => ToastService.success('¡Operación completada exitosamente!'),
              ),
              _buildToastButton(
                'Error',
                Icons.error,
                AppColors.error,
                () => ToastService.error('Ocurrió un error inesperado'),
              ),
              _buildToastButton(
                'Advertencia',
                Icons.warning,
                AppColors.warning,
                () => ToastService.warning('Atención: Revisa tu configuración'),
              ),
              _buildToastButton(
                'Información',
                Icons.info,
                AppColors.info,
                () => ToastService.info('Nueva función disponible'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedToasts() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🚀 Características Avanzadas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildToastButton(
                'Cargando',
                Icons.hourglass_empty,
                AppColors.primary,
                () {
                  ToastService.loading('Procesando datos...');
                  // Simular proceso
                  Future.delayed(const Duration(seconds: 3), () {
                    ToastService.hide();
                    ToastService.success('¡Proceso completado!');
                  });
                },
              ),
              _buildToastButton(
                'Con Acción',
                Icons.touch_app,
                AppColors.accent,
                () => ToastService.withAction(
                  message: 'Archivo eliminado',
                  action: 'DESHACER',
                  onAction: () => ToastService.info('¡Acción deshecha!'),
                  type: ToastType.warning,
                ),
              ),
              _buildToastButton(
                'Duración Larga',
                Icons.schedule,
                AppColors.secondary,
                () => ToastService.info(
                  'Esta notificación dura 8 segundos',
                  duration: const Duration(seconds: 8),
                ),
              ),
              _buildToastButton(
                'Multiple',
                Icons.layers,
                AppColors.primaryDark,
                () {
                  ToastService.success('Primera notificación');
                  ToastService.info('Segunda notificación');
                  ToastService.warning('Tercera notificación');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToastButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
    );
  }
}