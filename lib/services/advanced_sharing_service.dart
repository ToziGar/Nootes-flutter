import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/toast_service.dart';
import '../utils/debug.dart';

enum SharePermission { view, comment, edit }

enum ShareStatus { pending, accepted, declined, revoked, expired }

enum NotificationType {
  shareInvite,
  permissionChanged,
  noteUpdated,
  commentAdded,
  accessRevoked,
  collaboratorJoined,
}

enum CollaboratorStatus { online, offline, away, busy }

enum ActivityType {
  created,
  edited,
  commented,
  shared,
  permissionChanged,
  accessed,
  exported,
  deleted,
}

enum PermissionTemplate { viewer, commenter, editor, admin, custom }

enum CommentType { general, suggestion, question, approval, rejection }

enum VersionAction { created, edited, restored, merged, branched }

enum ApprovalStatus { pending, approved, rejected, needsRevision }

enum CalendarEventType { deadline, review, meeting, reminder }

class NoteComment {
  final String id;
  final String noteId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final CommentType type;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? parentId; // Para comentarios anidados
  final List<String> mentions; // @usuarios mencionados
  final Map<String, dynamic> metadata;
  final List<String> attachments;
  final bool isResolved;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final int position; // Posición en el documento
  final String? selectedText; // Texto seleccionado para comentar

  NoteComment({
    required this.id,
    required this.noteId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.type,
    required this.createdAt,
    this.updatedAt,
    this.parentId,
    this.mentions = const [],
    this.metadata = const {},
    this.attachments = const [],
    this.isResolved = false,
    this.resolvedBy,
    this.resolvedAt,
    this.position = 0,
    this.selectedText,
  });

  factory NoteComment.fromJson(Map<String, dynamic> json) {
    return NoteComment(
      id: json['id'] ?? '',
      noteId: json['noteId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userAvatar: json['userAvatar'] ?? '',
      content: json['content'] ?? '',
      type: CommentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CommentType.general,
      ),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
      parentId: json['parentId'],
      mentions: List<String>.from(json['mentions'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      attachments: List<String>.from(json['attachments'] ?? []),
      isResolved: json['isResolved'] ?? false,
      resolvedBy: json['resolvedBy'],
      resolvedAt: json['resolvedAt'] != null
          ? (json['resolvedAt'] as Timestamp).toDate()
          : null,
      position: json['position'] ?? 0,
      selectedText: json['selectedText'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'parentId': parentId,
      'mentions': mentions,
      'metadata': metadata,
      'attachments': attachments,
      'isResolved': isResolved,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'position': position,
      'selectedText': selectedText,
    };
  }
}

class NoteVersion {
  final String id;
  final String noteId;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final VersionAction action;
  final String? previousVersionId;
  final Map<String, dynamic> changes;
  final String changesSummary;
  final bool isMinor;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  NoteVersion({
    required this.id,
    required this.noteId,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.action,
    this.previousVersionId,
    this.changes = const {},
    required this.changesSummary,
    this.isMinor = false,
    this.tags = const [],
    this.metadata = const {},
  });

  factory NoteVersion.fromJson(Map<String, dynamic> json) {
    return NoteVersion(
      id: json['id'] ?? '',
      noteId: json['noteId'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      action: VersionAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => VersionAction.edited,
      ),
      previousVersionId: json['previousVersionId'],
      changes: Map<String, dynamic>.from(json['changes'] ?? {}),
      changesSummary: json['changesSummary'] ?? '',
      isMinor: json['isMinor'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'action': action.name,
      'previousVersionId': previousVersionId,
      'changes': changes,
      'changesSummary': changesSummary,
      'isMinor': isMinor,
      'tags': tags,
      'metadata': metadata,
    };
  }
}

class ApprovalRequest {
  final String id;
  final String noteId;
  final String noteTitle;
  final String requesterId;
  final String requesterName;
  final List<String> approverIds;
  final ApprovalStatus status;
  final String description;
  final DateTime createdAt;
  final DateTime? deadline;
  final Map<String, ApprovalStatus> approvals; // userId -> status
  final Map<String, String> comments; // userId -> comment
  final Map<String, DateTime> timestamps; // userId -> timestamp
  final bool requiresAllApprovals;
  final String? currentVersionId;

  ApprovalRequest({
    required this.id,
    required this.noteId,
    required this.noteTitle,
    required this.requesterId,
    required this.requesterName,
    required this.approverIds,
    required this.status,
    required this.description,
    required this.createdAt,
    this.deadline,
    this.approvals = const {},
    this.comments = const {},
    this.timestamps = const {},
    this.requiresAllApprovals = false,
    this.currentVersionId,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    final approvalsMap = <String, ApprovalStatus>{};
    if (json['approvals'] != null) {
      (json['approvals'] as Map<String, dynamic>).forEach((key, value) {
        approvalsMap[key] = ApprovalStatus.values.firstWhere(
          (e) => e.name == value,
          orElse: () => ApprovalStatus.pending,
        );
      });
    }

    final timestampsMap = <String, DateTime>{};
    if (json['timestamps'] != null) {
      (json['timestamps'] as Map<String, dynamic>).forEach((key, value) {
        timestampsMap[key] = (value as Timestamp).toDate();
      });
    }

    return ApprovalRequest(
      id: json['id'] ?? '',
      noteId: json['noteId'] ?? '',
      noteTitle: json['noteTitle'] ?? '',
      requesterId: json['requesterId'] ?? '',
      requesterName: json['requesterName'] ?? '',
      approverIds: List<String>.from(json['approverIds'] ?? []),
      status: ApprovalStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ApprovalStatus.pending,
      ),
      description: json['description'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      deadline: json['deadline'] != null
          ? (json['deadline'] as Timestamp).toDate()
          : null,
      approvals: approvalsMap,
      comments: Map<String, String>.from(json['comments'] ?? {}),
      timestamps: timestampsMap,
      requiresAllApprovals: json['requiresAllApprovals'] ?? false,
      currentVersionId: json['currentVersionId'],
    );
  }

  Map<String, dynamic> toJson() {
    final approvalsMap = <String, String>{};
    approvals.forEach((key, value) {
      approvalsMap[key] = value.name;
    });

    final timestampsMap = <String, dynamic>{};
    timestamps.forEach((key, value) {
      timestampsMap[key] = Timestamp.fromDate(value);
    });

    return {
      'id': id,
      'noteId': noteId,
      'noteTitle': noteTitle,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'approverIds': approverIds,
      'status': status.name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'approvals': approvalsMap,
      'comments': comments,
      'timestamps': timestampsMap,
      'requiresAllApprovals': requiresAllApprovals,
      'currentVersionId': currentVersionId,
    };
  }
}

class CalendarEvent {
  final String id;
  final String noteId;
  final String noteTitle;
  final String title;
  final String description;
  final CalendarEventType type;
  final DateTime startTime;
  final DateTime? endTime;
  final List<String> attendeeIds;
  final Map<String, String> attendeeNames;
  final String createdBy;
  final DateTime createdAt;
  final bool isAllDay;
  final String? location;
  final Map<String, dynamic> metadata;
  final List<String> reminders; // Minutos antes: ["15", "60", "1440"]

  CalendarEvent({
    required this.id,
    required this.noteId,
    required this.noteTitle,
    required this.title,
    required this.description,
    required this.type,
    required this.startTime,
    this.endTime,
    this.attendeeIds = const [],
    this.attendeeNames = const {},
    required this.createdBy,
    required this.createdAt,
    this.isAllDay = false,
    this.location,
    this.metadata = const {},
    this.reminders = const [],
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] ?? '',
      noteId: json['noteId'] ?? '',
      noteTitle: json['noteTitle'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: CalendarEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CalendarEventType.reminder,
      ),
      startTime: (json['startTime'] as Timestamp).toDate(),
      endTime: json['endTime'] != null
          ? (json['endTime'] as Timestamp).toDate()
          : null,
      attendeeIds: List<String>.from(json['attendeeIds'] ?? []),
      attendeeNames: Map<String, String>.from(json['attendeeNames'] ?? {}),
      createdBy: json['createdBy'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      isAllDay: json['isAllDay'] ?? false,
      location: json['location'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      reminders: List<String>.from(json['reminders'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'noteTitle': noteTitle,
      'title': title,
      'description': description,
      'type': type.name,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'attendeeIds': attendeeIds,
      'attendeeNames': attendeeNames,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isAllDay': isAllDay,
      'location': location,
      'metadata': metadata,
      'reminders': reminders,
    };
  }
}

class ShareNotification {
  final String id;
  final String userId;
  final String noteId;
  final String? folderId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;
  final String? actionUrl;
  final String? fromUserId;
  final String? fromUserName;

  ShareNotification({
    required this.id,
    required this.userId,
    required this.noteId,
    this.folderId,
    required this.type,
    required this.title,
    required this.message,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
    this.actionUrl,
    this.fromUserId,
    this.fromUserName,
  });

  factory ShareNotification.fromJson(Map<String, dynamic> json) {
    return ShareNotification(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      noteId: json['noteId'] ?? '',
      folderId: json['folderId'],
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.shareInvite,
      ),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      isRead: json['isRead'] ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      actionUrl: json['actionUrl'],
      fromUserId: json['fromUserId'],
      fromUserName: json['fromUserName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'noteId': noteId,
      'folderId': folderId,
      'type': type.name,
      'title': title,
      'message': message,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'actionUrl': actionUrl,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
    };
  }
}

class ActivityLog {
  final String id;
  final String noteId;
  final String? folderId;
  final String userId;
  final String userName;
  final ActivityType type;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final String? ipAddress;
  final String? deviceInfo;

  ActivityLog({
    required this.id,
    required this.noteId,
    this.folderId,
    required this.userId,
    required this.userName,
    required this.type,
    required this.description,
    this.metadata = const {},
    required this.timestamp,
    this.ipAddress,
    this.deviceInfo,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] ?? '',
      noteId: json['noteId'] ?? '',
      folderId: json['folderId'],
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      type: ActivityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ActivityType.accessed,
      ),
      description: json['description'] ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      ipAddress: json['ipAddress'],
      deviceInfo: json['deviceInfo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'folderId': folderId,
      'userId': userId,
      'userName': userName,
      'type': type.name,
      'description': description,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
      'ipAddress': ipAddress,
      'deviceInfo': deviceInfo,
    };
  }
}

class CollaboratorPresence {
  final String userId;
  final String userName;
  final String? userAvatar;
  final CollaboratorStatus status;
  final DateTime lastSeen;
  final String? currentLocation; // ej: "nota:123", "folder:456"
  final bool isTyping;
  final String? typingLocation; // posición en el documento
  final Color? cursorColor;

  CollaboratorPresence({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.status,
    required this.lastSeen,
    this.currentLocation,
    this.isTyping = false,
    this.typingLocation,
    this.cursorColor,
  });

  factory CollaboratorPresence.fromJson(Map<String, dynamic> json) {
    return CollaboratorPresence(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userAvatar: json['userAvatar'],
      status: CollaboratorStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CollaboratorStatus.offline,
      ),
      lastSeen: (json['lastSeen'] as Timestamp).toDate(),
      currentLocation: json['currentLocation'],
      isTyping: json['isTyping'] ?? false,
      typingLocation: json['typingLocation'],
      cursorColor: json['cursorColor'] != null
          ? Color(json['cursorColor'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'status': status.name,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'currentLocation': currentLocation,
      'isTyping': isTyping,
      'typingLocation': typingLocation,
      'cursorColor': cursorColor?.toARGB32(),
    };
  }
}

class ShareTemplate {
  final String id;
  final String name;
  final String description;
  final PermissionTemplate template;
  final SharePermission defaultPermission;
  final Duration? expirationDuration;
  final bool requireMessage;
  final bool allowPublicSharing;
  final List<String> allowedDomains;
  final Map<String, dynamic> restrictions;

  ShareTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.template,
    required this.defaultPermission,
    this.expirationDuration,
    this.requireMessage = false,
    this.allowPublicSharing = false,
    this.allowedDomains = const [],
    this.restrictions = const {},
  });

  factory ShareTemplate.fromJson(Map<String, dynamic> json) {
    return ShareTemplate(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      template: PermissionTemplate.values.firstWhere(
        (e) => e.name == json['template'],
        orElse: () => PermissionTemplate.viewer,
      ),
      defaultPermission: SharePermission.values.firstWhere(
        (e) => e.name == json['defaultPermission'],
        orElse: () => SharePermission.view,
      ),
      expirationDuration: json['expirationDurationMinutes'] != null
          ? Duration(minutes: json['expirationDurationMinutes'])
          : null,
      requireMessage: json['requireMessage'] ?? false,
      allowPublicSharing: json['allowPublicSharing'] ?? false,
      allowedDomains: List<String>.from(json['allowedDomains'] ?? []),
      restrictions: Map<String, dynamic>.from(json['restrictions'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'template': template.name,
      'defaultPermission': defaultPermission.name,
      'expirationDurationMinutes': expirationDuration?.inMinutes,
      'requireMessage': requireMessage,
      'allowPublicSharing': allowPublicSharing,
      'allowedDomains': allowedDomains,
      'restrictions': restrictions,
    };
  }
}

class SharedNote {
  final String id;
  final String noteId;
  final String title;
  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final String sharedWithId;
  final String sharedWithEmail;
  final SharePermission permission;
  final ShareStatus status;
  final DateTime sharedAt;
  final DateTime? respondedAt;
  final String? message;
  final DateTime lastModified;
  final int collaboratorCount;
  final bool isOwnerOnline;

  SharedNote({
    required this.id,
    required this.noteId,
    required this.title,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.sharedWithId,
    required this.sharedWithEmail,
    required this.permission,
    required this.status,
    required this.sharedAt,
    this.respondedAt,
    this.message,
    required this.lastModified,
    this.collaboratorCount = 1,
    this.isOwnerOnline = false,
  });

  factory SharedNote.fromJson(Map<String, dynamic> json) {
    return SharedNote(
      id: json['id'] ?? '',
      noteId: json['noteId'] ?? '',
      title: json['title'] ?? '',
      ownerId: json['ownerId'] ?? '',
      ownerName: json['ownerName'] ?? '',
      ownerEmail: json['ownerEmail'] ?? '',
      sharedWithId: json['sharedWithId'] ?? '',
      sharedWithEmail: json['sharedWithEmail'] ?? '',
      permission: SharePermission.values.firstWhere(
        (e) => e.name == json['permission'],
        orElse: () => SharePermission.view,
      ),
      status: ShareStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ShareStatus.pending,
      ),
      sharedAt: (json['sharedAt'] as Timestamp).toDate(),
      respondedAt: json['respondedAt'] != null
          ? (json['respondedAt'] as Timestamp).toDate()
          : null,
      message: json['message'],
      lastModified: (json['lastModified'] as Timestamp).toDate(),
      collaboratorCount: json['collaboratorCount'] ?? 1,
      isOwnerOnline: json['isOwnerOnline'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'title': title,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'sharedWithId': sharedWithId,
      'sharedWithEmail': sharedWithEmail,
      'permission': permission.name,
      'status': status.name,
      'sharedAt': Timestamp.fromDate(sharedAt),
      'respondedAt': respondedAt != null
          ? Timestamp.fromDate(respondedAt!)
          : null,
      'message': message,
      'lastModified': Timestamp.fromDate(lastModified),
      'collaboratorCount': collaboratorCount,
      'isOwnerOnline': isOwnerOnline,
    };
  }
}

class Collaborator {
  final String id;
  final String userId;
  final String name;
  final String email;
  final SharePermission permission;
  final ShareStatus status;
  final DateTime addedAt;
  final DateTime? lastActive;

  Collaborator({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.permission,
    required this.status,
    required this.addedAt,
    this.lastActive,
  });

  factory Collaborator.fromJson(Map<String, dynamic> json) {
    return Collaborator(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      permission: SharePermission.values.firstWhere(
        (e) => e.name == json['permission'],
        orElse: () => SharePermission.view,
      ),
      status: ShareStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ShareStatus.pending,
      ),
      addedAt: (json['addedAt'] as Timestamp).toDate(),
      lastActive: json['lastActive'] != null
          ? (json['lastActive'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'permission': permission.name,
      'status': status.name,
      'addedAt': Timestamp.fromDate(addedAt),
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
    };
  }
}

class AdvancedSharingService {
  static final AdvancedSharingService _instance =
      AdvancedSharingService._internal();
  factory AdvancedSharingService() => _instance;
  AdvancedSharingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = AuthService.instance.currentUser?.uid ?? '';

  // Obtener notas compartidas conmigo
  Future<List<SharedNote>> getSharedWithMe() async {
    try {
      // TODO: Descomentar cuando las colecciones estén configuradas
      /*
      final query = await _firestore
          .collection('shared_notes')
          .where('sharedWithId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'accepted')
          .orderBy('lastModified', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return SharedNote.fromJson(data);
      }).toList();
      */

      // Datos simulados mientras se configuran las colecciones
      return [
        SharedNote(
          id: 'shared_1',
          noteId: 'note_123',
          title: 'Proyecto de Marketing Digital - Estrategia Q4',
          ownerId: 'user_456',
          ownerName: 'Ana García',
          ownerEmail: 'ana.garcia@empresa.com',
          sharedWithId: _currentUserId,
          sharedWithEmail: AuthService.instance.currentUser?.email ?? '',
          permission: SharePermission.edit,
          status: ShareStatus.accepted,
          sharedAt: DateTime.now().subtract(Duration(days: 2)),
          lastModified: DateTime.now().subtract(Duration(hours: 3)),
          collaboratorCount: 4,
          isOwnerOnline: true,
        ),
        SharedNote(
          id: 'shared_2',
          noteId: 'note_456',
          title: 'Reunión de Ventas Q4 - Objetivos y KPIs',
          ownerId: 'user_789',
          ownerName: 'Carlos López',
          ownerEmail: 'carlos.lopez@empresa.com',
          sharedWithId: _currentUserId,
          sharedWithEmail: AuthService.instance.currentUser?.email ?? '',
          permission: SharePermission.comment,
          status: ShareStatus.accepted,
          sharedAt: DateTime.now().subtract(Duration(days: 5)),
          lastModified: DateTime.now().subtract(Duration(hours: 8)),
          collaboratorCount: 3,
          isOwnerOnline: false,
        ),
        SharedNote(
          id: 'shared_3',
          noteId: 'note_567',
          title: 'Manual de Onboarding - Nuevos Empleados',
          ownerId: 'user_999',
          ownerName: 'Roberto Díaz',
          ownerEmail: 'roberto.diaz@empresa.com',
          sharedWithId: _currentUserId,
          sharedWithEmail: AuthService.instance.currentUser?.email ?? '',
          permission: SharePermission.view,
          status: ShareStatus.accepted,
          sharedAt: DateTime.now().subtract(Duration(days: 7)),
          lastModified: DateTime.now().subtract(Duration(days: 2)),
          collaboratorCount: 6,
          isOwnerOnline: true,
        ),
        SharedNote(
          id: 'shared_4',
          noteId: 'note_678',
          title: 'Propuesta de Mejoras - Sistema de Gestión',
          ownerId: 'user_333',
          ownerName: 'María Fernández',
          ownerEmail: 'maria.fernandez@empresa.com',
          sharedWithId: _currentUserId,
          sharedWithEmail: AuthService.instance.currentUser?.email ?? '',
          permission: SharePermission.edit,
          status: ShareStatus.accepted,
          sharedAt: DateTime.now().subtract(Duration(days: 10)),
          lastModified: DateTime.now().subtract(Duration(hours: 12)),
          collaboratorCount: 2,
          isOwnerOnline: false,
        ),
        SharedNote(
          id: 'shared_5',
          noteId: 'note_789',
          title: 'Análisis de Competencia - Mercado Tech',
          ownerId: 'user_555',
          ownerName: 'Laura Martínez',
          ownerEmail: 'laura.martinez@empresa.com',
          sharedWithId: _currentUserId,
          sharedWithEmail: AuthService.instance.currentUser?.email ?? '',
          permission: SharePermission.comment,
          status: ShareStatus.accepted,
          sharedAt: DateTime.now().subtract(Duration(days: 14)),
          lastModified: DateTime.now().subtract(Duration(days: 3)),
          collaboratorCount: 5,
          isOwnerOnline: true,
        ),
      ];
    } catch (e) {
      logDebug('Error getting shared notes: $e');
      return [];
    }
  }

  // Obtener notas que he compartido
  Future<List<Map<String, dynamic>>> getSharedByMe() async {
    try {
      // TODO: Descomentar cuando las colecciones estén configuradas
      /*
      final query = await _firestore
          .collection('shared_notes')
          .where('ownerId', isEqualTo: _currentUserId)
          .orderBy('lastModified', descending: true)
          .get();

      // Agrupar por noteId para mostrar una entrada por nota
      final Map<String, List<SharedNote>> groupedByNote = {};
      
      for (final doc in query.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final sharedNote = SharedNote.fromJson(data);
        
        if (!groupedByNote.containsKey(sharedNote.noteId)) {
          groupedByNote[sharedNote.noteId] = [];
        }
        groupedByNote[sharedNote.noteId]!.add(sharedNote);
      }

      return groupedByNote.entries.map((entry) {
        final noteId = entry.key;
        final shares = entry.value;
        final firstShare = shares.first;
        
        return {
          'id': noteId,
          'title': firstShare.title,
          'collaborators': shares.map((share) => {
            'name': share.sharedWithEmail.split('@')[0],
            'email': share.sharedWithEmail,
            'permission': share.permission.name,
            'status': share.status.name,
          }).toList(),
          'lastModified': firstShare.lastModified,
          'views': shares.length * 10, // Simulado
        };
      }).toList();
      */

      // Datos simulados específicos por usuario
      // Solo mostrar datos para usuarios específicos (simular usuarios que han compartido)
      final hasSharedNotes = _simulateUserHasSharedContent(_currentUserId);

      if (!hasSharedNotes) {
        return []; // Usuario sin notas compartidas
      }

      return [
        {
          'id': 'note_001',
          'title': 'Manual de Procesos Internos - Departamento IT',
          'collaborators': [
            {
              'name': 'María Silva',
              'email': 'maria.silva@empresa.com',
              'permission': 'edit',
              'status': 'accepted',
              'lastActivity': DateTime.now().subtract(Duration(hours: 3)),
            },
            {
              'name': 'Juan Pérez',
              'email': 'juan.perez@empresa.com',
              'permission': 'comment',
              'status': 'accepted',
              'lastActivity': DateTime.now().subtract(Duration(hours: 8)),
            },
            {
              'name': 'Carmen Rodríguez',
              'email': 'carmen.rodriguez@empresa.com',
              'permission': 'view',
              'status': 'pending',
              'lastActivity': null,
            },
          ],
          'lastModified': DateTime.now().subtract(Duration(hours: 2)),
          'views': 78,
          'comments': 12,
          'versions': 5,
        },
        {
          'id': 'note_002',
          'title': 'Estrategia de Redes Sociales 2025',
          'collaborators': [
            {
              'name': 'Lucía Martínez',
              'email': 'lucia.martinez@empresa.com',
              'permission': 'edit',
              'status': 'accepted',
              'lastActivity': DateTime.now().subtract(Duration(hours: 6)),
            },
            {
              'name': 'Fernando Castro',
              'email': 'fernando.castro@empresa.com',
              'permission': 'comment',
              'status': 'accepted',
              'lastActivity': DateTime.now().subtract(Duration(days: 1)),
            },
          ],
          'lastModified': DateTime.now().subtract(Duration(hours: 12)),
          'views': 43,
          'comments': 8,
          'versions': 3,
        },
        {
          'id': 'note_003',
          'title': 'Plan de Capacitación Técnica Q1',
          'collaborators': [
            {
              'name': 'Andrea López',
              'email': 'andrea.lopez@empresa.com',
              'permission': 'edit',
              'status': 'accepted',
              'lastActivity': DateTime.now().subtract(Duration(hours: 18)),
            },
            {
              'name': 'Miguel Santos',
              'email': 'miguel.santos@empresa.com',
              'permission': 'edit',
              'status': 'accepted',
              'lastActivity': DateTime.now().subtract(Duration(days: 2)),
            },
            {
              'name': 'Isabel Morales',
              'email': 'isabel.morales@empresa.com',
              'permission': 'view',
              'status': 'accepted',
              'lastActivity': DateTime.now().subtract(Duration(days: 3)),
            },
          ],
          'lastModified': DateTime.now().subtract(Duration(days: 1)),
          'views': 67,
          'comments': 15,
          'versions': 7,
        },
        {
          'id': 'note_004',
          'title': 'Análisis de Rendimiento - Servidor Principal',
          'collaborators': [
            {
              'name': 'Roberto Díaz',
              'email': 'roberto.diaz@empresa.com',
              'permission': 'comment',
              'status': 'accepted',
              'lastActivity': DateTime.now().subtract(Duration(hours: 4)),
            },
          ],
          'lastModified': DateTime.now().subtract(Duration(hours: 6)),
          'views': 34,
          'comments': 6,
          'versions': 2,
        },
      ];
    } catch (e) {
      logDebug('Error getting shared by me: $e');
      return [];
    }
  }

  // Obtener invitaciones pendientes
  Future<List<SharedNote>> getPendingInvites() async {
    try {
      // TODO: Descomentar cuando las colecciones estén configuradas
      /*
      final query = await _firestore
          .collection('shared_notes')
          .where('sharedWithId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .orderBy('sharedAt', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return SharedNote.fromJson(data);
      }).toList();
      */

      // Datos simulados completos para demostración
      return [
        SharedNote(
          id: 'invite_1',
          noteId: 'note_789',
          title: 'Propuesta de Cliente VIP - Revisión Urgente',
          ownerId: 'user_999',
          ownerName: 'Roberto Díaz',
          ownerEmail: 'roberto.diaz@empresa.com',
          sharedWithId: '',
          sharedWithEmail: AuthService.instance.currentUser?.email ?? '',
          permission: SharePermission.comment,
          status: ShareStatus.pending,
          sharedAt: DateTime.now().subtract(Duration(hours: 2)),
          message:
              'Por favor revisa esta propuesta urgente y dame tu opinión antes de la reunión del viernes. Es para nuestro cliente más importante.',
          lastModified: DateTime.now().subtract(Duration(hours: 2)),
          collaboratorCount: 1,
          isOwnerOnline: true,
        ),
        SharedNote(
          id: 'invite_2',
          noteId: 'note_101',
          title: 'Plan de Capacitación 2025 - Colaboración Requerida',
          ownerId: 'user_888',
          ownerName: 'Sandra Morales',
          ownerEmail: 'sandra.morales@empresa.com',
          sharedWithId: '',
          sharedWithEmail: AuthService.instance.currentUser?.email ?? '',
          permission: SharePermission.edit,
          status: ShareStatus.pending,
          sharedAt: DateTime.now().subtract(Duration(hours: 8)),
          message:
              'Te invito a colaborar en el plan de capacitación para el próximo año. Necesito tu expertise en desarrollo técnico.',
          lastModified: DateTime.now().subtract(Duration(hours: 8)),
          collaboratorCount: 1,
          isOwnerOnline: false,
        ),
        SharedNote(
          id: 'invite_3',
          noteId: 'note_205',
          title: 'Estrategia de Marketing Q1 2025',
          ownerId: 'user_777',
          ownerName: 'Ana García',
          ownerEmail: 'ana.garcia@empresa.com',
          sharedWithId: '',
          sharedWithEmail: AuthService.instance.currentUser?.email ?? '',
          permission: SharePermission.view,
          status: ShareStatus.pending,
          sharedAt: DateTime.now().subtract(Duration(days: 1)),
          message:
              'Compartiendo la estrategia de marketing para el primer trimestre. Tu feedback sería muy valioso.',
          lastModified: DateTime.now().subtract(Duration(days: 1)),
          collaboratorCount: 3,
          isOwnerOnline: true,
        ),
      ];
    } catch (e) {
      logDebug('Error getting pending invites: $e');
      return [];
    }
  }

  // Compartir una nota con alguien
  Future<bool> shareNote({
    required String noteId,
    required String noteTitle,
    required String sharedWithEmail,
    required SharePermission permission,
    String? message,
  }) async {
    try {
      // Verificar si ya está compartida
      final existingQuery = await _firestore
          .collection('shared_notes')
          .where('noteId', isEqualTo: noteId)
          .where('ownerId', isEqualTo: _currentUserId)
          .where('sharedWithEmail', isEqualTo: sharedWithEmail)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        ToastService.warning('Esta nota ya está compartida con este usuario');
        return false;
      }

      // Obtener información del usuario actual
      final currentUser = AuthService.instance.currentUser!;

      // Crear el documento de compartir
      await _firestore.collection('shared_notes').add({
        'noteId': noteId,
        'title': noteTitle,
        'ownerId': _currentUserId,
        'ownerName': currentUser.email?.split('@')[0] ?? 'Usuario',
        'ownerEmail': currentUser.email ?? '',
        'sharedWithId': '', // Se llenará cuando el usuario acepte
        'sharedWithEmail': sharedWithEmail,
        'permission': permission.name,
        'status': 'pending',
        'sharedAt': Timestamp.now(),
        'message': message,
        'lastModified': Timestamp.now(),
        'collaboratorCount': 1,
        'isOwnerOnline': true,
      });

      ToastService.success('Invitación enviada correctamente');
      return true;
    } catch (e) {
      logDebug('Error sharing note: $e');
      ToastService.error('Error al compartir la nota');
      return false;
    }
  }

  // Aceptar una invitación
  Future<bool> acceptInvite(String shareId) async {
    try {
      await _firestore.collection('shared_notes').doc(shareId).update({
        'status': 'accepted',
        'respondedAt': Timestamp.now(),
        'sharedWithId': _currentUserId,
      });

      ToastService.success('Invitación aceptada');
      return true;
    } catch (e) {
      logDebug('Error accepting invite: $e');
      ToastService.error('Error al aceptar la invitación');
      return false;
    }
  }

  // Rechazar una invitación
  Future<bool> declineInvite(String shareId) async {
    try {
      await _firestore.collection('shared_notes').doc(shareId).update({
        'status': 'declined',
        'respondedAt': Timestamp.now(),
      });

      ToastService.info('Invitación rechazada');
      return true;
    } catch (e) {
      logDebug('Error declining invite: $e');
      ToastService.error('Error al rechazar la invitación');
      return false;
    }
  }

  // Cambiar permisos de un colaborador
  Future<bool> updatePermission(
    String shareId,
    SharePermission newPermission,
  ) async {
    try {
      await _firestore.collection('shared_notes').doc(shareId).update({
        'permission': newPermission.name,
        'lastModified': Timestamp.now(),
      });

      ToastService.success('Permisos actualizados');
      return true;
    } catch (e) {
      logDebug('Error updating permission: $e');
      ToastService.error('Error al actualizar permisos');
      return false;
    }
  }

  // Remover colaborador
  Future<bool> removeCollaborator(String shareId) async {
    try {
      await _firestore.collection('shared_notes').doc(shareId).delete();
      ToastService.success('Colaborador removido');
      return true;
    } catch (e) {
      logDebug('Error removing collaborator: $e');
      ToastService.error('Error al remover colaborador');
      return false;
    }
  }

  // Dejar de compartir una nota completamente
  Future<bool> stopSharing(String noteId) async {
    try {
      final query = await _firestore
          .collection('shared_notes')
          .where('noteId', isEqualTo: noteId)
          .where('ownerId', isEqualTo: _currentUserId)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      ToastService.success('Se dejó de compartir la nota');
      return true;
    } catch (e) {
      logDebug('Error stopping share: $e');
      ToastService.error('Error al dejar de compartir');
      return false;
    }
  }

  // Copiar enlace de compartir
  Future<void> copyShareLink(String noteId) async {
    try {
      final link = 'https://nootes.app/shared/$noteId';
      await Clipboard.setData(ClipboardData(text: link));
      ToastService.success('Enlace copiado al portapapeles');
    } catch (e) {
      logDebug('Error copying link: $e');
      ToastService.error('Error al copiar el enlace');
    }
  }

  // Generar enlace público
  Future<String?> generatePublicLink(String noteId) async {
    try {
      // Crear o actualizar el documento de enlace público
      final publicLinkDoc = _firestore.collection('public_links').doc(noteId);
      await publicLinkDoc.set({
        'noteId': noteId,
        'ownerId': _currentUserId,
        'createdAt': Timestamp.now(),
        'isActive': true,
        'accessCount': 0,
      });

      final link = 'https://nootes.app/public/$noteId';
      await Clipboard.setData(ClipboardData(text: link));
      ToastService.success('Enlace público generado y copiado');
      return link;
    } catch (e) {
      logDebug('Error generating public link: $e');
      ToastService.error('Error al generar enlace público');
      return null;
    }
  }

  // Obtener colaboradores de una nota
  Future<List<Collaborator>> getNoteCollaborators(String noteId) async {
    try {
      final query = await _firestore
          .collection('shared_notes')
          .where('noteId', isEqualTo: noteId)
          .where('ownerId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        return Collaborator(
          id: doc.id,
          userId: data['sharedWithId'] ?? '',
          name: data['sharedWithEmail'].split('@')[0],
          email: data['sharedWithEmail'],
          permission: SharePermission.values.firstWhere(
            (e) => e.name == data['permission'],
            orElse: () => SharePermission.view,
          ),
          status: ShareStatus.accepted,
          addedAt: (data['sharedAt'] as Timestamp).toDate(),
          lastActive: data['lastActive'] != null
              ? (data['lastActive'] as Timestamp).toDate()
              : null,
        );
      }).toList();
    } catch (e) {
      logDebug('Error getting collaborators: $e');
      return [];
    }
  }

  // === FUNCIONALIDADES ADICIONALES ===

  /// Crear notificación de compartir
  Future<void> createNotification({
    required String userId,
    required String noteId,
    String? folderId,
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic> data = const {},
    String? actionUrl,
  }) async {
    try {
      final notification = ShareNotification(
        id: _firestore.collection('notifications').doc().id,
        userId: userId,
        noteId: noteId,
        folderId: folderId,
        type: type,
        title: title,
        message: message,
        data: data,
        createdAt: DateTime.now(),
        actionUrl: actionUrl,
        fromUserId: _currentUserId,
        fromUserName: await _getCurrentUserName(),
      );

      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      logDebug('✅ Notificación creada: $title');
    } catch (e) {
      logDebug('❌ Error creando notificación: $e');
    }
  }

  /// Obtener notificaciones del usuario
  Future<List<ShareNotification>> getNotifications({
    bool? unreadOnly,
    int limit = 50,
  }) async {
    try {
      // TODO: Descomentar cuando las colecciones estén configuradas
      /*
      Query query = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (unreadOnly == true) {
        query = query.where('isRead', isEqualTo: false);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ShareNotification.fromJson({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id,
              }))
          .toList();
      */

      // Datos simulados completos para demostración
      final notifications = [
        ShareNotification(
          id: 'notif_1',
          userId: _currentUserId,
          noteId: 'note_123',
          type: NotificationType.commentAdded,
          title: 'Nuevo comentario en tu nota',
          message:
              'Ana García ha comentado en "Proyecto de Marketing Digital": "Excelente propuesta, me gusta la dirección que estamos tomando."',
          isRead: false,
          createdAt: DateTime.now().subtract(Duration(minutes: 30)),
          fromUserId: 'user_456',
          fromUserName: 'Ana García',
        ),
        ShareNotification(
          id: 'notif_2',
          userId: _currentUserId,
          noteId: 'note_456',
          type: NotificationType.noteUpdated,
          title: 'Nota colaborativa actualizada',
          message:
              'Carlos López ha editado "Reunión de Ventas Q4" - Se agregaron nuevas métricas de rendimiento',
          isRead: false,
          createdAt: DateTime.now().subtract(Duration(hours: 2)),
          fromUserId: 'user_789',
          fromUserName: 'Carlos López',
        ),
        ShareNotification(
          id: 'notif_3',
          userId: _currentUserId,
          noteId: 'note_789',
          type: NotificationType.shareInvite,
          title: 'Nueva invitación para colaborar',
          message:
              'Roberto Díaz te ha invitado a colaborar en "Propuesta de Cliente VIP"',
          isRead: false,
          createdAt: DateTime.now().subtract(Duration(hours: 3)),
          fromUserId: 'user_999',
          fromUserName: 'Roberto Díaz',
        ),
        ShareNotification(
          id: 'notif_4',
          userId: _currentUserId,
          noteId: 'note_321',
          type: NotificationType.permissionChanged,
          title: 'Permisos actualizados',
          message:
              'Tus permisos en "Plan Estratégico 2025" han sido actualizados a Editor',
          isRead: true,
          createdAt: DateTime.now().subtract(Duration(hours: 6)),
          fromUserId: 'user_555',
          fromUserName: 'María Fernández',
        ),
        ShareNotification(
          id: 'notif_5',
          userId: _currentUserId,
          noteId: 'note_654',
          type: NotificationType.collaboratorJoined,
          title: 'Nuevo colaborador',
          message:
              'Laura Martínez se ha unido a "Presentación de Ventas" como colaboradora',
          isRead: true,
          createdAt: DateTime.now().subtract(Duration(days: 1)),
          fromUserId: 'user_444',
          fromUserName: 'Laura Martínez',
        ),
        ShareNotification(
          id: 'notif_6',
          userId: _currentUserId,
          noteId: 'note_987',
          type: NotificationType.accessRevoked,
          title: 'Acceso revocado',
          message:
              'Tu acceso a "Documento Confidencial XYZ" ha sido revocado por motivos de seguridad',
          isRead: true,
          createdAt: DateTime.now().subtract(Duration(days: 2)),
          fromUserId: 'user_111',
          fromUserName: 'Administrador Sistema',
        ),
      ];

      if (unreadOnly == true) {
        return notifications.where((n) => !n.isRead).toList();
      }

      return notifications.take(limit).toList();
    } catch (e) {
      logDebug('❌ Error obteniendo notificaciones: $e');
      return [];
    }
  }

  /// Marcar notificación como leída
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      logDebug('❌ Error marcando notificación como leída: $e');
    }
  }

  /// Marcar todas las notificaciones como leídas
  Future<void> markAllNotificationsAsRead() async {
    try {
      final unreadQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadQuery.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      logDebug('❌ Error marcando todas las notificaciones como leídas: $e');
    }
  }

  /// Obtener comentarios recientes del usuario
  Future<List<NoteComment>> getRecentComments({int limit = 20}) async {
    try {
      // TODO: Descomentar cuando las colecciones estén configuradas
      /*
      final query = await _firestore
          .collection('note_comments')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return NoteComment.fromJson(data);
      }).toList();
      */

      // Datos simulados completos para demostración
      return [
        NoteComment(
          id: 'comment_1',
          noteId: 'note_123',
          userId: 'user_456',
          userName: 'Ana García',
          userAvatar: 'AG',
          content:
              'Excelente trabajo en esta sección. Me parece que deberíamos expandir el punto sobre las métricas de ROI.',
          type: CommentType.suggestion,
          createdAt: DateTime.now().subtract(Duration(minutes: 45)),
          mentions: [],
          metadata: {'noteTitle': 'Proyecto de Marketing Digital'},
          attachments: [],
          isResolved: false,
          position: 150,
          selectedText: 'métricas de rendimiento',
        ),
        NoteComment(
          id: 'comment_2',
          noteId: 'note_456',
          userId: 'user_789',
          userName: 'Carlos López',
          userAvatar: 'CL',
          content:
              '¿Podríamos agregar más detalles sobre la implementación técnica? @${AuthService.instance.currentUser?.email ?? "Usuario"}',
          type: CommentType.question,
          createdAt: DateTime.now().subtract(Duration(hours: 2)),
          mentions: [_currentUserId],
          metadata: {'noteTitle': 'Reunión de Ventas Q4'},
          attachments: [],
          isResolved: false,
          position: 89,
          selectedText: 'implementación del sistema',
        ),
        NoteComment(
          id: 'comment_3',
          noteId: 'note_789',
          userId: 'user_999',
          userName: 'Roberto Díaz',
          userAvatar: 'RD',
          content:
              'Perfecto, este enfoque está alineado con nuestros objetivos estratégicos.',
          type: CommentType.approval,
          createdAt: DateTime.now().subtract(Duration(hours: 4)),
          mentions: [],
          metadata: {'noteTitle': 'Propuesta de Cliente VIP'},
          attachments: [],
          isResolved: true,
          resolvedBy: _currentUserId,
          resolvedAt: DateTime.now().subtract(Duration(hours: 3)),
          position: 245,
        ),
        NoteComment(
          id: 'comment_4',
          noteId: 'note_321',
          userId: 'user_555',
          userName: 'María Fernández',
          userAvatar: 'MF',
          content:
              'Necesitamos revisar los números del presupuesto. Hay algunas discrepancias que debemos aclarar.',
          type: CommentType.general,
          createdAt: DateTime.now().subtract(Duration(hours: 6)),
          mentions: [],
          metadata: {'noteTitle': 'Plan Estratégico 2025'},
          attachments: ['budget_analysis.pdf'],
          isResolved: false,
          position: 320,
        ),
        NoteComment(
          id: 'comment_5',
          noteId: 'note_654',
          userId: 'user_444',
          userName: 'Laura Martínez',
          userAvatar: 'LM',
          content:
              'Excelente presentación. Solo sugiero ajustar el slide 15 para mayor claridad visual.',
          type: CommentType.suggestion,
          createdAt: DateTime.now().subtract(Duration(days: 1)),
          mentions: [],
          metadata: {'noteTitle': 'Presentación de Ventas'},
          attachments: [],
          isResolved: false,
          position: 567,
          selectedText: 'gráfico de barras',
        ),
      ];
    } catch (e) {
      logDebug('❌ Error obteniendo comentarios recientes: $e');
      return [];
    }
  }

  /// Registrar actividad
  Future<void> logActivity({
    required String noteId,
    String? folderId,
    required ActivityType type,
    required String description,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final activity = ActivityLog(
        id: _firestore.collection('activity_logs').doc().id,
        noteId: noteId,
        folderId: folderId,
        userId: _currentUserId,
        userName: await _getCurrentUserName(),
        type: type,
        description: description,
        metadata: metadata,
        timestamp: DateTime.now(),
      );

      await _firestore
          .collection('activity_logs')
          .doc(activity.id)
          .set(activity.toJson());
    } catch (e) {
      logDebug('❌ Error registrando actividad: $e');
    }
  }

  /// Obtener historial de actividad de una nota
  Future<List<ActivityLog>> getActivityHistory(
    String noteId, {
    int limit = 100,
  }) async {
    try {
      final query = await _firestore
          .collection('activity_logs')
          .where('noteId', isEqualTo: noteId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => ActivityLog.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      logDebug('❌ Error obteniendo historial de actividad: $e');
      return [];
    }
  }

  /// Actualizar presencia del colaborador
  Future<void> updateCollaboratorPresence({
    required String noteId,
    required CollaboratorStatus status,
    String? currentLocation,
    bool isTyping = false,
    String? typingLocation,
  }) async {
    try {
      final presence = CollaboratorPresence(
        userId: _currentUserId,
        userName: await _getCurrentUserName(),
        status: status,
        lastSeen: DateTime.now(),
        currentLocation: currentLocation,
        isTyping: isTyping,
        typingLocation: typingLocation,
        cursorColor: Colors.blue, // Color por defecto
      );

      await _firestore
          .collection('presence')
          .doc('${noteId}_$_currentUserId')
          .set(presence.toJson());
    } catch (e) {
      logDebug('❌ Error actualizando presencia: $e');
    }
  }

  /// Obtener presencia de colaboradores en una nota
  Stream<List<CollaboratorPresence>> getCollaboratorPresence(String noteId) {
    return _firestore
        .collection('presence')
        .where('currentLocation', isEqualTo: 'nota:$noteId')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CollaboratorPresence.fromJson(doc.data()))
              .where(
                (presence) => presence.userId != _currentUserId,
              ) // Excluir usuario actual
              .toList(),
        );
  }

  /// Crear enlace público para una nota
  Future<String?> createPublicLink({
    required String noteId,
    Duration? expiresIn,
    bool allowComments = false,
  }) async {
    try {
      final publicId = _generateUniqueId();
      final expiresAt = expiresIn != null
          ? DateTime.now().add(expiresIn)
          : null;

      await _firestore.collection('public_links').doc(publicId).set({
        'noteId': noteId,
        'ownerId': _currentUserId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'allowComments': allowComments,
        'viewCount': 0,
      });

      // Actualizar la nota con el enlace público
      await _firestore.collection('notes').doc(noteId).update({
        'isPublic': true,
        'publicId': publicId,
      });

      final baseUrl = 'https://nootes.app/public'; // URL base de tu app
      return '$baseUrl/$publicId';
    } catch (e) {
      logDebug('❌ Error creando enlace público: $e');
      return null;
    }
  }

  /// Revocar enlace público
  Future<void> revokePublicLink(String noteId) async {
    try {
      // Buscar y eliminar el enlace público
      final query = await _firestore
          .collection('public_links')
          .where('noteId', isEqualTo: noteId)
          .where('ownerId', isEqualTo: _currentUserId)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      // Actualizar la nota
      batch.update(_firestore.collection('notes').doc(noteId), {
        'isPublic': false,
        'publicId': FieldValue.delete(),
      });

      await batch.commit();
    } catch (e) {
      logDebug('❌ Error revocando enlace público: $e');
    }
  }

  /// Obtener plantillas de permisos predefinidas
  List<ShareTemplate> getDefaultTemplates() {
    return [
      ShareTemplate(
        id: 'viewer',
        name: 'Solo lectura',
        description: 'Los colaboradores pueden ver la nota pero no editarla',
        template: PermissionTemplate.viewer,
        defaultPermission: SharePermission.view,
      ),
      ShareTemplate(
        id: 'commenter',
        name: 'Comentarista',
        description: 'Los colaboradores pueden ver y comentar la nota',
        template: PermissionTemplate.commenter,
        defaultPermission: SharePermission.comment,
      ),
      ShareTemplate(
        id: 'editor',
        name: 'Editor completo',
        description: 'Los colaboradores pueden ver, comentar y editar la nota',
        template: PermissionTemplate.editor,
        defaultPermission: SharePermission.edit,
      ),
      ShareTemplate(
        id: 'temp_24h',
        name: 'Acceso temporal (24h)',
        description: 'Acceso de solo lectura que expira en 24 horas',
        template: PermissionTemplate.viewer,
        defaultPermission: SharePermission.view,
        expirationDuration: Duration(hours: 24),
      ),
      ShareTemplate(
        id: 'temp_7d',
        name: 'Acceso semanal',
        description: 'Acceso de edición que expira en 7 días',
        template: PermissionTemplate.editor,
        defaultPermission: SharePermission.edit,
        expirationDuration: Duration(days: 7),
      ),
    ];
  }

  /// Compartir usando una plantilla
  Future<bool> shareWithTemplate({
    required String noteId,
    required String noteTitle,
    required String email,
    required ShareTemplate template,
    String? customMessage,
  }) async {
    try {
      final message =
          customMessage ??
          'Te han compartido una nota usando la plantilla "${template.name}"';

      return await shareNote(
        noteId: noteId,
        noteTitle: noteTitle,
        sharedWithEmail: email,
        permission: template.defaultPermission,
        message: message,
      );
    } catch (e) {
      logDebug('❌ Error compartiendo con plantilla: $e');
      return false;
    }
  }

  /// Obtener estadísticas de compartir
  Future<Map<String, dynamic>> getSharingStats() async {
    try {
      // Notas compartidas por mí
      final sharedByMeQuery = await _firestore
          .collection('shared_notes')
          .where('ownerId', isEqualTo: _currentUserId)
          .get();

      // Notas compartidas conmigo
      final sharedWithMeQuery = await _firestore
          .collection('shared_notes')
          .where('sharedWithId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      // Colaboradores únicos
      final collaborators = <String>{};
      for (final doc in sharedByMeQuery.docs) {
        collaborators.add(doc.data()['sharedWithId']);
      }
      for (final doc in sharedWithMeQuery.docs) {
        collaborators.add(doc.data()['ownerId']);
      }

      return {
        'notesSharedByMe': sharedByMeQuery.docs.length,
        'notesSharedWithMe': sharedWithMeQuery.docs.length,
        'totalCollaborators': collaborators.length,
        'pendingInvites': sharedByMeQuery.docs
            .where((doc) => doc.data()['status'] == 'pending')
            .length,
      };
    } catch (e) {
      logDebug('❌ Error obteniendo estadísticas: $e');
      return {};
    }
  }

  /// Obtener nombre del usuario actual
  Future<String> _getCurrentUserName() async {
    try {
      final user = AuthService.instance.currentUser;
      return user?.email?.split('@')[0] ?? 'Usuario';
    } catch (e) {
      return 'Usuario';
    }
  }

  /// Generar ID único
  String _generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (1000 + DateTime.now().microsecond % 9000).toString();
  }

  // === SISTEMA DE COMENTARIOS ===

  /// Añadir comentario a una nota
  Future<String?> addComment({
    required String noteId,
    required String content,
    CommentType type = CommentType.general,
    String? parentId,
    List<String> mentions = const [],
    int position = 0,
    String? selectedText,
  }) async {
    try {
      final commentId = _generateUniqueId();
      final currentUser = AuthService.instance.currentUser!;

      final comment = NoteComment(
        id: commentId,
        noteId: noteId,
        userId: currentUser.uid,
        userName: await _getCurrentUserName(),
        userAvatar: '', // En una implementación real, obtener del perfil
        content: content,
        type: type,
        createdAt: DateTime.now(),
        mentions: mentions,
        position: position,
        selectedText: selectedText,
      );

      await _firestore
          .collection('note_comments')
          .doc(commentId)
          .set(comment.toJson());

      // Notificar a los mencionados
      for (final mention in mentions) {
        await createNotification(
          userId: mention,
          noteId: noteId,
          type: NotificationType.commentAdded,
          title: 'Te han mencionado en un comentario',
          message: content.length > 100
              ? '${content.substring(0, 100)}...'
              : content,
          data: {'commentId': commentId},
        );
      }

      return commentId;
    } catch (e) {
      logDebug('❌ Error añadiendo comentario: $e');
      return null;
    }
  }

  /// Obtener comentarios de una nota
  Stream<List<NoteComment>> getComments(String noteId) {
    return _firestore
        .collection('note_comments')
        .where('noteId', isEqualTo: noteId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NoteComment.fromJson({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  /// Resolver comentario
  Future<void> resolveComment(String commentId) async {
    try {
      await _firestore.collection('note_comments').doc(commentId).update({
        'isResolved': true,
        'resolvedBy': _currentUserId,
        'resolvedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      logDebug('❌ Error resolviendo comentario: $e');
    }
  }

  /// Responder a comentario
  Future<String?> replyToComment({
    required String parentCommentId,
    required String noteId,
    required String content,
    List<String> mentions = const [],
  }) async {
    return await addComment(
      noteId: noteId,
      content: content,
      parentId: parentCommentId,
      mentions: mentions,
      type: CommentType.general,
    );
  }

  // === SISTEMA DE VERSIONADO ===

  /// Crear nueva versión de nota
  Future<String?> createVersion({
    required String noteId,
    required String title,
    required String content,
    required String changesSummary,
    VersionAction action = VersionAction.edited,
    bool isMinor = false,
    Map<String, dynamic> changes = const {},
    List<String> tags = const [],
  }) async {
    try {
      final versionId = _generateUniqueId();
      final currentUser = AuthService.instance.currentUser!;

      // Obtener versión anterior para referencias
      final previousVersionQuery = await _firestore
          .collection('note_versions')
          .where('noteId', isEqualTo: noteId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      final previousVersionId = previousVersionQuery.docs.isNotEmpty
          ? previousVersionQuery.docs.first.id
          : null;

      final version = NoteVersion(
        id: versionId,
        noteId: noteId,
        title: title,
        content: content,
        authorId: currentUser.uid,
        authorName: await _getCurrentUserName(),
        createdAt: DateTime.now(),
        action: action,
        previousVersionId: previousVersionId,
        changes: changes,
        changesSummary: changesSummary,
        isMinor: isMinor,
        tags: tags,
      );

      await _firestore
          .collection('note_versions')
          .doc(versionId)
          .set(version.toJson());

      // Registrar actividad
      await logActivity(
        noteId: noteId,
        type: ActivityType.edited,
        description: 'Nueva versión: $changesSummary',
        metadata: {
          'versionId': versionId,
          'isMinor': isMinor,
          'action': action.name,
        },
      );

      return versionId;
    } catch (e) {
      logDebug('❌ Error creando versión: $e');
      return null;
    }
  }

  /// Obtener historial de versiones
  Future<List<NoteVersion>> getVersionHistory(
    String noteId, {
    int limit = 50,
  }) async {
    try {
      final query = await _firestore
          .collection('note_versions')
          .where('noteId', isEqualTo: noteId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => NoteVersion.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      logDebug('❌ Error obteniendo historial: $e');
      return [];
    }
  }

  /// Restaurar versión anterior
  Future<bool> restoreVersion(String versionId, String noteId) async {
    try {
      final versionDoc = await _firestore
          .collection('note_versions')
          .doc(versionId)
          .get();

      if (!versionDoc.exists) return false;

      final version = NoteVersion.fromJson({
        ...versionDoc.data()!,
        'id': versionDoc.id,
      });

      // Actualizar la nota actual
      await _firestore.collection('notes').doc(noteId).update({
        'title': version.title,
        'content': version.content,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Crear nueva versión con la restauración
      await createVersion(
        noteId: noteId,
        title: version.title,
        content: version.content,
        changesSummary:
            'Restaurado a versión del ${version.createdAt.day}/${version.createdAt.month}',
        action: VersionAction.restored,
        changes: {'restoredFromVersion': versionId},
      );

      return true;
    } catch (e) {
      logDebug('❌ Error restaurando versión: $e');
      return false;
    }
  }

  // === SISTEMA DE APROBACIONES ===

  /// Crear solicitud de aprobación
  Future<String?> createApprovalRequest({
    required String noteId,
    required String noteTitle,
    required List<String> approverIds,
    required String description,
    DateTime? deadline,
    bool requiresAllApprovals = false,
    String? currentVersionId,
  }) async {
    try {
      final requestId = _generateUniqueId();
      final currentUser = AuthService.instance.currentUser!;

      final request = ApprovalRequest(
        id: requestId,
        noteId: noteId,
        noteTitle: noteTitle,
        requesterId: currentUser.uid,
        requesterName: await _getCurrentUserName(),
        approverIds: approverIds,
        status: ApprovalStatus.pending,
        description: description,
        createdAt: DateTime.now(),
        deadline: deadline,
        requiresAllApprovals: requiresAllApprovals,
        currentVersionId: currentVersionId,
      );

      await _firestore
          .collection('approval_requests')
          .doc(requestId)
          .set(request.toJson());

      // Notificar a los aprobadores
      for (final approverId in approverIds) {
        await createNotification(
          userId: approverId,
          noteId: noteId,
          type: NotificationType.shareInvite, // Reutilizar para aprobaciones
          title: 'Solicitud de aprobación',
          message: 'Necesitas aprobar: $noteTitle',
          data: {
            'requestId': requestId,
            'deadline': deadline?.toIso8601String(),
          },
        );
      }

      return requestId;
    } catch (e) {
      logDebug('❌ Error creando solicitud de aprobación: $e');
      return null;
    }
  }

  /// Aprobar/Rechazar solicitud
  Future<bool> respondToApproval({
    required String requestId,
    required ApprovalStatus response,
    String? comment,
  }) async {
    try {
      final currentUser = AuthService.instance.currentUser!;

      await _firestore.collection('approval_requests').doc(requestId).update({
        'approvals.${currentUser.uid}': response.name,
        'comments.${currentUser.uid}': comment ?? '',
        'timestamps.${currentUser.uid}': Timestamp.fromDate(DateTime.now()),
      });

      // Verificar si todas las aprobaciones están completas
      final requestDoc = await _firestore
          .collection('approval_requests')
          .doc(requestId)
          .get();

      if (requestDoc.exists) {
        final request = ApprovalRequest.fromJson({
          ...requestDoc.data()!,
          'id': requestDoc.id,
        });

        final allResponded = request.approverIds.every(
          (id) => request.approvals.containsKey(id),
        );

        if (allResponded) {
          ApprovalStatus finalStatus;
          if (request.requiresAllApprovals) {
            finalStatus =
                request.approvals.values.every(
                  (status) => status == ApprovalStatus.approved,
                )
                ? ApprovalStatus.approved
                : ApprovalStatus.rejected;
          } else {
            finalStatus =
                request.approvals.values.any(
                  (status) => status == ApprovalStatus.approved,
                )
                ? ApprovalStatus.approved
                : ApprovalStatus.rejected;
          }

          await _firestore
              .collection('approval_requests')
              .doc(requestId)
              .update({'status': finalStatus.name});

          // Notificar al solicitante
          await createNotification(
            userId: request.requesterId,
            noteId: request.noteId,
            type: NotificationType.permissionChanged,
            title: finalStatus == ApprovalStatus.approved
                ? 'Aprobación concedida'
                : 'Aprobación denegada',
            message:
                'Tu solicitud para "${request.noteTitle}" ha sido ${finalStatus.name}',
            data: {'requestId': requestId},
          );
        }
      }

      return true;
    } catch (e) {
      logDebug('❌ Error respondiendo a aprobación: $e');
      return false;
    }
  }

  /// Obtener solicitudes de aprobación pendientes
  Future<List<ApprovalRequest>> getPendingApprovals() async {
    try {
      // TODO: Descomentar cuando las colecciones estén configuradas
      /*
      final query = await _firestore
          .collection('approval_requests')
          .where('approverIds', arrayContains: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => ApprovalRequest.fromJson({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList();
      */

      // Datos simulados completos para demostración
      return [
        ApprovalRequest(
          id: 'approval_1',
          noteId: 'note_555',
          noteTitle: 'Política de Trabajo Remoto - Actualización 2025',
          requesterId: 'user_777',
          requesterName: 'Fernando Castro',
          approverIds: [_currentUserId, 'user_888', 'user_999'],
          status: ApprovalStatus.pending,
          description:
              'Necesito aprobación urgente para publicar la nueva política de trabajo remoto. Incluye cambios importantes en horarios flexibles y nuevas herramientas de colaboración.',
          createdAt: DateTime.now().subtract(Duration(hours: 2)),
          deadline: DateTime.now().add(Duration(days: 2)),
          requiresAllApprovals: true,
        ),
        ApprovalRequest(
          id: 'approval_2',
          noteId: 'note_666',
          noteTitle: 'Presupuesto Q1 2025 - Departamento de Marketing',
          requesterId: 'user_999',
          requesterName: 'Mónica Herrera',
          approverIds: [_currentUserId, 'user_111'],
          status: ApprovalStatus.pending,
          description:
              'Solicito aprobación del presupuesto para el primer trimestre. Total solicitado: \$150,000 USD para campañas digitales y eventos.',
          createdAt: DateTime.now().subtract(Duration(hours: 8)),
          deadline: DateTime.now().add(Duration(days: 5)),
          requiresAllApprovals: false,
        ),
        ApprovalRequest(
          id: 'approval_3',
          noteId: 'note_777',
          noteTitle: 'Contrato de Servicios - Proveedor TI',
          requesterId: 'user_555',
          requesterName: 'Ricardo Mendoza',
          approverIds: [_currentUserId],
          status: ApprovalStatus.pending,
          description:
              'Contrato anual con nuevo proveedor de servicios de TI. Requiere aprobación legal y financiera antes del 15 de octubre.',
          createdAt: DateTime.now().subtract(Duration(days: 1)),
          deadline: DateTime.now().add(Duration(days: 4)),
          requiresAllApprovals: false,
        ),
        ApprovalRequest(
          id: 'approval_4',
          noteId: 'note_888',
          noteTitle: 'Manual de Procedimientos de Seguridad',
          requesterId: 'user_333',
          requesterName: 'Carmen Silva',
          approverIds: [_currentUserId, 'user_444'],
          status: ApprovalStatus.needsRevision,
          description:
              'Manual actualizado de procedimientos de seguridad. Requiere revisión de las secciones 3.2 y 4.1 según comentarios anteriores.',
          createdAt: DateTime.now().subtract(Duration(days: 3)),
          deadline: DateTime.now().add(Duration(days: 7)),
          requiresAllApprovals: true,
        ),
      ];
    } catch (e) {
      logDebug('❌ Error obteniendo aprobaciones pendientes: $e');
      return [];
    }
  }

  // === SISTEMA DE CALENDARIO ===

  /// Crear evento de calendario
  Future<String?> createCalendarEvent({
    required String noteId,
    required String noteTitle,
    required String title,
    required String description,
    required CalendarEventType type,
    required DateTime startTime,
    DateTime? endTime,
    List<String> attendeeIds = const [],
    bool isAllDay = false,
    String? location,
    List<String> reminders = const [],
  }) async {
    try {
      final eventId = _generateUniqueId();

      // Obtener nombres de los asistentes
      final attendeeNames = <String, String>{};
      for (final attendeeId in attendeeIds) {
        // En una implementación real, obtener nombres de los usuarios
        attendeeNames[attendeeId] = 'Usuario $attendeeId';
      }

      final event = CalendarEvent(
        id: eventId,
        noteId: noteId,
        noteTitle: noteTitle,
        title: title,
        description: description,
        type: type,
        startTime: startTime,
        endTime: endTime,
        attendeeIds: attendeeIds,
        attendeeNames: attendeeNames,
        createdBy: _currentUserId,
        createdAt: DateTime.now(),
        isAllDay: isAllDay,
        location: location,
        reminders: reminders,
      );

      await _firestore
          .collection('calendar_events')
          .doc(eventId)
          .set(event.toJson());

      // Notificar a los asistentes
      for (final attendeeId in attendeeIds) {
        await createNotification(
          userId: attendeeId,
          noteId: noteId,
          type: NotificationType.shareInvite, // Reutilizar para eventos
          title: 'Nuevo evento: $title',
          message:
              'Tienes un evento programado para ${startTime.day}/${startTime.month}',
          data: {'eventId': eventId, 'startTime': startTime.toIso8601String()},
        );
      }

      return eventId;
    } catch (e) {
      logDebug('❌ Error creando evento: $e');
      return null;
    }
  }

  /// Obtener eventos del calendario para un rango de fechas
  Future<List<CalendarEvent>> getCalendarEvents({
    DateTime? startDate,
    DateTime? endDate,
    String? noteId,
  }) async {
    try {
      // TODO: Descomentar cuando las colecciones estén configuradas
      /*
      Query query = _firestore.collection('calendar_events');
      
      if (noteId != null) {
        query = query.where('noteId', isEqualTo: noteId);
      }
      
      // Filtrar por usuario (creador o asistente)
      query = query.where('attendeeIds', arrayContains: _currentUserId);
      
      if (startDate != null) {
        query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.orderBy('startTime').get();
      return snapshot.docs
          .map((doc) => CalendarEvent.fromJson({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id,
              }))
          .toList();
      */

      // Datos simulados mientras se configuran las colecciones
      final now = DateTime.now();
      return [
        CalendarEvent(
          id: 'event_1',
          noteId: 'note_123',
          noteTitle: 'Proyecto de Marketing Digital',
          title: 'Revisión de Progreso',
          description: 'Reunión semanal para revisar el avance del proyecto',
          type: CalendarEventType.meeting,
          startTime: now.add(Duration(days: 2, hours: 10)),
          endTime: now.add(Duration(days: 2, hours: 11)),
          attendeeIds: [_currentUserId, 'user_456'],
          attendeeNames: {_currentUserId: 'Tú', 'user_456': 'Ana García'},
          createdBy: 'user_456',
          createdAt: now.subtract(Duration(days: 1)),
          location: 'Sala de Juntas A',
          reminders: ['15', '60'],
        ),
        CalendarEvent(
          id: 'event_2',
          noteId: 'note_456',
          noteTitle: 'Reunión de Ventas Q4',
          title: 'Fecha límite de presentación',
          description: 'Deadline para entregar la presentación final',
          type: CalendarEventType.deadline,
          startTime: now.add(Duration(days: 5)),
          attendeeIds: [_currentUserId],
          attendeeNames: {_currentUserId: 'Tú'},
          createdBy: _currentUserId,
          createdAt: now.subtract(Duration(hours: 2)),
          isAllDay: true,
          reminders: ['1440', '120'],
        ),
      ];
    } catch (e) {
      logDebug('❌ Error obteniendo eventos: $e');
      return [];
    }
  }

  /// Simular si un usuario tiene contenido compartido (para datos de prueba)
  bool _simulateUserHasSharedContent(String userId) {
    // Lista de usuarios que simulamos que tienen notas compartidas
    final usersWithSharedContent = [
      'demo@nootes.com',
      'admin@nootes.com',
      'test@example.com',
      'user@demo.com',
    ];

    return usersWithSharedContent.contains(userId);
  }

  /// Editar un evento del calendario existente
  Future<bool> updateCalendarEvent({
    required String eventId,
    required String title,
    required String description,
    required CalendarEventType type,
    required DateTime startTime,
    DateTime? endTime,
    required List<String> attendeeIds,
    String? location,
    bool isAllDay = false,
    List<String> reminders = const [],
  }) async {
    try {
      // TODO: Descomentar cuando las colecciones estén configuradas
      /*
      final eventData = {
        'title': title,
        'description': description,
        'type': type.name,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': endTime != null ? Timestamp.fromDate(endTime) : null,
        'attendeeIds': attendeeIds,
        'location': location,
        'isAllDay': isAllDay,
        'reminders': reminders,
        'lastModified': Timestamp.now(),
      };

      await _firestore
          .collection('calendar_events')
          .doc(eventId)
          .update(eventData);
      */

      // Simulación de actualización exitosa
      logDebug('✅ Evento actualizado: $title');
      return true;
    } catch (e) {
      logDebug('❌ Error actualizando evento: $e');
      return false;
    }
  }

  /// Eliminar un evento del calendario
  Future<bool> deleteCalendarEvent(String eventId) async {
    try {
      // TODO: Descomentar cuando las colecciones estén configuradas
      /*
      await _firestore
          .collection('calendar_events')
          .doc(eventId)
          .delete();
      */

      // Simulación de eliminación exitosa
      logDebug('✅ Evento eliminado: $eventId');
      return true;
    } catch (e) {
      logDebug('❌ Error eliminando evento: $e');
      return false;
    }
  }

  /// Programar recordatorio automático
  Future<void> scheduleReminder({
    required String noteId,
    required String title,
    required DateTime reminderTime,
    String? message,
  }) async {
    try {
      await createCalendarEvent(
        noteId: noteId,
        noteTitle: title,
        title: 'Recordatorio: $title',
        description: message ?? 'Recordatorio automático',
        type: CalendarEventType.reminder,
        startTime: reminderTime,
        attendeeIds: [_currentUserId],
        reminders: ['0'], // Recordatorio en el momento exacto
      );
    } catch (e) {
      logDebug('❌ Error programando recordatorio: $e');
    }
  }

  // === ANALYTICS Y REPORTES ===

  /// Obtener analytics de colaboración
  Future<Map<String, dynamic>> getCollaborationAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Actividad por día
      final activityQuery = await _firestore
          .collection('activity_logs')
          .where('userId', isEqualTo: _currentUserId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final activityByDay = <String, int>{};
      final activityByType = <String, int>{};

      for (final doc in activityQuery.docs) {
        final activity = ActivityLog.fromJson({...doc.data(), 'id': doc.id});
        final day = '${activity.timestamp.day}/${activity.timestamp.month}';

        activityByDay[day] = (activityByDay[day] ?? 0) + 1;
        activityByType[activity.type.name] =
            (activityByType[activity.type.name] ?? 0) + 1;
      }

      // Comentarios por nota
      final commentsQuery = await _firestore
          .collection('note_comments')
          .where('userId', isEqualTo: _currentUserId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final commentsByNote = <String, int>{};
      for (final doc in commentsQuery.docs) {
        final comment = NoteComment.fromJson({...doc.data(), 'id': doc.id});
        commentsByNote[comment.noteId] =
            (commentsByNote[comment.noteId] ?? 0) + 1;
      }

      return {
        'activityByDay': activityByDay,
        'activityByType': activityByType,
        'commentsByNote': commentsByNote,
        'totalActivities': activityQuery.docs.length,
        'totalComments': commentsQuery.docs.length,
        'periodStart': start.toIso8601String(),
        'periodEnd': end.toIso8601String(),
      };
    } catch (e) {
      logDebug('❌ Error obteniendo analytics: $e');
      return {};
    }
  }

  /// Generar reporte de colaboración
  Future<Map<String, dynamic>> generateCollaborationReport(
    String noteId,
  ) async {
    try {
      final futures = await Future.wait([
        getVersionHistory(noteId),
        getActivityHistory(noteId),
        getNoteCollaborators(noteId),
      ]);

      final versions = futures[0] as List<NoteVersion>;
      final activities = futures[1] as List<ActivityLog>;
      final collaborators = futures[2] as List<Collaborator>;

      // Obtener comentarios
      final commentsSnapshot = await _firestore
          .collection('note_comments')
          .where('noteId', isEqualTo: noteId)
          .get();

      final comments = commentsSnapshot.docs
          .map((doc) => NoteComment.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Estadísticas por colaborador
      final collaboratorStats = <String, Map<String, dynamic>>{};

      for (final collaborator in collaborators) {
        final userActivities = activities
            .where((a) => a.userId == collaborator.userId)
            .length;
        final userComments = comments
            .where((c) => c.userId == collaborator.userId)
            .length;
        final userVersions = versions
            .where((v) => v.authorId == collaborator.userId)
            .length;

        collaboratorStats[collaborator.userId] = {
          'name': collaborator.name,
          'email': collaborator.email,
          'activities': userActivities,
          'comments': userComments,
          'versions': userVersions,
          'lastActive': collaborator.lastActive?.toIso8601String(),
        };
      }

      return {
        'noteId': noteId,
        'generatedAt': DateTime.now().toIso8601String(),
        'collaboratorStats': collaboratorStats,
        'totalVersions': versions.length,
        'totalActivities': activities.length,
        'totalComments': comments.length,
        'totalCollaborators': collaborators.length,
        'timeline': activities
            .map(
              (a) => {
                'timestamp': a.timestamp.toIso8601String(),
                'type': a.type.name,
                'user': a.userName,
                'description': a.description,
              },
            )
            .toList(),
      };
    } catch (e) {
      logDebug('❌ Error generando reporte: $e');
      return {};
    }
  }
}
