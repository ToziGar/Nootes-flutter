import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_colors.dart';
import '../utils/debug.dart';

/// Enum para tipos de toast
enum ToastType { success, error, warning, info, loading }

/// Clase para configuración de toast
class ToastConfig {
  final String message;
  final ToastType type;
  final Duration duration;
  final bool showProgress;
  final VoidCallback? onTap;
  final String? action;
  final VoidCallback? onAction;

  const ToastConfig({
    required this.message,
    this.type = ToastType.info,
    this.duration = const Duration(seconds: 4),
    this.showProgress = true,
    this.onTap,
    this.action,
    this.onAction,
  });
}

/// Servicio profesional para mostrar notificaciones tipo toast
class ToastService {
  static final ToastService _instance = ToastService._internal();
  factory ToastService() => _instance;
  ToastService._internal();

  static ToastService get instance => _instance;

  OverlayEntry? _overlayEntry;
  Timer? _timer;
  final List<ToastConfig> _queue = [];
  bool _isShowing = false;
  BuildContext? _context;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _retryScheduled = false;

  /// Muestra un toast de éxito
  static void success(
    String message, {
    Duration? duration,
    VoidCallback? onTap,
  }) {
    instance._show(
      ToastConfig(
        message: message,
        type: ToastType.success,
        duration: duration ?? const Duration(seconds: 3),
        onTap: onTap,
      ),
    );
  }

  /// Muestra un toast de error
  static void error(String message, {Duration? duration, VoidCallback? onTap}) {
    instance._show(
      ToastConfig(
        message: message,
        type: ToastType.error,
        duration: duration ?? const Duration(seconds: 5),
        onTap: onTap,
      ),
    );
  }

  /// Muestra un toast de advertencia
  static void warning(
    String message, {
    Duration? duration,
    VoidCallback? onTap,
  }) {
    instance._show(
      ToastConfig(
        message: message,
        type: ToastType.warning,
        duration: duration ?? const Duration(seconds: 4),
        onTap: onTap,
      ),
    );
  }

  /// Muestra un toast de información
  static void info(String message, {Duration? duration, VoidCallback? onTap}) {
    instance._show(
      ToastConfig(
        message: message,
        type: ToastType.info,
        duration: duration ?? const Duration(seconds: 3),
        onTap: onTap,
      ),
    );
  }

  /// Muestra un toast de carga
  static void loading(String message) {
    instance._show(
      ToastConfig(
        message: message,
        type: ToastType.loading,
        duration: const Duration(seconds: 30), // Duración larga para loading
        showProgress: false,
      ),
    );
  }

  /// Muestra un toast con acción
  static void withAction({
    required String message,
    required String action,
    required VoidCallback onAction,
    ToastType type = ToastType.info,
    Duration? duration,
  }) {
    instance._show(
      ToastConfig(
        message: message,
        type: type,
        duration: duration ?? const Duration(seconds: 6),
        action: action,
        onAction: onAction,
      ),
    );
  }

  /// Oculta el toast actual
  static void hide() {
    instance._hide();
  }

  /// Limpia todos los toasts en cola
  static void clear() {
    instance._queue.clear();
    instance._hide();
  }

  void _show(ToastConfig config) {
    // Agregar a la cola si ya hay uno mostrándose
    if (_isShowing) {
      _queue.add(config);
      return;
    }

    _isShowing = true;
    _createOverlay(config);
  }

  void _createOverlay(ToastConfig config) {
    // Prefer getting Overlay from navigatorKey to ensure it's created
    OverlayState? overlay = _navigatorKey?.currentState?.overlay;

    if (overlay == null) {
      // Fallback to using a registered BuildContext
      final context = _getContext();
      if (context != null) {
        try {
          overlay = Overlay.of(context, rootOverlay: true);
        } catch (_) {
          // ignore and handle below
        }
      }
    }

    if (overlay == null) {
      // Overlay not ready yet. Schedule a one-shot retry shortly and bail out gracefully.
      if (!_retryScheduled) {
        _retryScheduled = true;
        Future.delayed(const Duration(milliseconds: 50), () {
          _retryScheduled = false;
          // Only retry if still showing this toast and overlay entry not yet inserted
          if (_isShowing && _overlayEntry == null) {
            _createOverlay(config);
          }
        });
      }
      logDebug('⚠️ ToastService: Overlay not ready yet, will retry shortly.');
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(config: config, onDismiss: _hide),
    );

    overlay.insert(_overlayEntry!);

    // Auto-hide después de la duración especificada
      if (config.type != ToastType.loading) {
      _timer = Timer(config.duration, _hide);
    }
  }

  void _hide() {
    _timer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;

    // Mostrar siguiente en cola
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      Future.delayed(const Duration(milliseconds: 200), () {
        _show(next);
      });
    }
  }

  BuildContext? _getContext() {
    return _context;
  }

  /// Método para registrar el contexto
  static void registerContext(BuildContext context) {
    instance._context = context;
  }

  /// Método para registrar el navigatorKey (recomendado)
  static void registerNavigatorKey(GlobalKey<NavigatorState> key) {
    instance._navigatorKey = key;
  }

  /// Método para inicializar el servicio con un contexto
  static void initialize() {
    // Inicialización del servicio
  }
}

/// Widget privado para mostrar el toast
class _ToastWidget extends StatefulWidget {
  final ToastConfig config;
  final VoidCallback onDismiss;

  const _ToastWidget({required this.config, required this.onDismiss});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);

    _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    _animationController.forward();

    // Iniciar animación de progreso
    if (widget.config.showProgress && widget.config.type != ToastType.loading) {
      _animationController.duration = widget.config.duration;
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: _getAccentColor().withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildContent(),
                    if (widget.config.showProgress &&
                        widget.config.type != ToastType.loading)
                      _buildProgressBar(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return GestureDetector(
      onTap: () {
        widget.config.onTap?.call();
        widget.onDismiss();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.config.message,
                    style: TextStyle(
                      color: _getTextColor(),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.config.action != null) ...[
              const SizedBox(width: 12),
              _buildActionButton(),
            ],
            if (widget.config.type != ToastType.loading) ...[
              const SizedBox(width: 8),
              _buildCloseButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (widget.config.type == ToastType.loading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(_getAccentColor()),
        ),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: _getAccentColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_getIcon(), color: Colors.white, size: 14),
    );
  }

  Widget _buildActionButton() {
    return GestureDetector(
      onTap: () {
        widget.config.onAction?.call();
        widget.onDismiss();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getAccentColor().withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          widget.config.action!,
          style: TextStyle(
            color: _getAccentColor(),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _getTextColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.close,
          color: _getTextColor().withValues(alpha: 0.6),
          size: 14,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          height: 2,
          width: double.infinity,
          color: _getAccentColor().withValues(alpha: 0.2),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnimation.value,
            child: Container(color: _getAccentColor()),
          ),
        );
      },
    );
  }

  Color _getBackgroundColor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF161B22) : Colors.white;
  }

  Color _getTextColor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : const Color(0xFF2D3436);
  }

  Color _getAccentColor() {
    switch (widget.config.type) {
      case ToastType.success:
        return AppColors.success;
      case ToastType.error:
        return AppColors.error;
      case ToastType.warning:
        return AppColors.warning;
      case ToastType.info:
        return AppColors.info;
      case ToastType.loading:
        return AppColors.primary;
    }
  }

  IconData _getIcon() {
    switch (widget.config.type) {
      case ToastType.success:
        return Icons.check;
      case ToastType.error:
        return Icons.close;
      case ToastType.warning:
        return Icons.warning;
      case ToastType.info:
        return Icons.info;
      case ToastType.loading:
        return Icons.hourglass_empty;
    }
  }
}

/// Widget para inicializar el servicio de toast en la app
class ToastProvider extends StatefulWidget {
  final Widget child;

  const ToastProvider({super.key, required this.child});

  @override
  State<ToastProvider> createState() => _ToastProviderState();
}

class _ToastProviderState extends State<ToastProvider> {
  @override
  void initState() {
    super.initState();
    // Configurar el contexto para el servicio de toast
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeToastService();
    });
  }

  void _initializeToastService() {
    // Registrar el contexto en el servicio
    ToastService.registerContext(context);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
