import 'package:flutter/material.dart';

/// Small helper extension to provide a stable replacement for the deprecated
/// `Color.withOpacity` behaviour. Use `withValues(a: ...)` to set opacity
/// (a = 0.0 .. 1.0) or `withValues(r:..., g:..., b:...)` to adjust channels.
extension ColorUtils on Color {
  /// Change individual channels; values are 0.0..1.0
  Color withValues({double? a, double? r, double? g, double? b}) {
    // New Color API provides normalized channels (.a,.r,.g,.b) as doubles.
    final intA =
        (a != null
            ? (a.clamp(0.0, 1.0) * 255).round()
            : (this.a * 255).round()) &
        0xff;
    final intR =
        (r != null
            ? (r.clamp(0.0, 1.0) * 255).round()
            : (this.r * 255).round()) &
        0xff;
    final intG =
        (g != null
            ? (g.clamp(0.0, 1.0) * 255).round()
            : (this.g * 255).round()) &
        0xff;
    final intB =
        (b != null
            ? (b.clamp(0.0, 1.0) * 255).round()
            : (this.b * 255).round()) &
        0xff;
    return Color.fromARGB(intA, intR, intG, intB);
  }

  /// Convenience to replace common withOpacity(double) usage.
  Color withOpacityCompat(double opacity) => withValues(a: opacity);
}
