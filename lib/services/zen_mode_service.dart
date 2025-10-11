import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/color_utils.dart';
import 'package:flutter/services.dart';

/// Servicio para el modo Zen (escritura sin distracciones)
class ZenModeService {
  static final ZenModeService _instance = ZenModeService._internal();
  factory ZenModeService() => _instance;
  ZenModeService._internal();

  bool _isZenModeActive = false;
  ZenModeConfig _config = ZenModeConfig();
  OverlayEntry? _overlayEntry;
  BuildContext? _context;

  /// Indica si el modo Zen está activo
  bool get isZenModeActive => _isZenModeActive;

  /// Configuración actual del modo Zen
  ZenModeConfig get config => _config;

  /// Inicializa el servicio
  void initialize(BuildContext context) {
    _context = context;
  }

  /// Actualiza la configuración
  void updateConfig(ZenModeConfig config) {
    _config = config;
  }

  /// Activa el modo Zen
  void enterZenMode(Widget editorWidget) {
    if (_isZenModeActive || _context == null) return;

    _isZenModeActive = true;

    // Cambiar a pantalla completa si está configurado
    if (_config.fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    }

    // Crear overlay para el modo Zen
    _overlayEntry = OverlayEntry(
      builder: (context) => ZenModeOverlay(
        config: _config,
        editorWidget: editorWidget,
        onExit: exitZenMode,
      ),
    );

    Overlay.of(_context!).insert(_overlayEntry!);
  }

  /// Desactiva el modo Zen
  void exitZenMode() {
    if (!_isZenModeActive) return;

    _isZenModeActive = false;

    // Restaurar UI del sistema
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Remover overlay
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Alterna el modo Zen
  void toggleZenMode(Widget editorWidget) {
    if (_isZenModeActive) {
      exitZenMode();
    } else {
      enterZenMode(editorWidget);
    }
  }
}

/// Configuración del modo Zen
class ZenModeConfig {
  final bool fullscreen;
  final bool hideStatusBar;
  final bool hideToolbars;
  final bool centerContent;
  final double maxWidth;
  final Color? backgroundColor;
  final double opacity;
  final bool enableFocusMode;
  final Duration focusLineDuration;
  final bool showProgress;
  final bool enableBreakReminders;
  final Duration breakInterval;
  final bool enableAmbientSounds;
  final AmbientSound ambientSound;

  ZenModeConfig({
    this.fullscreen = true,
    this.hideStatusBar = true,
    this.hideToolbars = true,
    this.centerContent = true,
    this.maxWidth = 800,
    this.backgroundColor,
    this.opacity = 0.95,
    this.enableFocusMode = false,
    this.focusLineDuration = const Duration(seconds: 30),
    this.showProgress = false,
    this.enableBreakReminders = false,
    this.breakInterval = const Duration(minutes: 25),
    this.enableAmbientSounds = false,
    this.ambientSound = AmbientSound.none,
  });

  ZenModeConfig copyWith({
    bool? fullscreen,
    bool? hideStatusBar,
    bool? hideToolbars,
    bool? centerContent,
    double? maxWidth,
    Color? backgroundColor,
    double? opacity,
    bool? enableFocusMode,
    Duration? focusLineDuration,
    bool? showProgress,
    bool? enableBreakReminders,
    Duration? breakInterval,
    bool? enableAmbientSounds,
    AmbientSound? ambientSound,
  }) {
    return ZenModeConfig(
      fullscreen: fullscreen ?? this.fullscreen,
      hideStatusBar: hideStatusBar ?? this.hideStatusBar,
      hideToolbars: hideToolbars ?? this.hideToolbars,
      centerContent: centerContent ?? this.centerContent,
      maxWidth: maxWidth ?? this.maxWidth,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      opacity: opacity ?? this.opacity,
      enableFocusMode: enableFocusMode ?? this.enableFocusMode,
      focusLineDuration: focusLineDuration ?? this.focusLineDuration,
      showProgress: showProgress ?? this.showProgress,
      enableBreakReminders: enableBreakReminders ?? this.enableBreakReminders,
      breakInterval: breakInterval ?? this.breakInterval,
      enableAmbientSounds: enableAmbientSounds ?? this.enableAmbientSounds,
      ambientSound: ambientSound ?? this.ambientSound,
    );
  }
}

/// Tipos de sonidos ambientales
enum AmbientSound { none, rain, forest, ocean, cafe, fireplace, whitenoise }

/// Overlay del modo Zen
class ZenModeOverlay extends StatefulWidget {
  final ZenModeConfig config;
  final Widget editorWidget;
  final VoidCallback onExit;

  const ZenModeOverlay({
    super.key,
    required this.config,
    required this.editorWidget,
    required this.onExit,
  });

  @override
  State<ZenModeOverlay> createState() => _ZenModeOverlayState();
}

class _ZenModeOverlayState extends State<ZenModeOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _breathingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _breathingAnimation;

  bool _showControls = false;
  final DateTime _startTime = DateTime.now();
  Duration _sessionTime = Duration.zero;
  Timer? _timer;
  Timer? _breakTimer;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _breathingAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    if (widget.config.enableFocusMode) {
      _breathingController.repeat(reverse: true);
    }

    // Iniciar temporizador de sesión
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _sessionTime = DateTime.now().difference(_startTime);
      });
    });

    // Configurar recordatorios de descanso
    if (widget.config.enableBreakReminders) {
      _breakTimer = Timer.periodic(widget.config.breakInterval, (timer) {
        _showBreakReminder();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _breathingController.dispose();
    _timer?.cancel();
    _breakTimer?.cancel();
    super.dispose();
  }

  void _showBreakReminder() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BreakReminderDialog(
        sessionTime: _sessionTime,
        onContinue: () => Navigator.of(context).pop(),
        onTakeBreak: () {
          Navigator.of(context).pop();
          widget.onExit();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor =
        widget.config.backgroundColor ?? theme.scaffoldBackgroundColor;

    return Material(
      type: MaterialType.canvas,
      color: backgroundColor.withOpacityCompat(widget.config.opacity),
      child: Stack(
        children: [
          // Fondo con efecto de respiración
          if (widget.config.enableFocusMode)
            AnimatedBuilder(
              animation: _breathingAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: _breathingAnimation.value,
                      colors: [
                        backgroundColor.withOpacityCompat(0.1),
                        backgroundColor,
                      ],
                    ),
                  ),
                );
              },
            ),

          // Contenido del editor
          FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: widget.config.centerContent
                        ? widget.config.maxWidth
                        : double.infinity,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 64,
                  ),
                  child: widget.editorWidget,
                ),
              ),
            ),
          ),

          // Controles flotantes
          if (_showControls)
            Positioned(
              top: 40,
              right: 40,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ZenModeControls(
                  sessionTime: _sessionTime,
                  config: widget.config,
                  onExit: widget.onExit,
                  onConfigChanged: (config) {
                    setState(() {
                      widget.config;
                    });
                  },
                ),
              ),
            ),

          // Indicador de progreso
          if (widget.config.showProgress)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: ZenModeProgress(
                  sessionTime: _sessionTime,
                  config: widget.config,
                ),
              ),
            ),

          // Botón de salida siempre visible (discreto)
          Positioned(
            top: 20,
            left: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onExit,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacityCompat(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Controles del modo Zen
class ZenModeControls extends StatelessWidget {
  final Duration sessionTime;
  final ZenModeConfig config;
  final VoidCallback onExit;
  final Function(ZenModeConfig) onConfigChanged;

  const ZenModeControls({
    super.key,
    required this.sessionTime,
    required this.config,
    required this.onExit,
    required this.onConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacityCompat(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tiempo de sesión
          Text(
            _formatDuration(sessionTime),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(height: 16),

          // Controles rápidos
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  // Mostrar configuración
                  showDialog(
                    context: context,
                    builder: (context) => ZenModeSettingsDialog(
                      config: config,
                      onConfigChanged: onConfigChanged,
                    ),
                  );
                },
                icon: const Icon(Icons.settings, color: Colors.white),
                tooltip: 'Configuración',
              ),
              IconButton(
                onPressed: () {
                  // Tomar captura
                },
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                tooltip: 'Captura',
              ),
              IconButton(
                onPressed: onExit,
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                tooltip: 'Salir del modo Zen',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }
}

/// Indicador de progreso del modo Zen
class ZenModeProgress extends StatelessWidget {
  final Duration sessionTime;
  final ZenModeConfig config;

  const ZenModeProgress({
    super.key,
    required this.sessionTime,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final progress = config.enableBreakReminders
        ? (sessionTime.inMilliseconds / config.breakInterval.inMilliseconds)
              .clamp(0.0, 1.0)
        : (sessionTime.inMinutes / 60.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacityCompat(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            color: Colors.white.withOpacityCompat(0.7),
            size: 16,
          ),
          const SizedBox(width: 8),
          Container(
            width: 200,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacityCompat(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo de recordatorio de descanso
class BreakReminderDialog extends StatelessWidget {
  final Duration sessionTime;
  final VoidCallback onContinue;
  final VoidCallback onTakeBreak;

  const BreakReminderDialog({
    super.key,
    required this.sessionTime,
    required this.onContinue,
    required this.onTakeBreak,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.spa, color: Colors.green),
          SizedBox(width: 8),
          Text('Hora de un descanso'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Has estado escribiendo durante ${_formatMinutes(sessionTime)}. '
            'Es recomendable tomar un descanso para mantener la productividad.',
          ),
          const SizedBox(height: 16),
          const Text(
            '💡 Sugerencias para tu descanso:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('• Levántate y estírate'),
          const Text('• Mira por la ventana'),
          const Text('• Bebe agua'),
          const Text('• Respira profundamente'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onContinue,
          child: const Text('Continuar escribiendo'),
        ),
        ElevatedButton(
          onPressed: onTakeBreak,
          child: const Text('Tomar descanso'),
        ),
      ],
    );
  }

  String _formatMinutes(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '$minutes minutos';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours hora${hours > 1 ? 's' : ''} y $remainingMinutes minutos';
    }
  }
}

/// Diálogo de configuración del modo Zen
class ZenModeSettingsDialog extends StatefulWidget {
  final ZenModeConfig config;
  final Function(ZenModeConfig) onConfigChanged;

  const ZenModeSettingsDialog({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  State<ZenModeSettingsDialog> createState() => _ZenModeSettingsDialogState();
}

class _ZenModeSettingsDialogState extends State<ZenModeSettingsDialog> {
  late ZenModeConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configuración del Modo Zen'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Pantalla completa'),
                value: _config.fullscreen,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(fullscreen: value);
                  });
                },
              ),

              SwitchListTile(
                title: const Text('Centrar contenido'),
                value: _config.centerContent,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(centerContent: value);
                  });
                },
              ),

              SwitchListTile(
                title: const Text('Modo de enfoque'),
                subtitle: const Text('Efecto de respiración sutil'),
                value: _config.enableFocusMode,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(enableFocusMode: value);
                  });
                },
              ),

              SwitchListTile(
                title: const Text('Mostrar progreso'),
                value: _config.showProgress,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(showProgress: value);
                  });
                },
              ),

              SwitchListTile(
                title: const Text('Recordatorios de descanso'),
                value: _config.enableBreakReminders,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(enableBreakReminders: value);
                  });
                },
              ),

              if (_config.enableBreakReminders) ...[
                ListTile(
                  title: const Text('Intervalo de descanso'),
                  subtitle: Slider(
                    value: _config.breakInterval.inMinutes.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    label: '${_config.breakInterval.inMinutes} min',
                    onChanged: (value) {
                      setState(() {
                        _config = _config.copyWith(
                          breakInterval: Duration(minutes: value.round()),
                        );
                      });
                    },
                  ),
                ),
              ],

              ListTile(
                title: const Text('Ancho máximo'),
                subtitle: Slider(
                  value: _config.maxWidth,
                  min: 400,
                  max: 1200,
                  divisions: 8,
                  label: '${_config.maxWidth.round()}px',
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(maxWidth: value);
                    });
                  },
                ),
              ),

              ListTile(
                title: const Text('Opacidad'),
                subtitle: Slider(
                  value: _config.opacity,
                  min: 0.7,
                  max: 1.0,
                  divisions: 6,
                  label: '${(_config.opacity * 100).round()}%',
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(opacity: value);
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfigChanged(_config);
            Navigator.of(context).pop();
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
