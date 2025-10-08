import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio para persistir preferencias y estado de la aplicación
class PreferencesService {
  static const _storage = FlutterSecureStorage();
  
  // Keys
  static const _keySelectedFolder = 'workspace_selected_folder';
  static const _keyFilterTags = 'workspace_filter_tags';
  static const _keyDateRangeStart = 'workspace_date_range_start';
  static const _keyDateRangeEnd = 'workspace_date_range_end';
  static const _keySortOption = 'workspace_sort_option';
  static const _keyRecentSearches = 'workspace_recent_searches';
  static const _keyCompactMode = 'workspace_compact_mode';
  static const _keyNoteCache = 'workspace_note_cache_';
  static const _keyThemeMode = 'app_theme_mode';
  static const _keyLocale = 'app_locale';
  
  // Carpeta seleccionada
  static Future<String?> getSelectedFolder() async {
    return await _storage.read(key: _keySelectedFolder);
  }
  
  static Future<void> setSelectedFolder(String? folderId) async {
    if (folderId == null) {
      await _storage.delete(key: _keySelectedFolder);
    } else {
      await _storage.write(key: _keySelectedFolder, value: folderId);
    }
  }
  
  // Filtros de tags
  static Future<List<String>> getFilterTags() async {
    final json = await _storage.read(key: _keyFilterTags);
    if (json == null) return [];
    try {
      return List<String>.from(jsonDecode(json));
    } catch (e) {
      return [];
    }
  }
  
  static Future<void> setFilterTags(List<String> tags) async {
    if (tags.isEmpty) {
      await _storage.delete(key: _keyFilterTags);
    } else {
      await _storage.write(key: _keyFilterTags, value: jsonEncode(tags));
    }
  }
  
  // Rango de fechas
  static Future<Map<String, String>?> getDateRange() async {
    final start = await _storage.read(key: _keyDateRangeStart);
    final end = await _storage.read(key: _keyDateRangeEnd);
    if (start == null || end == null) return null;
    return {'start': start, 'end': end};
  }
  
  static Future<void> setDateRange(DateTime? start, DateTime? end) async {
    if (start == null || end == null) {
      await _storage.delete(key: _keyDateRangeStart);
      await _storage.delete(key: _keyDateRangeEnd);
    } else {
      await _storage.write(key: _keyDateRangeStart, value: start.toIso8601String());
      await _storage.write(key: _keyDateRangeEnd, value: end.toIso8601String());
    }
  }
  
  // Opción de ordenamiento
  static Future<String?> getSortOption() async {
    return await _storage.read(key: _keySortOption);
  }
  
  static Future<void> setSortOption(String option) async {
    await _storage.write(key: _keySortOption, value: option);
  }
  
  // Búsquedas recientes (máximo 10)
  static Future<List<String>> getRecentSearches() async {
    final json = await _storage.read(key: _keyRecentSearches);
    if (json == null) return [];
    try {
      return List<String>.from(jsonDecode(json));
    } catch (e) {
      return [];
    }
  }
  
  static Future<void> addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    final recent = await getRecentSearches();
    recent.remove(query); // Eliminar si ya existe
    recent.insert(0, query); // Agregar al inicio
    
    // Mantener solo los últimos 10
    if (recent.length > 10) {
      recent.removeRange(10, recent.length);
    }
    
    await _storage.write(key: _keyRecentSearches, value: jsonEncode(recent));
  }
  
  static Future<void> clearRecentSearches() async {
    await _storage.delete(key: _keyRecentSearches);
  }
  
  // Modo compacto
  static Future<bool> getCompactMode() async {
    final value = await _storage.read(key: _keyCompactMode);
    return value == 'true';
  }
  
  static Future<void> setCompactMode(bool compact) async {
    await _storage.write(key: _keyCompactMode, value: compact.toString());
  }
  
  // Caché de notas (por uid)
  static Future<Map<String, dynamic>?> getNoteCache(String uid) async {
    final json = await _storage.read(key: '$_keyNoteCache$uid');
    if (json == null) return null;
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final timestamp = DateTime.parse(data['timestamp'] as String);
      // Caché válido por 5 minutos
      if (DateTime.now().difference(timestamp).inMinutes > 5) {
        return null;
      }
      return data;
    } catch (e) {
      return null;
    }
  }
  
  static Future<void> setNoteCache(String uid, List<Map<String, dynamic>> notes) async {
    // Convertir Timestamp a String para serialización
    final serializedNotes = notes.map((note) {
      final serialized = Map<String, dynamic>.from(note);
      // Convertir createdAt si es Timestamp
      if (serialized['createdAt'] != null) {
        final createdAt = serialized['createdAt'];
        if (createdAt is DateTime) {
          serialized['createdAt'] = createdAt.toIso8601String();
        } else if (createdAt is int) {
          serialized['createdAt'] = DateTime.fromMillisecondsSinceEpoch(createdAt).toIso8601String();
        } else {
          // Si es Timestamp de Firestore, tiene toDate()
          try {
            serialized['createdAt'] = (createdAt as dynamic).toDate().toIso8601String();
          } catch (e) {
            serialized['createdAt'] = DateTime.now().toIso8601String();
          }
        }
      }
      // Convertir updatedAt si es Timestamp
      if (serialized['updatedAt'] != null) {
        final updatedAt = serialized['updatedAt'];
        if (updatedAt is DateTime) {
          serialized['updatedAt'] = updatedAt.toIso8601String();
        } else if (updatedAt is int) {
          serialized['updatedAt'] = DateTime.fromMillisecondsSinceEpoch(updatedAt).toIso8601String();
        } else {
          try {
            serialized['updatedAt'] = (updatedAt as dynamic).toDate().toIso8601String();
          } catch (e) {
            serialized['updatedAt'] = DateTime.now().toIso8601String();
          }
        }
      }
      return serialized;
    }).toList();
    
    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'notes': serializedNotes,
    };
    await _storage.write(key: '$_keyNoteCache$uid', value: jsonEncode(data));
  }
  
  static Future<void> clearNoteCache(String uid) async {
    await _storage.delete(key: '$_keyNoteCache$uid');
  }
  
  // Limpiar todas las preferencias
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
  
  // ==================== TEMA E IDIOMA ====================
  
  /// Obtiene el modo de tema guardado (light, dark, system)
  static Future<ThemeMode> getThemeMode() async {
    final String? themeModeString = await _storage.read(key: _keyThemeMode);
    
    switch (themeModeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
  
  /// Guarda el modo de tema
  static Future<void> setThemeMode(ThemeMode themeMode) async {
    String themeModeString;
    
    switch (themeMode) {
      case ThemeMode.light:
        themeModeString = 'light';
        break;
      case ThemeMode.dark:
        themeModeString = 'dark';
        break;
      case ThemeMode.system:
        themeModeString = 'system';
        break;
    }
    
    await _storage.write(key: _keyThemeMode, value: themeModeString);
  }
  
  /// Obtiene el idioma guardado
  static Future<Locale> getLocale() async {
    final String? localeString = await _storage.read(key: _keyLocale);
    
    switch (localeString) {
      case 'en':
        return const Locale('en', '');
      case 'es':
      default:
        return const Locale('es', '');
    }
  }
  
  /// Guarda el idioma
  static Future<void> setLocale(Locale locale) async {
    await _storage.write(key: _keyLocale, value: locale.languageCode);
  }
  
  /// Obtiene el modo de tema como string para la UI
  static Future<String> getThemeModeString() async {
    final themeMode = await getThemeMode();
    switch (themeMode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }
  
  /// Obtiene el idioma como string para la UI
  static Future<String> getLanguageString() async {
    final locale = await getLocale();
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'es':
      default:
        return 'Español';
    }
  }
}
