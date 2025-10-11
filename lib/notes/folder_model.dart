import 'package:flutter/material.dart';
import '../theme/icon_registry.dart';

/// Modelo de carpeta para organizar notas
class Folder {
  final String id;
  final String name;
  final IconData icon;
  final String? emoji; // Emoji personalizado, tiene prioridad sobre icon
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
    this.emoji,
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
      emoji: json['emoji'] as String?,
      color: _parseColor(json['color']),
      noteIds: List<String>.from(json['noteIds'] as List? ?? []),
      docId: json['docId'] as String? ?? (json['id'] as String),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      order: json['order'] as int? ?? 0,
    );
  }

  static Color _parseColor(dynamic value) {
    if (value is int) return Color(value);
    if (value is double) return Color(value.toInt());
    if (value is String) {
      // Try parse hex string like 'ff00ff00' or '#ff00ff00' or '00ff00' (RGB)
      var cleaned = value.replaceAll('#', '').toLowerCase();
      if (cleaned.length == 6) {
        // If only RGB provided, assume fully opaque
        cleaned = 'ff$cleaned';
      }
      final parsed = int.tryParse(cleaned, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return const Color(0xFFF59E0B);
  }

  /// Convertir carpeta a JSON para Firestore
  Map<String, dynamic> toJson() {
    final result = {
      'id': id,
      'docId': docId,
      'name': name,
      'icon': _iconToString(icon),
      'color': color.toARGB32(),
      'noteIds': noteIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'order': order,
    };

    if (emoji != null) {
      result['emoji'] = emoji!;
    }

    return result;
  }

  /// Copiar carpeta con cambios
  Folder copyWith({
    String? id,
    String? name,
    IconData? icon,
    String? emoji,
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
      emoji: emoji ?? this.emoji,
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
    return copyWith(noteIds: [...noteIds, noteId], updatedAt: DateTime.now());
  }

  /// Remover nota de la carpeta
  Folder removeNote(String noteId) {
    return copyWith(
      noteIds: noteIds.where((id) => id != noteId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  // Mapeo de strings a IconData - ahora usa NoteIconRegistry
  static IconData _iconFromString(String iconName) {
    return NoteIconRegistry.iconFromName(iconName) ?? Icons.folder_rounded;
  }

  static String _iconToString(IconData icon) {
    return NoteIconRegistry.nameFromIcon(icon);
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

  /// Iconos disponibles para carpetas - ahora usa todo el NoteIconRegistry
  static List<IconData> get availableIcons =>
      NoteIconRegistry.icons.values.toList();
}
