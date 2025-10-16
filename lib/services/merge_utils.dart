/// Utilities for merging document maps in an offline-friendly way.
///
/// The merge strategy is intentionally simple and conservative:
/// - For list fields (`List<String>`) we merge as a set-union to avoid
///   accidentally dropping tags/ids when syncing from multiple clients.
/// - For other fields, the incoming value overwrites the existing one.
Map<String, dynamic> mergeNoteMaps(
    Map<String, dynamic> current, Map<String, dynamic> incoming) {
  final merged = Map<String, dynamic>.from(current);

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
        final set = <String>{}..addAll(currentList)..addAll(incomingList);
        merged[key] = set.toList();
        continue;
      }
      // Not string lists: fall through to overwrite with incoming list.
    }

    // For other types, prefer the incoming value (client intends to update).
    merged[key] = incomingValue;
  }

  return merged;
}
