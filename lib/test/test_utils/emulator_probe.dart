import 'dart:io';

/// Returns true when the FIRESTORE emulator host string (host:port) is
/// reachable via a short TCP connection. Accepts null or empty and returns
/// false in that case.
Future<bool> isEmulatorReachable(String? emulator, {Duration timeout = const Duration(milliseconds: 300)}) async {
  if (emulator == null || emulator.isEmpty) return false;
  final parts = emulator.split(':');
  final host = parts[0];
  final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 8080 : 8080;
  try {
    final sock = await Socket.connect(host, port, timeout: timeout);
    sock.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
