import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A small widget that displays a network image with a retry button and
/// a friendly placeholder when loading fails (useful for web/CORS issues).
class SafeNetworkImage extends StatefulWidget {
  const SafeNetworkImage(this.url, {super.key, this.fit = BoxFit.contain, this.height, this.width});

  final String url;
  final BoxFit fit;
  final double? height;
  final double? width;

  @override
  State<SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  // A simple token to force Image.network to try again when changed
  int _reloadToken = 0;

  void _retry() {
    setState(() => _reloadToken++);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Image.network(
        widget.url,
        key: ValueKey('safe-${widget.url}-$_reloadToken'),
        fit: widget.fit,
        // show a spinner while loading
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stack) {
          return Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_rounded, size: 28),
                const SizedBox(height: 8),
                const Text('Imagen no disponible', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await Clipboard.setData(ClipboardData(text: widget.url));
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copiada al portapapeles')));
                        } catch (_) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo copiar la URL')));
                        }
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar URL'),
                    ),
                  ],
                ),
                if (kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Puede existir un bloqueo CORS en web', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
