import 'dart:convert';

class Note {
  final String id;
  String title;
  String content;
  List<String> tags;
  bool pinned;
  DateTime createdAt;
  DateTime updatedAt;
  bool encrypted;

  Note({
    required this.id,
    this.title = '',
    this.content = '',
    List<String>? tags,
    this.pinned = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.encrypted = false,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'tags': tags,
        'pinned': pinned,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'encrypted': encrypted,
      };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
        id: m['id'].toString(),
        title: m['title']?.toString() ?? '',
        content: m['content']?.toString() ?? '',
        tags: (m['tags'] as List?)?.whereType<String>().toList() ?? [],
        pinned: m['pinned'] == true,
        createdAt: m['createdAt'] != null ? DateTime.parse(m['createdAt'].toString()).toUtc() : DateTime.now().toUtc(),
        updatedAt: m['updatedAt'] != null ? DateTime.parse(m['updatedAt'].toString()).toUtc() : DateTime.now().toUtc(),
        encrypted: m['encrypted'] == true,
      );

  String toJson() => jsonEncode(toMap());

  factory Note.fromJson(String src) => Note.fromMap(jsonDecode(src) as Map<String, dynamic>);
}
