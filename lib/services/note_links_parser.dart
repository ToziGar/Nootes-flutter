/// Helper para detectar y parsear enlaces de notas con sintaxis [[nombre_nota]]
class NoteLinksParser {
  /// Expresión regular para detectar [[nota]]
  static final RegExp linkPattern = RegExp(r'\[\[([^\]]+)\]\]');

  /// Extrae todos los nombres de notas enlazadas desde un texto
  static List<String> extractLinkedNoteNames(String text) {
    final matches = linkPattern.allMatches(text);
    return matches.map((m) => m.group(1)!.trim()).toList();
  }

  /// Extrae enlaces únicos (sin duplicados)
  static Set<String> extractUniqueLinkedNoteNames(String text) {
    return extractLinkedNoteNames(text).toSet();
  }

  /// Verifica si hay un [[ sin cerrar al final del texto (para autocompletado)
  static bool hasIncompleteLink(String text) {
    // Buscar [[ seguido por texto pero sin ]]
    final lastOpenBracket = text.lastIndexOf('[[');
    if (lastOpenBracket == -1) return false;

    final afterBracket = text.substring(lastOpenBracket + 2);
    return !afterBracket.contains(']]');
  }

  /// Obtiene el texto parcial después del último [[ para buscar sugerencias
  static String? getIncompleteLinkQuery(String text) {
    if (!hasIncompleteLink(text)) return null;

    final lastOpenBracket = text.lastIndexOf('[[');
    final afterBracket = text.substring(lastOpenBracket + 2);

    // Extraer solo hasta el primer salto de línea o espacio doble
    final query = afterBracket.split(RegExp(r'[\n\r]')).first;
    return query.trim();
  }

  /// Reemplaza [[nota]] con un widget personalizado o texto
  /// Útil para renderizar en markdown
  static String replaceLinksWithMarkdown(
    String text,
    Map<String, String> noteIdsByTitle,
  ) {
    return text.replaceAllMapped(linkPattern, (match) {
      final noteName = match.group(1)!.trim();
      final noteId = noteIdsByTitle[noteName];

      if (noteId != null) {
        // Si la nota existe, crear enlace con ID
        return '[$noteName](note://$noteId)';
      } else {
        // Si no existe, dejar como texto con indicador
        return '🔗 $noteName';
      }
    });
  }

  /// Verifica si el cursor está dentro de un [[link]]
  static bool isCursorInLink(String text, int cursorPosition) {
    final beforeCursor = text.substring(0, cursorPosition);
    final lastOpen = beforeCursor.lastIndexOf('[[');

    if (lastOpen == -1) return false;

    final afterOpen = text.substring(lastOpen);
    final closePos = afterOpen.indexOf(']]');

    return closePos == -1 || closePos > (cursorPosition - lastOpen);
  }

  /// Obtiene la posición inicial del link actual si el cursor está dentro de uno
  static int? getCurrentLinkStart(String text, int cursorPosition) {
    if (!isCursorInLink(text, cursorPosition)) return null;
    return text.substring(0, cursorPosition).lastIndexOf('[[');
  }

  /// Estructura para representar un link encontrado
  static List<LinkMatch> findAllLinks(String text) {
    final matches = linkPattern.allMatches(text);
    return matches
        .map(
          (m) => LinkMatch(
            title: m.group(1)!.trim(),
            start: m.start,
            end: m.end,
            fullMatch: m.group(0)!,
          ),
        )
        .toList();
  }
}

/// Representa un link encontrado en el texto
class LinkMatch {
  final String title;
  final int start;
  final int end;
  final String fullMatch;

  LinkMatch({
    required this.title,
    required this.start,
    required this.end,
    required this.fullMatch,
  });
}
