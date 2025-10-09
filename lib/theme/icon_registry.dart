import 'package:flutter/material.dart';

/// Central registry for note/folder icons and a rich color palette.
class NoteIconRegistry {
  /// Map of token -> IconData
  static const Map<String, IconData> icons = {
    // Essentials
    'note': Icons.description_rounded,
    'star': Icons.star_rounded,
    'task': Icons.check_circle_rounded,
    'idea': Icons.lightbulb_rounded,
    'code': Icons.code_rounded,
    'link': Icons.link_rounded,
    'audio': Icons.mic_rounded,
    'image': Icons.image_rounded,
    'book': Icons.book_rounded,
    'folder': Icons.folder_rounded,

    // Work & study
    'work': Icons.work_rounded,
    'school': Icons.school_rounded,
    'home': Icons.home_rounded,
    'calendar': Icons.calendar_month_rounded,
    'meeting': Icons.groups_rounded,
    'task_alt': Icons.task_alt_rounded,

    // Content types
    'video': Icons.movie_rounded,
    'music': Icons.music_note_rounded,
    'photo': Icons.photo_rounded,
    'draw': Icons.brush_rounded,
    'table': Icons.table_chart_rounded,
    'chart': Icons.query_stats_rounded,

    // Categories
    'finance': Icons.attach_money_rounded,
    'shopping': Icons.shopping_cart_rounded,
    'travel': Icons.travel_explore_rounded,
    'fitness': Icons.fitness_center_rounded,
    'game': Icons.sports_esports_rounded,
    'food': Icons.restaurant_rounded,
    'health': Icons.health_and_safety_rounded,
    'idea_bulb': Icons.tips_and_updates_rounded,

    // Misc
    'bookmark': Icons.bookmark_rounded,
    'favorite': Icons.favorite_rounded,
    'pin': Icons.push_pin_rounded,
    'inbox': Icons.inbox_rounded,
    'tag': Icons.sell_rounded,
    'cloud': Icons.cloud_rounded,
    'security': Icons.lock_rounded,
  };

  /// Large, tasteful color palette to choose from.
  static const List<Color> palette = [
    // Purples / Blues
    Color(0xFF6C5CE7), Color(0xFF8B7FF8), Color(0xFF3B82F6), Color(0xFF2563EB),
    Color(0xFF1D4ED8), Color(0xFF60A5FA), Color(0xFF7C3AED),
    // Teals / Greens
    Color(0xFF10B981), Color(0xFF14B8A6), Color(0xFF34D399), Color(0xFF06B6D4),
    Color(0xFF0EA5E9), Color(0xFF22C55E),
    // Oranges / Reds / Pink
    Color(0xFFF59E0B), Color(0xFFFB923C), Color(0xFFEF4444), Color(0xFFE11D48),
    Color(0xFFF472B6), Color(0xFFFF7675),
    // Neutrals
    Color(0xFF9CA3AF), Color(0xFF6B7280), Color(0xFFF3F4F6),
  ];

  static IconData? iconFromName(String? name) => name == null ? null : icons[name];
  static String nameFromIcon(IconData icon) {
    return icons.entries.firstWhere((e) => e.value == icon, orElse: () => const MapEntry('note', Icons.description_rounded)).key;
  }
}
