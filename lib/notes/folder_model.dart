import 'package:flutter/material.dart';

/// Modelo de carpeta para organizar notas
class Folder {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final List<String> noteIds; // IDs de las notas en esta carpeta
  final String docId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int order;
  
  Folder({
    required this.id,
    required this.name,
    this.icon = Icons.folder_rounded,
    this.color = const Color(0xFFF59E0B),
    this.noteIds = const [],
    this.docId = '',
    required this.createdAt,
    required this.updatedAt,
    this.order = 0,
  });
  
  /// Crear carpeta desde JSON de Firestore
  factory Folder.fromJson(Map<String, dynamic> json) {
    // Helper para convertir tanto Timestamp como String a DateTime
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      // Firestore Timestamp tiene toDate()
      if (value.runtimeType.toString() == 'Timestamp') {
        return (value as dynamic).toDate() as DateTime;
      }
      return DateTime.now();
    }
    
    return Folder(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: _iconFromString(json['icon'] as String? ?? 'folder_rounded'),
      color: Color(json['color'] as int? ?? 0xFFF59E0B),
      noteIds: List<String>.from(json['noteIds'] as List? ?? []),
      docId: json['docId'] as String? ?? (json['id'] as String),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      order: json['order'] as int? ?? 0,
    );
  }
  
  /// Convertir carpeta a JSON para Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'docId': docId,
      'name': name,
      'icon': _iconToString(icon),
      'color': color.value,
      'noteIds': noteIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'order': order,
    };
  }
  
  /// Copiar carpeta con cambios
  Folder copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    List<String>? noteIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? order,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      noteIds: noteIds ?? this.noteIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
    );
  }
  
  /// Agregar nota a la carpeta
  Folder addNote(String noteId) {
    if (noteIds.contains(noteId)) return this;
    return copyWith(
      noteIds: [...noteIds, noteId],
      updatedAt: DateTime.now(),
    );
  }
  
  /// Remover nota de la carpeta
  Folder removeNote(String noteId) {
    return copyWith(
      noteIds: noteIds.where((id) => id != noteId).toList(),
      updatedAt: DateTime.now(),
    );
  }
  
  // Mapeo de strings a IconData
  static IconData _iconFromString(String iconName) {
    final iconMap = {
      'folder_rounded': Icons.folder_rounded,
      'work_rounded': Icons.work_rounded,
      'school_rounded': Icons.school_rounded,
      'home_rounded': Icons.home_rounded,
      'favorite_rounded': Icons.favorite_rounded,
      'star_rounded': Icons.star_rounded,
      'bookmark_rounded': Icons.bookmark_rounded,
      'lightbulb_rounded': Icons.lightbulb_rounded,
      'code_rounded': Icons.code_rounded,
      'palette_rounded': Icons.palette_rounded,
      'music_note_rounded': Icons.music_note_rounded,
      'sports_esports_rounded': Icons.sports_esports_rounded,
      'restaurant_rounded': Icons.restaurant_rounded,
      'flight_rounded': Icons.flight_rounded,
      'shopping_bag_rounded': Icons.shopping_bag_rounded,
    };
    return iconMap[iconName] ?? Icons.folder_rounded;
  }
  
  static String _iconToString(IconData icon) {
    final iconMap = {
      Icons.folder_rounded.codePoint: 'folder_rounded',
      Icons.work_rounded.codePoint: 'work_rounded',
      Icons.school_rounded.codePoint: 'school_rounded',
      Icons.home_rounded.codePoint: 'home_rounded',
      Icons.favorite_rounded.codePoint: 'favorite_rounded',
      Icons.star_rounded.codePoint: 'star_rounded',
      Icons.bookmark_rounded.codePoint: 'bookmark_rounded',
      Icons.lightbulb_rounded.codePoint: 'lightbulb_rounded',
      Icons.code_rounded.codePoint: 'code_rounded',
      Icons.palette_rounded.codePoint: 'palette_rounded',
      Icons.music_note_rounded.codePoint: 'music_note_rounded',
      Icons.sports_esports_rounded.codePoint: 'sports_esports_rounded',
      Icons.restaurant_rounded.codePoint: 'restaurant_rounded',
      Icons.flight_rounded.codePoint: 'flight_rounded',
      Icons.shopping_bag_rounded.codePoint: 'shopping_bag_rounded',
    };
    return iconMap[icon.codePoint] ?? 'folder_rounded';
  }
  
  /// Colores predefinidos para carpetas
  static const List<Color> availableColors = [
    Color(0xFFF59E0B), // Amber
    Color(0xFF6366F1), // Indigo
    Color(0xFFEF4444), // Red
    Color(0xFF10B981), // Green
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
    Color(0xFFF97316), // Orange
  ];
  
  /// Iconos disponibles para carpetas
  static const List<IconData> availableIcons = [
    Icons.folder_rounded,
    Icons.work_rounded,
    Icons.school_rounded,
    Icons.home_rounded,
    Icons.favorite_rounded,
    Icons.star_rounded,
    Icons.bookmark_rounded,
    Icons.lightbulb_rounded,
    Icons.code_rounded,
    Icons.palette_rounded,
    Icons.music_note_rounded,
    Icons.sports_esports_rounded,
    Icons.restaurant_rounded,
    Icons.flight_rounded,
    Icons.shopping_bag_rounded,
  ];
}
