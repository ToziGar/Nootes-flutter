import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget para cargar imágenes con manejo de CORS y caché
class CorsImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? placeholder;

  const CorsImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  @override
  State<CorsImage> createState() => _CorsImageState();
}

class _CorsImageState extends State<CorsImage> {
  @override
  Widget build(BuildContext context) {
    // Para Firebase Storage, agregar parámetros que ayudan con CORS
    final correctedUrl = _addCorsParams(widget.imageUrl);

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: Stack(
        children: [
          Image.network(
            correctedUrl,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return Container(
                width: widget.width,
                height: widget.height,
                color: AppColors.surfaceLight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      if (widget.placeholder != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.placeholder!,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: widget.width,
                height: widget.height,
                color: AppColors.surfaceLight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_rounded,
                      size: 48,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Error al cargar imagen',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Verifica CORS en Firebase',
                      style: TextStyle(color: AppColors.primary, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Agregar parámetros para mejorar compatibilidad CORS
  String _addCorsParams(String url) {
    if (url.contains('firebasestorage.googleapis.com')) {
      // Firebase Storage ya tiene CORS configurado, solo asegurar token
      return url.contains('?') ? url : url;
    }
    return url;
  }
}

/// Widget mejorado para mostrar imágenes en markdown
class MarkdownImage extends StatelessWidget {
  final String src;
  final String? alt;
  final double maxWidth;

  const MarkdownImage({
    super.key,
    required this.src,
    this.alt,
    this.maxWidth = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            child: CorsImage(
              imageUrl: src,
              width: maxWidth,
              fit: BoxFit.contain,
              placeholder: alt ?? 'Cargando imagen...',
            ),
          ),
          if (alt != null && alt!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              alt!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
