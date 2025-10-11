import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.bg),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -60,
            child: _GlowCircle(
              color: AppColors.accent.withValues(alpha: 0.22),
              size: 280,
            ),
          ),
          Positioned(
            bottom: -160,
            right: -80,
            child: _GlowCircle(
              color: AppColors.note.withValues(alpha: 0.16),
              size: 340,
            ),
          ),
          Positioned(
            top: 180,
            right: -100,
            child: _GlowCircle(
              color: Colors.white.withValues(alpha: 0.05),
              size: 220,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 16,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.borderColor, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}
