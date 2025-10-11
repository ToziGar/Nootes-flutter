import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

/// Servicio para generar estadísticas y analytics de la aplicación
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;

  /// Registra un evento de uso
  Future<void> trackEvent(
    String eventName,
    Map<String, dynamic> properties,
  ) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).collection('analytics').add({
      'event': eventName,
      'properties': properties,
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateTime.now().toString().substring(0, 10), // YYYY-MM-DD
    });
  }

  /// Obtiene estadísticas generales del usuario
  Future<UserStats> getUserStats() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return UserStats.empty();

    // Obtener estadísticas de notas
    final notesSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notes')
        .get();

    // Obtener estadísticas de carpetas
    final foldersSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('folders')
        .get();

    // Calcular estadísticas de palabras y caracteres
    int totalWords = 0;
    int totalCharacters = 0;
    DateTime? firstNoteDate;
    DateTime? lastNoteDate;
    int todayNotes = 0;
    int weekNotes = 0;
    int monthNotes = 0;

    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = today.subtract(const Duration(days: 30));

    for (final doc in notesSnapshot.docs) {
      final data = doc.data();
      final content = data['content'] as String? ?? '';
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      // Contar palabras y caracteres
      totalWords += content.split(' ').where((word) => word.isNotEmpty).length;
      totalCharacters += content.length;

      // Fechas
      if (createdAt != null) {
        if (firstNoteDate == null || createdAt.isBefore(firstNoteDate)) {
          firstNoteDate = createdAt;
        }
        if (lastNoteDate == null || createdAt.isAfter(lastNoteDate)) {
          lastNoteDate = createdAt;
        }

        // Contar notas por período
        if (createdAt.isAfter(DateTime(today.year, today.month, today.day))) {
          todayNotes++;
        }
        if (createdAt.isAfter(weekAgo)) {
          weekNotes++;
        }
        if (createdAt.isAfter(monthAgo)) {
          monthNotes++;
        }
      }
    }

    return UserStats(
      totalNotes: notesSnapshot.docs.length,
      totalFolders: foldersSnapshot.docs.length,
      totalWords: totalWords,
      totalCharacters: totalCharacters,
      firstNoteDate: firstNoteDate,
      lastNoteDate: lastNoteDate,
      notesToday: todayNotes,
      notesThisWeek: weekNotes,
      notesThisMonth: monthNotes,
    );
  }

  /// Obtiene estadísticas de actividad por día de los últimos 30 días
  Future<List<DailyActivity>> getDailyActivity() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return [];

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('analytics')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('timestamp')
        .get();

    final Map<String, DailyActivity> activityMap = {};

    // Inicializar todos los días con 0 actividad
    for (int i = 0; i < 30; i++) {
      final date = DateTime.now().subtract(Duration(days: 29 - i));
      final dateKey = date.toString().substring(0, 10);
      activityMap[dateKey] = DailyActivity(
        date: date,
        notesCreated: 0,
        notesEdited: 0,
        totalEvents: 0,
      );
    }

    // Contar eventos por día
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final date = data['date'] as String?;
      final event = data['event'] as String?;

      if (date != null && activityMap.containsKey(date)) {
        activityMap[date] = activityMap[date]!.copyWith(
          totalEvents: activityMap[date]!.totalEvents + 1,
          notesCreated: event == 'note_created'
              ? activityMap[date]!.notesCreated + 1
              : activityMap[date]!.notesCreated,
          notesEdited: event == 'note_edited'
              ? activityMap[date]!.notesEdited + 1
              : activityMap[date]!.notesEdited,
        );
      }
    }

    return activityMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Obtiene estadísticas de las carpetas más utilizadas
  Future<List<FolderStats>> getFolderStats() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return [];

    // Obtener todas las carpetas
    final foldersSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('folders')
        .get();

    final folderStats = <FolderStats>[];

    for (final folderDoc in foldersSnapshot.docs) {
      final folderData = folderDoc.data();
      final folderId = folderDoc.id;
      final folderName = folderData['name'] as String? ?? 'Sin nombre';

      // Contar notas en esta carpeta
      final notesSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notes')
          .where('folderId', isEqualTo: folderId)
          .get();

      if (notesSnapshot.docs.isNotEmpty) {
        int totalWords = 0;
        DateTime? lastActivity;

        for (final noteDoc in notesSnapshot.docs) {
          final noteData = noteDoc.data();
          final content = noteData['content'] as String? ?? '';
          final updatedAt = (noteData['updatedAt'] as Timestamp?)?.toDate();

          totalWords += content
              .split(' ')
              .where((word) => word.isNotEmpty)
              .length;

          if (updatedAt != null) {
            if (lastActivity == null || updatedAt.isAfter(lastActivity)) {
              lastActivity = updatedAt;
            }
          }
        }

        folderStats.add(
          FolderStats(
            folderId: folderId,
            folderName: folderName,
            noteCount: notesSnapshot.docs.length,
            totalWords: totalWords,
            lastActivity: lastActivity,
          ),
        );
      }
    }

    // Ordenar por número de notas (descendente)
    folderStats.sort((a, b) => b.noteCount.compareTo(a.noteCount));
    return folderStats;
  }

  /// Obtiene estadísticas de etiquetas más utilizadas
  Future<List<TagStats>> getTagStats() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return [];

    final notesSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notes')
        .get();

    final Map<String, int> tagCounts = {};

    for (final doc in notesSnapshot.docs) {
      final data = doc.data();
      final tags = data['tags'] as List<dynamic>? ?? [];

      for (final tag in tags) {
        if (tag is String && tag.isNotEmpty) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
    }

    final tagStats = tagCounts.entries
        .map((entry) => TagStats(tag: entry.key, count: entry.value))
        .toList();

    // Ordenar por frecuencia (descendente)
    tagStats.sort((a, b) => b.count.compareTo(a.count));
    return tagStats.take(20).toList(); // Top 20 etiquetas
  }

  /// Obtiene horarios de mayor productividad
  Future<List<HourlyActivity>> getHourlyActivity() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('analytics')
        .where('event', whereIn: ['note_created', 'note_edited'])
        .get();

    final Map<int, int> hourlyActivity = {};

    // Inicializar todas las horas
    for (int i = 0; i < 24; i++) {
      hourlyActivity[i] = 0;
    }

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

      if (timestamp != null) {
        final hour = timestamp.hour;
        hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + 1;
      }
    }

    return hourlyActivity.entries
        .map((entry) => HourlyActivity(hour: entry.key, activity: entry.value))
        .toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));
  }

  // Métodos para registrar eventos específicos
  Future<void> trackNoteCreated(String noteId) async {
    await trackEvent('note_created', {'noteId': noteId});
  }

  Future<void> trackNoteEdited(String noteId) async {
    await trackEvent('note_edited', {'noteId': noteId});
  }

  Future<void> trackNoteDeleted(String noteId) async {
    await trackEvent('note_deleted', {'noteId': noteId});
  }

  Future<void> trackFolderCreated(String folderId) async {
    await trackEvent('folder_created', {'folderId': folderId});
  }

  Future<void> trackSearch(String query) async {
    await trackEvent('search', {'query': query});
  }

  Future<void> trackExport(String format) async {
    await trackEvent('export', {'format': format});
  }
}

/// Clase para estadísticas generales del usuario
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

  int get averageWordsPerNote => totalNotes > 0 ? totalWords ~/ totalNotes : 0;
  int get averageCharactersPerNote =>
      totalNotes > 0 ? totalCharacters ~/ totalNotes : 0;

  int get daysSinceFirstNote {
    if (firstNoteDate == null) return 0;
    return DateTime.now().difference(firstNoteDate!).inDays;
  }
}

/// Clase para actividad diaria
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

/// Clase para estadísticas de carpetas
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

/// Clase para estadísticas de etiquetas
class TagStats {
  final String tag;
  final int count;

  const TagStats({required this.tag, required this.count});
}

/// Clase para actividad por hora
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
