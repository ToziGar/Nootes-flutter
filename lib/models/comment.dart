class Comment {
  final String id;
  final String noteId;
  final String authorId;
  final String authorEmail;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;

  Comment({
    required this.id,
    required this.noteId,
    required this.authorId,
    required this.authorEmail,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.isEdited = false,
  });

  factory Comment.fromMap(Map<String, dynamic> data, String id) {
    return Comment(
      id: id,
      noteId: data['noteId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorEmail: data['authorEmail'] ?? '',
      authorName: data['authorName'] ?? '',
      content: data['content'] ?? '',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate(),
      isEdited: data['isEdited'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'noteId': noteId,
      'authorId': authorId,
      'authorEmail': authorEmail,
      'authorName': authorName,
      'content': content,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isEdited': isEdited,
    };
  }

  Comment copyWith({
    String? id,
    String? noteId,
    String? authorId,
    String? authorEmail,
    String? authorName,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
  }) {
    return Comment(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      authorId: authorId ?? this.authorId,
      authorEmail: authorEmail ?? this.authorEmail,
      authorName: authorName ?? this.authorName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}