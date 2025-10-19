import 'package:flutter/widgets.dart';

class ImagePrefetchService {
  static final ImagePrefetchService _instance =
      ImagePrefetchService._internal();
  factory ImagePrefetchService() => _instance;
  ImagePrefetchService._internal();

  /// Prefetch a network image into the image cache
  Future<void> prefetch(BuildContext context, String url) async {
    try {
      final provider = NetworkImage(url);
      await precacheImage(provider, context);
    } catch (_) {
      // Ignore prefetch errors; UI will show placeholders
    }
  }
}
