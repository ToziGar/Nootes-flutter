import 'package:flutter/material.dart';

/// Servicio de autocompletado inteligente
class AutoCompleteService {
  static final AutoCompleteService _instance = AutoCompleteService._internal();
  factory AutoCompleteService() => _instance;
  AutoCompleteService._internal();

  /// Inicializa el servicio
  void initialize() {
    // Inicialización
  }

  /// Lista de sugerencias actuales
  Future<List<AutoCompleteSuggestion>> getSuggestions(String text, int cursorPosition) async {
    return [
      AutoCompleteSuggestion(
        text: 'ejemplo',
        description: 'Texto de ejemplo',
        type: SuggestionType.text,
        icon: Icons.text_fields,
        color: Colors.blue,
        frequency: 1,
      ),
    ];
  }

  /// Lista de snippets de código
  List<CodeSnippet> getCodeSnippets(String prefix) {
    return [
      CodeSnippet(
        name: 'título',
        content: '# ${'{cursor}'}',
        description: 'Encabezado de nivel 1',
        trigger: 'h1',
        template: '# ${'{cursor}'}',
      ),
    ];
  }

  /// Añade una palabra del usuario
  void addUserWord(dynamic suggestion) {
    // Accept either an AutoCompleteSuggestion or a plain String
    String? word;
    if (suggestion == null) return;
    if (suggestion is AutoCompleteSuggestion) {
      word = suggestion.text;
    } else if (suggestion is String) {
      word = suggestion;
    }

    if (word == null) return;

    // Currently this simple implementation delegates to the other AutoCompleteService
    // if present (there is a richer autocomplete service in another file). For now
    // just print or store locally if needed.
    // TODO: Integrate with user-word persistence.
  }
}

/// Sugerencia de autocompletado
class AutoCompleteSuggestion {
  final String text;
  final String description;
  final SuggestionType type;
  final IconData icon;
  final Color color;
  final int frequency;

  AutoCompleteSuggestion({
    required this.text,
    required this.description,
    required this.type,
    required this.icon,
    required this.color,
    this.frequency = 1,
  });
}

/// Snippet de código
class CodeSnippet {
  final String name;
  final String content;
  final String description;
  final String trigger;
  final String template;

  CodeSnippet({
    required this.name,
    required this.content,
    required this.description,
    required this.trigger,
    required this.template,
  });
}

/// Tipos de sugerencias
enum SuggestionType {
  text,
  snippet,
  keyword,
}