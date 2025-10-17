/// Utilities for merging document maps in an offline-friendly way.
///
/// The merge strategy is intentionally simple and conservative:
/// - For list fields (`List<String>`) we merge as a set-union to avoid
///   accidentally dropping tags/ids when syncing from multiple clients.
/// - For other fields, the incoming value overwrites the existing one.
Map<String, dynamic> mergeNoteMaps(
    Map<String, dynamic> current, Map<String, dynamic> incoming) {
  final merged = Map<String, dynamic>.from(current);

  // Helper to parse a timestamp-like value into DateTime.
  DateTime? parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // Precompute map-level timestamps if present so we can apply a last-writer-wins
  // (LWW) policy for non-list scalar fields. Prefer `lastClientUpdateAt`,
  // then `updatedAt`.
  final incomingTs = parseTs(incoming['lastClientUpdateAt'] ?? incoming['updatedAt']);
  final currentTs = parseTs(current['lastClientUpdateAt'] ?? current['updatedAt']);

  for (final entry in incoming.entries) {
    final key = entry.key;
    final incomingValue = entry.value;
    final currentValue = current[key];

    // Merge string lists (common for tags or id lists)
    if (currentValue is List && incomingValue is List) {
      // Only perform a union merge for lists of strings. For other list
      // element types, prefer the incoming list (overwrite) to avoid
      // dropping typed elements.
      final currentStringCount = currentValue.whereType<String>().length;
      final incomingStringCount = incomingValue.whereType<String>().length;
      if (currentStringCount == currentValue.length &&
          incomingStringCount == incomingValue.length) {
        final currentList = currentValue.whereType<String>().toList();
        final incomingList = incomingValue.whereType<String>().toList();
        // Preserve current ordering, then append any new items from incoming
        // in their incoming order. This keeps merges deterministic and
        // avoids surprising reordering for the user.
        final seen = <String>{...currentList};
        final mergedList = [...currentList];
        for (final s in incomingList) {
          if (!seen.contains(s)) {
            seen.add(s);
            mergedList.add(s);
          }
        }
        merged[key] = mergedList;
        continue;
      }
      // Not string lists: fall through to overwrite with incoming list.
    }

    // For other types, attempt per-field LWW if companion timestamp fields exist.
    // Check for per-field companion timestamps: e.g., '<field>_lastClientUpdateAt' or '<field>_updatedAt'.
  final incomingFieldTs = parseTs(incoming['${key}_lastClientUpdateAt'] ?? incoming['${key}_updatedAt']);
  final currentFieldTs = parseTs(current['${key}_lastClientUpdateAt'] ?? current['${key}_updatedAt']);

    if (incomingFieldTs != null && currentFieldTs != null) {
      if (incomingFieldTs.isAfter(currentFieldTs)) {
        merged[key] = incomingValue;
      } else {
        // keep current
      }
    } else if (incomingFieldTs != null && currentFieldTs == null) {
      // If only incoming provides a per-field timestamp, prefer incoming.
      merged[key] = incomingValue;
    } else if (incomingFieldTs == null && currentFieldTs != null) {
      // Only current has a per-field timestamp -> keep current.
    } else if (incomingTs != null && currentTs != null) {
      // Fallback to map-level LWW as before.
      if (incomingTs.isAfter(currentTs)) {
        merged[key] = incomingValue;
      }
    } else {
      // No timestamps to help us; prefer incoming value by default.
      merged[key] = incomingValue;
    }
  }

  return merged;
}
