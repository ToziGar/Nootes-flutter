// Helper to attach per-field companion timestamps to outgoing update payloads.
//
// Rules:
// - Skip keys that already look like timestamp companions (ending with
//   '_lastClientUpdateAt' or '_updatedAt').
// - Do NOT add companions for values that are List or Map (treated as
//   complex structures). Everything else is considered scalar-like and will
//   receive a '<field>_lastClientUpdateAt' companion timestamp if one is not
//   already present in the payload.
// - Preserve existing companion timestamps; do not overwrite them.

Map<String, dynamic> attachFieldTimestamps(Map<String, dynamic> data, {DateTime? now}) {
  final nowIso = (now ?? DateTime.now()).toUtc().toIso8601String();

  // Start with a shallow copy so we don't mutate the input map.
  final result = Map<String, dynamic>.from(data);

  for (final entry in data.entries) {
    final key = entry.key;

    // Skip companion-looking keys.
    if (key.endsWith('_lastClientUpdateAt') || key.endsWith('_updatedAt')) {
      continue;
    }

    final companionKey = '${key}_lastClientUpdateAt';
    if (result.containsKey(companionKey)) continue;

    final value = entry.value;

    // Treat Lists and Maps as complex structures — do not add per-field
    // companions for them.
    if (value is List || value is Map) continue;

    // Everything else is scalar-like (including null, bool, num, String, and
    // sentinel objects such as FieldValue). Attach companion timestamp.
    result[companionKey] = nowIso;
  }

  return result;
}
