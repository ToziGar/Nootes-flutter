import 'package:flutter/foundation.dart';

/// Small helper to centralize debug-only printing.
/// Use this instead of calling `debugPrint`/`print` directly so release
/// builds won't accidentally emit developer logs.
void logDebug(String message) {
  if (kDebugMode) {
    try {
      // Use debugPrint which is safer for long messages.
      // ignore: avoid_print
      debugPrint(message);
    } catch (_) {}
  }
}
