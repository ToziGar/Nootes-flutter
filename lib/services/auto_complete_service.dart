import 'package:flutter/material.dart';
import 'preferences_service.dart';

/// Servicio de autocompletado inteligente
class AutoCompleteService {
  static final AutoCompleteService _instance = AutoCompleteService._internal();
  factory AutoCompleteService() => _instance;
  AutoCompleteService._internal();

  // Cache en memoria de palabras del usuario para respuestas rápidas
  List<_UserWord> _userWords = const [];

  /// Inicializa el servicio
  void initialize() {
    // Cargar palabras del usuario desde preferencias a memoria
    _loadUserWords();
  }

  Future<void> _loadUserWords() async {
    final raw = await PreferencesService.getUserWords();
    _userWords = raw
        .map((e) => _UserWord(
              text: (e['text'] ?? '').toString(),
              freq: e['freq'] is int ? e['freq'] as int : int.tryParse('${e['freq']}') ?? 1,
              lastUsed: DateTime.tryParse('${e['lastUsed']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
            ))
        .where((w) => w.text.isNotEmpty)
        .toList(growable: false);
    _userWords.sort();
  }

  /// Lista de sugerencias actuales
  Future<List<AutoCompleteSuggestion>> getSuggestions(String text, int cursorPosition) async {
    final query = text.substring(0, cursorPosition).split(RegExp(r"\s+")).lastOrNull ?? '';
    final q = query.toLowerCase();

    // Sugerencias personalizadas por palabras del usuario
    final personal = _userWords
        .where((w) => q.isEmpty ? true : w.text.toLowerCase().startsWith(q))
        .take(8)
        .map((w) => AutoCompleteSuggestion(
              text: w.text,
              description: 'Frecuencia ${w.freq}',
              type: SuggestionType.keyword,
              icon: Icons.person,
              color: Colors.teal,
              frequency: w.freq,
            ))
        .toList();

    // Sugerencias base (ejemplo)
    final base = [
      AutoCompleteSuggestion(
        text: 'ejemplo',
        description: 'Texto de ejemplo',
        type: SuggestionType.text,
        icon: Icons.text_fields,
        color: Colors.blue,
        frequency: 1,
      ),
    ];

    return [...personal, ...base];
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

    // Persistir y actualizar cache
    PreferencesService.addOrBumpUserWord(word);
    // También reflejar en memoria para disponibilidad inmediata
    final idx = _userWords.indexWhere((w) => w.text.toLowerCase() == word!.toLowerCase());
    if (idx >= 0) {
      final updated = _userWords[idx].copyWith(freq: _userWords[idx].freq + 1, lastUsed: DateTime.now());
      final list = [..._userWords];
      list[idx] = updated;
      list.sort();
      _userWords = list;
    } else {
  final list = [..._userWords, _UserWord(text: word, freq: 1, lastUsed: DateTime.now())];
      list.sort();
      _userWords = list;
    }
  }
}

// Modelo interno para ordenar y manejar palabras de usuario
class _UserWord implements Comparable<_UserWord> {
  final String text;
  final int freq;
  final DateTime lastUsed;
  const _UserWord({required this.text, required this.freq, required this.lastUsed});

  _UserWord copyWith({String? text, int? freq, DateTime? lastUsed}) =>
      _UserWord(text: text ?? this.text, freq: freq ?? this.freq, lastUsed: lastUsed ?? this.lastUsed);

  @override
  int compareTo(_UserWord other) {
    // Ordenar por frecuencia desc y luego por recencia desc
    if (freq != other.freq) return other.freq.compareTo(freq);
    return other.lastUsed.compareTo(lastUsed);
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