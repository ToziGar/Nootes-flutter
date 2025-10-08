import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

/// Servicio de autocompletado inteligente para el editor
class AutoCompleteService {
  static final AutoCompleteService _instance = AutoCompleteService._internal();
  factory AutoCompleteService() => _instance;
  AutoCompleteService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;

  // Cache de sugerencias
  Map<String, List<String>> _suggestionsCache = {};
  List<String> _commonWords = [];
  List<String> _userWords = [];
  Map<String, int> _wordFrequency = {};

  /// Inicializa el servicio cargando datos del usuario
  Future<void> initialize() async {
    await _loadCommonWords();
    await _loadUserWords();
  }

  /// Carga palabras comunes en español e inglés
  Future<void> _loadCommonWords() async {
    _commonWords = [
      // Palabras comunes en español
      'el', 'la', 'de', 'que', 'y', 'a', 'en', 'un', 'es', 'se', 'no', 'te', 'lo', 'le', 'da', 'su', 'por', 'son', 'con', 'para',
      'también', 'todo', 'muy', 'cuando', 'donde', 'como', 'porque', 'entonces', 'después', 'antes', 'ahora', 'siempre', 'nunca',
      'proyecto', 'trabajo', 'reunión', 'tarea', 'objetivo', 'importante', 'necesario', 'desarrollar', 'implementar', 'crear',
      'análisis', 'resultado', 'proceso', 'sistema', 'aplicación', 'usuario', 'interfaz', 'función', 'método', 'clase',
      
      // Palabras comunes en inglés
      'the', 'of', 'and', 'to', 'in', 'is', 'you', 'that', 'it', 'he', 'was', 'for', 'on', 'are', 'as', 'with', 'his', 'they',
      'also', 'all', 'very', 'when', 'where', 'how', 'because', 'then', 'after', 'before', 'now', 'always', 'never',
      'project', 'work', 'meeting', 'task', 'goal', 'important', 'necessary', 'develop', 'implement', 'create',
      'analysis', 'result', 'process', 'system', 'application', 'user', 'interface', 'function', 'method', 'class',
      
      // Palabras técnicas comunes
      'flutter', 'dart', 'widget', 'stateful', 'stateless', 'build', 'context', 'scaffold', 'container', 'column', 'row',
      'firebase', 'firestore', 'authentication', 'database', 'collection', 'document', 'query', 'snapshot', 'stream',
      'javascript', 'typescript', 'react', 'vue', 'angular', 'nodejs', 'express', 'mongodb', 'mysql', 'postgresql',
      'python', 'django', 'flask', 'fastapi', 'pandas', 'numpy', 'tensorflow', 'pytorch', 'scikit', 'jupyter',
      'github', 'gitlab', 'docker', 'kubernetes', 'aws', 'azure', 'gcp', 'terraform', 'ansible', 'jenkins',
    ];
  }

  /// Carga palabras del usuario desde Firestore
  Future<void> _loadUserWords() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    try {
      final notesSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notes')
          .get();

      final Set<String> userWordsSet = {};
      final Map<String, int> frequency = {};

      for (final doc in notesSnapshot.docs) {
        final content = doc.data()['content'] as String? ?? '';
        final words = _extractWords(content);
        
        for (final word in words) {
          if (word.length >= 3) {
            userWordsSet.add(word);
            frequency[word] = (frequency[word] ?? 0) + 1;
          }
        }
      }

      _userWords = userWordsSet.toList();
      _wordFrequency = frequency;
    } catch (e) {
      print('Error loading user words: $e');
    }
  }

  /// Extrae palabras de un texto
  List<String> _extractWords(String text) {
    // Limpiar texto y extraer palabras
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  /// Obtiene sugerencias de autocompletado
  Future<List<AutoCompleteSuggestion>> getSuggestions(String input, {int maxSuggestions = 10}) async {
    if (input.length < 2) return [];

    final lowercaseInput = input.toLowerCase();
    final suggestions = <AutoCompleteSuggestion>[];

    // Cache key
    final cacheKey = lowercaseInput;
    if (_suggestionsCache.containsKey(cacheKey)) {
      return _suggestionsCache[cacheKey]!
          .map((word) => AutoCompleteSuggestion(
                text: word,
                type: SuggestionType.cached,
                frequency: _wordFrequency[word] ?? 0,
              ))
          .toList();
    }

    // Buscar en palabras del usuario (mayor prioridad)
    for (final word in _userWords) {
      if (word.startsWith(lowercaseInput) && word != lowercaseInput) {
        suggestions.add(AutoCompleteSuggestion(
          text: word,
          type: SuggestionType.userWord,
          frequency: _wordFrequency[word] ?? 0,
        ));
      }
    }

    // Buscar en palabras comunes
    for (final word in _commonWords) {
      if (word.startsWith(lowercaseInput) && word != lowercaseInput) {
        suggestions.add(AutoCompleteSuggestion(
          text: word,
          type: SuggestionType.commonWord,
          frequency: 1,
        ));
      }
    }

    // Buscar coincidencias parciales en palabras del usuario
    for (final word in _userWords) {
      if (word.contains(lowercaseInput) && !word.startsWith(lowercaseInput)) {
        suggestions.add(AutoCompleteSuggestion(
          text: word,
          type: SuggestionType.partialMatch,
          frequency: _wordFrequency[word] ?? 0,
        ));
      }
    }

    // Ordenar por prioridad y frecuencia
    suggestions.sort((a, b) {
      // Primero por tipo (userWord > commonWord > partialMatch)
      if (a.type != b.type) {
        return a.type.priority.compareTo(b.type.priority);
      }
      // Luego por frecuencia
      return b.frequency.compareTo(a.frequency);
    });

    // Limitar resultados y cachear
    final limitedSuggestions = suggestions.take(maxSuggestions).toList();
    _suggestionsCache[cacheKey] = limitedSuggestions.map((s) => s.text).toList();

    return limitedSuggestions;
  }

  /// Obtiene sugerencias de snippets de código
  List<CodeSnippet> getCodeSnippets(String input) {
    final snippets = <CodeSnippet>[];
    final lowercaseInput = input.toLowerCase();

    // Snippets de Markdown
    if (lowercaseInput.contains('table') || lowercaseInput.contains('tabla')) {
      snippets.add(CodeSnippet(
        trigger: 'table',
        description: 'Tabla básica',
        template: '''| Columna 1 | Columna 2 | Columna 3 |
|-----------|-----------|-----------|
| Fila 1    | Dato 1    | Dato 2    |
| Fila 2    | Dato 3    | Dato 4    |''',
      ));
    }

    if (lowercaseInput.contains('code') || lowercaseInput.contains('código')) {
      snippets.add(CodeSnippet(
        trigger: 'code',
        description: 'Bloque de código',
        template: '''```\${1:language}
\${2:// Tu código aquí}
```''',
      ));
    }

    if (lowercaseInput.contains('task') || lowercaseInput.contains('tarea')) {
      snippets.add(CodeSnippet(
        trigger: 'task',
        description: 'Lista de tareas',
        template: '''- [ ] \${1:Tarea pendiente}
- [x] \${2:Tarea completada}
- [ ] \${3:Otra tarea}''',
      ));
    }

    if (lowercaseInput.contains('link') || lowercaseInput.contains('enlace')) {
      snippets.add(CodeSnippet(
        trigger: 'link',
        description: 'Enlace',
        template: '[\${1:texto del enlace}](\${2:https://ejemplo.com})',
      ));
    }

    if (lowercaseInput.contains('image') || lowercaseInput.contains('imagen')) {
      snippets.add(CodeSnippet(
        trigger: 'image',
        description: 'Imagen',
        template: '![\${1:alt text}](\${2:ruta/a/imagen.jpg})',
      ));
    }

    // Snippets de programación
    if (lowercaseInput.contains('function') || lowercaseInput.contains('función')) {
      snippets.add(CodeSnippet(
        trigger: 'function',
        description: 'Función',
        template: '''function \${1:nombreFuncion}(\${2:parametros}) {
  \${3:// código}
  return \${4:resultado};
}''',
      ));
    }

    if (lowercaseInput.contains('class') || lowercaseInput.contains('clase')) {
      snippets.add(CodeSnippet(
        trigger: 'class',
        description: 'Clase',
        template: '''class \${1:NombreClase} {
  constructor(\${2:parametros}) {
    \${3:// inicialización}
  }
  
  \${4:metodo}() {
    \${5:// implementación}
  }
}''',
      ));
    }

    return snippets;
  }

  /// Registra una nueva palabra del usuario
  Future<void> addUserWord(String word) async {
    if (word.length < 3) return;
    
    final cleanWord = word.toLowerCase().trim();
    if (!_userWords.contains(cleanWord)) {
      _userWords.add(cleanWord);
      _wordFrequency[cleanWord] = 1;
    } else {
      _wordFrequency[cleanWord] = (_wordFrequency[cleanWord] ?? 0) + 1;
    }

    // Limpiar cache
    _suggestionsCache.clear();
  }

  /// Limpia el cache de sugerencias
  void clearCache() {
    _suggestionsCache.clear();
  }
}

/// Tipo de sugerencia de autocompletado
enum SuggestionType {
  userWord(0),
  commonWord(1),
  partialMatch(2),
  cached(3);

  const SuggestionType(this.priority);
  final int priority;
}

/// Clase para representar una sugerencia de autocompletado
class AutoCompleteSuggestion {
  final String text;
  final SuggestionType type;
  final int frequency;

  const AutoCompleteSuggestion({
    required this.text,
    required this.type,
    required this.frequency,
  });

  IconData get icon {
    switch (type) {
      case SuggestionType.userWord:
        return Icons.person;
      case SuggestionType.commonWord:
        return Icons.language;
      case SuggestionType.partialMatch:
        return Icons.search;
      case SuggestionType.cached:
        return Icons.history;
    }
  }

  Color get color {
    switch (type) {
      case SuggestionType.userWord:
        return Colors.blue;
      case SuggestionType.commonWord:
        return Colors.green;
      case SuggestionType.partialMatch:
        return Colors.orange;
      case SuggestionType.cached:
        return Colors.grey;
    }
  }
}

/// Clase para snippets de código
class CodeSnippet {
  final String trigger;
  final String description;
  final String template;

  const CodeSnippet({
    required this.trigger,
    required this.description,
    required this.template,
  });
}