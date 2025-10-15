import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/exceptions/sharing_exceptions.dart';

/// Servicio mejorado de búsqueda con capacidades avanzadas
class SearchServiceEnhanced {
  static final SearchServiceEnhanced _instance = SearchServiceEnhanced._internal();
  factory SearchServiceEnhanced() => _instance;
  SearchServiceEnhanced._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;
  final FirestoreService _firestoreService = FirestoreService.instance;

  // Cache de búsquedas recientes
  final Map<String, SearchResult> _searchCache = {};
  final List<String> _recentSearches = [];
  static const int _maxRecentSearches = 20;
  static const Duration _cacheTimeout = Duration(minutes: 10);

  /// Realiza una búsqueda avanzada de notas
  Future<SearchResult> searchNotes({
    required String query,
    SearchFilter? filter,
    int limit = 50,
    bool useCache = true,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      throw AuthenticationException('Usuario no autenticado');
    }

    // Validar query
    if (query.trim().isEmpty) {
      return SearchResult.empty();
    }

    final normalizedQuery = _normalizeQuery(query);
    final cacheKey = _buildCacheKey(uid, normalizedQuery, filter);

    // Verificar cache
    if (useCache && _searchCache.containsKey(cacheKey)) {
      final cached = _searchCache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTimeout) {
        return cached;
      }
    }

    try {
      final results = await _performSearch(uid, normalizedQuery, filter, limit);
      
      // Guardar en cache
      final searchResult = SearchResult(
        query: query,
        results: results,
        totalCount: results.length,
        timestamp: DateTime.now(),
        filter: filter,
      );
      
      _searchCache[cacheKey] = searchResult;
      _addToRecentSearches(query);

      return searchResult;
    } catch (e) {
      debugPrint('Error en búsqueda: $e');
      throw NetworkException();
    }
  }

  /// Búsqueda rápida con sugerencias
  Future<List<SearchSuggestion>> getSearchSuggestions({
    required String partialQuery,
    int limit = 10,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return [];

    if (partialQuery.trim().isEmpty) {
      return _getRecentSearchSuggestions(limit);
    }

    try {
      final suggestions = <SearchSuggestion>[];
      
      // Sugerencias de títulos de notas
      final titleSuggestions = await _getTitleSuggestions(uid, partialQuery, limit ~/ 2);
      suggestions.addAll(titleSuggestions);

      // Sugerencias de tags
      final tagSuggestions = await _getTagSuggestions(uid, partialQuery, limit ~/ 4);
      suggestions.addAll(tagSuggestions);

      // Sugerencias de carpetas
      final folderSuggestions = await _getFolderSuggestions(uid, partialQuery, limit ~/ 4);
      suggestions.addAll(folderSuggestions);

      // Ordenar por relevancia
      suggestions.sort((a, b) => b.score.compareTo(a.score));
      
      return suggestions.take(limit).toList();
    } catch (e) {
      debugPrint('Error obteniendo sugerencias: $e');
      return [];
    }
  }

  /// Búsqueda en tiempo real
  Stream<SearchResult> searchNotesRealtime({
    required String query,
    SearchFilter? filter,
    int limit = 50,
  }) async* {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    if (query.trim().isEmpty) {
      yield SearchResult.empty();
      return;
    }

    // Búsqueda inicial
    final initialResult = await searchNotes(
      query: query,
      filter: filter,
      limit: limit,
      useCache: false,
    );
    yield initialResult;

    // Stream de actualizaciones en tiempo real
    yield* _createRealtimeSearchStream(uid, query, filter, limit);
  }

  /// Obtiene estadísticas de búsqueda del usuario
  Future<SearchStats> getSearchStats() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      return SearchStats(
        totalSearches: 0,
        recentSearches: [],
        topSearchTerms: {},
        searchTrends: {},
      );
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('searchHistory')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final searchHistory = snapshot.docs.map((doc) => doc.data()).toList();
      
      return _calculateSearchStats(searchHistory);
    } catch (e) {
      debugPrint('Error obteniendo estadísticas de búsqueda: $e');
      return SearchStats(
        totalSearches: 0,
        recentSearches: [],
        topSearchTerms: {},
        searchTrends: {},
      );
    }
  }

  /// Guarda una búsqueda en el historial
  Future<void> saveSearchToHistory(String query, int resultCount) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || query.trim().isEmpty) return;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('searchHistory')
          .add({
        'query': query.trim(),
        'resultCount': resultCount,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toString().substring(0, 10),
      });
    } catch (e) {
      debugPrint('Error guardando búsqueda en historial: $e');
    }
  }

  /// Limpia el historial de búsquedas
  Future<void> clearSearchHistory() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('searchHistory')
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      _recentSearches.clear();
      _searchCache.clear();
    } catch (e) {
      debugPrint('Error limpiando historial: $e');
    }
  }

  /// Obtiene búsquedas populares globales (anonimizadas)
  Future<List<String>> getPopularSearches({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('globalSearchStats')
          .orderBy('count', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['term'] as String)
          .where((term) => term.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo búsquedas populares: $e');
      return [];
    }
  }

  // Métodos privados de implementación

  Future<List<SearchResultItem>> _performSearch(
    String uid,
    String query,
    SearchFilter? filter,
    int limit,
  ) async {
    final results = <SearchResultItem>[];
    
    // Búsqueda por título
    final titleResults = await _searchByTitle(uid, query, limit);
    results.addAll(titleResults);

    // Búsqueda por contenido
    final contentResults = await _searchByContent(uid, query, limit);
    results.addAll(contentResults);

    // Búsqueda por tags
    final tagResults = await _searchByTags(uid, query, limit);
    results.addAll(tagResults);

    // Eliminar duplicados y aplicar filtros
    final uniqueResults = _removeDuplicates(results);
    final filteredResults = _applyFilters(uniqueResults, filter);

    // Ordenar por relevancia
    filteredResults.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    return filteredResults.take(limit).toList();
  }

  Future<List<SearchResultItem>> _searchByTitle(String uid, String query, int limit) async {
    final notes = await _firestoreService.listNotes(uid: uid);
    final results = <SearchResultItem>[];

    for (final note in notes) {
      final title = note['title']?.toString() ?? '';
      final score = _calculateRelevanceScore(query, title, SearchMatchType.title);
      
      if (score > 0) {
        results.add(SearchResultItem(
          id: note['id'],
          title: title,
          content: note['content']?.toString() ?? '',
          type: SearchResultType.note,
          relevanceScore: score,
          matchType: SearchMatchType.title,
          highlightedText: _highlightText(title, query),
          createdAt: _parseTimestamp(note['createdAt']),
          updatedAt: _parseTimestamp(note['updatedAt']),
        ));
      }
    }

    return results;
  }

  Future<List<SearchResultItem>> _searchByContent(String uid, String query, int limit) async {
    final notes = await _firestoreService.listNotes(uid: uid);
    final results = <SearchResultItem>[];

    for (final note in notes) {
      final content = note['content']?.toString() ?? '';
      final score = _calculateRelevanceScore(query, content, SearchMatchType.content);
      
      if (score > 0) {
        results.add(SearchResultItem(
          id: note['id'],
          title: note['title']?.toString() ?? '',
          content: content,
          type: SearchResultType.note,
          relevanceScore: score,
          matchType: SearchMatchType.content,
          highlightedText: _extractRelevantSnippet(content, query),
          createdAt: _parseTimestamp(note['createdAt']),
          updatedAt: _parseTimestamp(note['updatedAt']),
        ));
      }
    }

    return results;
  }

  Future<List<SearchResultItem>> _searchByTags(String uid, String query, int limit) async {
    final notes = await _firestoreService.listNotes(uid: uid);
    final results = <SearchResultItem>[];

    for (final note in notes) {
      final tags = List<String>.from(note['tags'] ?? []);
      final tagScore = _calculateTagRelevanceScore(query, tags);
      
      if (tagScore > 0) {
        results.add(SearchResultItem(
          id: note['id'],
          title: note['title']?.toString() ?? '',
          content: note['content']?.toString() ?? '',
          type: SearchResultType.note,
          relevanceScore: tagScore,
          matchType: SearchMatchType.tag,
          highlightedText: tags.join(', '),
          createdAt: _parseTimestamp(note['createdAt']),
          updatedAt: _parseTimestamp(note['updatedAt']),
        ));
      }
    }

    return results;
  }

  double _calculateRelevanceScore(String query, String text, SearchMatchType matchType) {
    if (text.isEmpty) return 0;

    final normalizedQuery = query.toLowerCase();
    final normalizedText = text.toLowerCase();
    
    double score = 0;
    
    // Puntuación base por tipo de coincidencia
    final baseScore = matchType == SearchMatchType.title ? 3.0 : 1.0;
    
    // Coincidencia exacta
    if (normalizedText.contains(normalizedQuery)) {
      score += baseScore * 2;
    }
    
    // Coincidencias de palabras individuales
    final queryWords = normalizedQuery.split(' ');
    final textWords = normalizedText.split(' ');
    
    for (final queryWord in queryWords) {
      if (queryWord.length < 2) continue;
      
      for (final textWord in textWords) {
        if (textWord.startsWith(queryWord)) {
          score += baseScore * 0.8;
        } else if (textWord.contains(queryWord)) {
          score += baseScore * 0.5;
        }
      }
    }
    
    return score;
  }

  double _calculateTagRelevanceScore(String query, List<String> tags) {
    final normalizedQuery = query.toLowerCase();
    double score = 0;
    
    for (final tag in tags) {
      final normalizedTag = tag.toLowerCase();
      if (normalizedTag == normalizedQuery) {
        score += 5.0; // Coincidencia exacta de tag
      } else if (normalizedTag.contains(normalizedQuery)) {
        score += 3.0; // Coincidencia parcial
      }
    }
    
    return score;
  }

  List<SearchResultItem> _removeDuplicates(List<SearchResultItem> results) {
    final seen = <String>{};
    return results.where((item) => seen.add(item.id)).toList();
  }

  List<SearchResultItem> _applyFilters(List<SearchResultItem> results, SearchFilter? filter) {
    if (filter == null) return results;
    
    return results.where((item) {
      // Filtro por tipo
      if (filter.types != null && !filter.types!.contains(item.type)) {
        return false;
      }
      
      // Filtro por fecha
      if (filter.dateRange != null) {
        final itemDate = item.updatedAt ?? item.createdAt;
        if (itemDate != null) {
          if (itemDate.isBefore(filter.dateRange!.start)) {
            return false;
          }
          if (itemDate.isAfter(filter.dateRange!.end)) {
            return false;
          }
        }
      }
      
      return true;
    }).toList();
  }

  String _highlightText(String text, String query) {
    // Implementación básica de resaltado
    final normalizedQuery = query.toLowerCase();
    final normalizedText = text.toLowerCase();
    
    final index = normalizedText.indexOf(normalizedQuery);
    if (index == -1) return text;
    
    return '${text.substring(0, index)}**${text.substring(index, index + query.length)}**${text.substring(index + query.length)}';
  }

  String _extractRelevantSnippet(String content, String query, {int maxLength = 200}) {
    final normalizedQuery = query.toLowerCase();
    final normalizedContent = content.toLowerCase();
    
    final index = normalizedContent.indexOf(normalizedQuery);
    if (index == -1) {
      return content.length > maxLength 
          ? '${content.substring(0, maxLength)}...'
          : content;
    }
    
    final start = (index - 50).clamp(0, content.length);
    final end = (index + query.length + 50).clamp(0, content.length);
    
    String snippet = content.substring(start, end);
    if (start > 0) snippet = '...$snippet';
    if (end < content.length) snippet = '$snippet...';
    
    return snippet;
  }

  DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    if (timestamp is String) {
      return DateTime.tryParse(timestamp);
    }
    return null;
  }

  String _normalizeQuery(String query) {
    return query.trim().toLowerCase();
  }

  String _buildCacheKey(String uid, String query, SearchFilter? filter) {
    return '$uid:$query:${filter?.hashCode ?? 0}';
  }

  void _addToRecentSearches(String query) {
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    
    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches.removeRange(_maxRecentSearches, _recentSearches.length);
    }
  }

  List<SearchSuggestion> _getRecentSearchSuggestions(int limit) {
    return _recentSearches.take(limit).map((query) =>
      SearchSuggestion(
        text: query,
        type: SearchSuggestionType.recent,
        score: 1.0,
      )
    ).toList();
  }

  Future<List<SearchSuggestion>> _getTitleSuggestions(String uid, String partialQuery, int limit) async {
    // Implementación simplificada
    return [];
  }

  Future<List<SearchSuggestion>> _getTagSuggestions(String uid, String partialQuery, int limit) async {
    // Implementación simplificada
    return [];
  }

  Future<List<SearchSuggestion>> _getFolderSuggestions(String uid, String partialQuery, int limit) async {
    // Implementación simplificada
    return [];
  }

  Stream<SearchResult> _createRealtimeSearchStream(String uid, String query, SearchFilter? filter, int limit) async* {
    // Stream simplificado - implementar con snapshots en tiempo real
    yield SearchResult.empty();
  }

  SearchStats _calculateSearchStats(List<Map<String, dynamic>> searchHistory) {
    final topTerms = <String, int>{};
    final trends = <String, int>{};
    
    for (final search in searchHistory) {
      final query = search['query'] as String? ?? '';
      final date = search['date'] as String? ?? '';
      
      topTerms[query] = (topTerms[query] ?? 0) + 1;
      trends[date] = (trends[date] ?? 0) + 1;
    }
    
    return SearchStats(
      totalSearches: searchHistory.length,
      recentSearches: searchHistory.take(10).map((s) => s['query'] as String).toList(),
      topSearchTerms: topTerms,
      searchTrends: trends,
    );
  }

  /// Limpia recursos del servicio
  void dispose() {
    _searchCache.clear();
    _recentSearches.clear();
  }
}

/// Resultado de búsqueda
class SearchResult {
  final String query;
  final List<SearchResultItem> results;
  final int totalCount;
  final DateTime timestamp;
  final SearchFilter? filter;

  const SearchResult({
    required this.query,
    required this.results,
    required this.totalCount,
    required this.timestamp,
    this.filter,
  });

  factory SearchResult.empty() {
    return SearchResult(
      query: '',
      results: [],
      totalCount: 0,
      timestamp: DateTime.now(),
    );
  }
}

/// Elemento individual en los resultados de búsqueda
class SearchResultItem {
  final String id;
  final String title;
  final String content;
  final SearchResultType type;
  final double relevanceScore;
  final SearchMatchType matchType;
  final String highlightedText;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SearchResultItem({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.relevanceScore,
    required this.matchType,
    required this.highlightedText,
    this.createdAt,
    this.updatedAt,
  });
}

/// Filtros de búsqueda
class SearchFilter {
  final List<SearchResultType>? types;
  final DateTimeRange? dateRange;
  final List<String>? tags;
  final bool? isPinned;
  final bool? isShared;

  const SearchFilter({
    this.types,
    this.dateRange,
    this.tags,
    this.isPinned,
    this.isShared,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchFilter &&
        other.types == types &&
        other.dateRange == dateRange &&
        other.tags == tags &&
        other.isPinned == isPinned &&
        other.isShared == isShared;
  }

  @override
  int get hashCode {
    return Object.hash(types, dateRange, tags, isPinned, isShared);
  }
}

/// Sugerencia de búsqueda
class SearchSuggestion {
  final String text;
  final SearchSuggestionType type;
  final double score;
  final String? description;

  const SearchSuggestion({
    required this.text,
    required this.type,
    required this.score,
    this.description,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchSuggestion &&
        other.text == text &&
        other.type == type &&
        other.score == score &&
        other.description == description;
  }

  @override
  int get hashCode {
    return Object.hash(text, type, score, description);
  }
}

/// Estadísticas de búsqueda
class SearchStats {
  final int totalSearches;
  final List<String> recentSearches;
  final Map<String, int> topSearchTerms;
  final Map<String, int> searchTrends;

  const SearchStats({
    required this.totalSearches,
    required this.recentSearches,
    required this.topSearchTerms,
    required this.searchTrends,
  });
}

/// Enums para el sistema de búsqueda

enum SearchResultType {
  note,
  folder,
  collection,
  tag,
  user,
}

enum SearchMatchType {
  title,
  content,
  tag,
  metadata,
}

enum SearchSuggestionType {
  recent,
  popular,
  title,
  tag,
  folder,
}