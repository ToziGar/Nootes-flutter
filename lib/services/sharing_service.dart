// Backwards-compatible export shim.
// Consumers importing 'package:nootes/services/sharing_service.dart'
// will receive the improved implementation from
// 'sharing_service_improved.dart'.

export 'package:nootes/services/sharing_service_improved.dart';
// Also export compatibility helpers so legacy method names are available.
export 'package:nootes/services/sharing_service_compat.dart';
