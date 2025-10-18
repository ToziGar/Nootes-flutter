import 'package:nootes/utils/debug.dart';

/// Minimal analytics service placeholder.
/// Replace with integration (Firebase Analytics, Amplitude, etc.) later.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  /// Log a generic event. In debug mode this prints to console.
  void logEvent(String name, [Map<String, dynamic>? params]) {
    // Use centralized debug logger
    logDebug('ANALYTICS: $name ${params ?? {}}');
  }

  // --- Placeholder async methods used by UI (return defaults) ---
  Future<UserStats> getUserStats() async => UserStats.empty();

  Future<List<DailyActivity>> getDailyActivity() async => <DailyActivity>[];

  Future<List<FolderStats>> getFolderStats() async => <FolderStats>[];

  Future<List<TagStats>> getTagStats() async => <TagStats>[];

  Future<List<HourlyActivity>> getHourlyActivity() async => <HourlyActivity>[];

  Future<void> trackEvent(String event, [Map<String, dynamic>? props]) async {
    // no-op placeholder
    logEvent(event, props);
  }
}

/// --- Types used by stats dashboard (kept minimal so UI compiles) ---
class UserStats {
  final int totalNotes;
  final int totalFolders;
  final int totalWords;
  final int totalCharacters;
  final DateTime? firstNoteDate;
  final DateTime? lastNoteDate;
  final int notesToday;
  final int notesThisWeek;
  final int notesThisMonth;

  const UserStats({
    required this.totalNotes,
    required this.totalFolders,
    required this.totalWords,
    required this.totalCharacters,
    this.firstNoteDate,
    this.lastNoteDate,
    required this.notesToday,
    required this.notesThisWeek,
    required this.notesThisMonth,
  });

  factory UserStats.empty() {
    return const UserStats(
      totalNotes: 0,
      totalFolders: 0,
      totalWords: 0,
      totalCharacters: 0,
      notesToday: 0,
      notesThisWeek: 0,
      notesThisMonth: 0,
    );
  }

  /// Average number of words per note (rounded down). Returns 0 when no notes.
  int get averageWordsPerNote => totalNotes > 0 ? (totalWords ~/ totalNotes) : 0;

  /// Days since the first note was created. Returns 0 when unknown.
  int get daysSinceFirstNote {
    if (firstNoteDate == null) return 0;
    final diff = DateTime.now().difference(firstNoteDate!);
    return diff.inDays;
  }
}

class DailyActivity {
  final DateTime date;
  final int notesCreated;
  final int notesEdited;
  final int totalEvents;

  const DailyActivity({
    required this.date,
    required this.notesCreated,
    required this.notesEdited,
    required this.totalEvents,
  });

  DailyActivity copyWith({
    DateTime? date,
    int? notesCreated,
    int? notesEdited,
    int? totalEvents,
  }) {
    return DailyActivity(
      date: date ?? this.date,
      notesCreated: notesCreated ?? this.notesCreated,
      notesEdited: notesEdited ?? this.notesEdited,
      totalEvents: totalEvents ?? this.totalEvents,
    );
  }
}

class FolderStats {
  final String folderId;
  final String folderName;
  final int noteCount;
  final int totalWords;
  final DateTime? lastActivity;

  const FolderStats({
    required this.folderId,
    required this.folderName,
    required this.noteCount,
    required this.totalWords,
    this.lastActivity,
  });
}

class TagStats {
  final String tag;
  final int count;
  const TagStats({required this.tag, required this.count});
}

class HourlyActivity {
  final int hour;
  final int activity;
  const HourlyActivity({required this.hour, required this.activity});

  String get hourLabel {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}
