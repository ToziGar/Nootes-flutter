import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// Menú FAB expandible con múltiples acciones
class UnifiedFABMenu extends StatefulWidget {
  final VoidCallback onNewNote;
  final VoidCallback onNewFolder;
  final VoidCallback onNewFromTemplate;
  final VoidCallback onInsertImage;
  final VoidCallback onToggleRecording;
  final VoidCallback onOpenDashboard;
  final bool isRecording;

  const UnifiedFABMenu({
    super.key,
    required this.onNewNote,
    required this.onNewFolder,
    required this.onNewFromTemplate,
    required this.onInsertImage,
    required this.onToggleRecording,
    required this.onOpenDashboard,
    this.isRecording = false,
  });

  @override
  State<UnifiedFABMenu> createState() => _UnifiedFABMenuState();
}

class _UnifiedFABMenuState extends State<UnifiedFABMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Botones expandibles
        ..._buildActionButtons(),
        
        // Botón principal
        ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 0.95).animate(_expandAnimation),
          child: FloatingActionButton(
            onPressed: _toggle,
            backgroundColor: AppColors.primary,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 250),
              turns: _isExpanded ? 0.125 : 0, // 45 grados cuando está expandido
              child: Icon(
                _isExpanded ? Icons.close_rounded : Icons.add_rounded,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActionButtons() {
    if (!_isExpanded) return [];

    final buttons = [
      _FabMenuItem(
        icon: Icons.analytics_rounded,
        label: 'Dashboard',
        color: const Color(0xFF8B5CF6),
        onPressed: () {
          _toggle();
          widget.onOpenDashboard();
        },
        animation: _expandAnimation,
        index: 0,
      ),
      _FabMenuItem(
        icon: Icons.description_rounded,
        label: 'Plantilla',
        color: const Color(0xFFF59E0B),
        onPressed: () {
          _toggle();
          widget.onNewFromTemplate();
        },
        animation: _expandAnimation,
        index: 1,
      ),
      _FabMenuItem(
        icon: Icons.image_outlined,
        label: 'Imagen',
        color: const Color(0xFF06B6D4),
        onPressed: () {
          _toggle();
          widget.onInsertImage();
        },
        animation: _expandAnimation,
        index: 2,
      ),
      _FabMenuItem(
        icon: widget.isRecording ? Icons.stop_rounded : Icons.mic_outlined,
        label: widget.isRecording ? 'Detener' : 'Audio',
        color: widget.isRecording ? AppColors.danger : const Color(0xFF10B981),
        onPressed: () {
          widget.onToggleRecording();
          if (!widget.isRecording) _toggle();
        },
        animation: _expandAnimation,
        index: 3,
      ),
      _FabMenuItem(
        icon: Icons.folder_outlined,
        label: 'Carpeta',
        color: const Color(0xFFEC4899),
        onPressed: () {
          _toggle();
          widget.onNewFolder();
        },
        animation: _expandAnimation,
        index: 4,
      ),
      _FabMenuItem(
        icon: Icons.note_add_rounded,
        label: 'Nota',
        color: AppColors.primary,
        onPressed: () {
          _toggle();
          widget.onNewNote();
        },
        animation: _expandAnimation,
        index: 5,
      ),
    ];

    return buttons
        .map((btn) => Padding(
              padding: const EdgeInsets.only(bottom: AppColors.space12),
              child: btn,
            ))
        .toList();
  }
}

/// Item individual del menú FAB
class _FabMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final Animation<double> animation;
  final int index;

  const _FabMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    required this.animation,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // Animación escalonada: cada botón aparece con un pequeño delay
    final delayedAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(
          math.min(index * 0.1, 0.4),
          math.min(0.6 + index * 0.1, 1.0),
          curve: Curves.easeOut,
        ),
      ),
    );

    return ScaleTransition(
      scale: delayedAnimation,
      child: FadeTransition(
        opacity: delayedAnimation,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppColors.space12,
                  vertical: AppColors.space8,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppColors.space12),
            
            // Botón
            FloatingActionButton.small(
              heroTag: 'fab_$label',
              onPressed: onPressed,
              backgroundColor: color,
              elevation: 4,
              child: Icon(icon, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
