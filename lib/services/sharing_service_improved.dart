import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nootes/services/auth_service.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/field_timestamp_helper.dart';
import 'package:nootes/services/logging_service.dart';
import 'package:nootes/services/notification_service.dart';
import 'package:nootes/services/exceptions/sharing_exceptions.dart';
import 'dart:math';

/// Estados de una nota/carpeta compartida
enum SharingStatus {
  /// Pendiente de aceptación por parte del receptor
  pending,

  /// Aceptada por el receptor - el contenido está siendo compartido activamente
  accepted,

  /// Rechazada por el receptor - el receptor declinó la invitación
  rejected,

  /// Revocada por el propietario - el propietario canceló la compartición
  revoked,

  /// El receptor se salió voluntariamente de la compartición
  left,
}

/// Tipos de elementos que se pueden compartir
enum SharedItemType {
  /// Nota individual
  note,

  /// Carpeta con sus notas
  folder,

  /// Colección con sus notas
  collection,
}

/// Niveles de permisos para elementos compartidos
enum PermissionLevel {
  /// Solo lectura - puede ver el contenido pero no modificarlo
  read,

  /// Lectura y comentarios - puede ver y comentar pero no editar
  comment,

  /// Lectura y edición - puede ver, comentar y editar el contenido
  edit,
}

/// Configuración para operaciones de compartición
class SharingConfig {
  const SharingConfig({
    this.enableNotifications = true,
    this.enablePresenceTracking = true,
    this.defaultPermission = PermissionLevel.read,
    this.enableComments = true,
    this.maxSharesPerItem = 50,
    this.defaultExpirationDays,
  });

  final bool enableNotifications;
  final bool enablePresenceTracking;
  final PermissionLevel defaultPermission;
  final bool enableComments;
  final int maxSharesPerItem;
  final int? defaultExpirationDays;
}

/// Resultado de operaciones de compartición con información adicional
class SharingResult<T> {
  const SharingResult({
    required this.success,
    this.data,
    this.error,
    this.metadata,
  });

  final bool success;
  final T? data;
  final String? error;
  final Map<String, dynamic>? metadata;

  /// Fábrica para resultados exitosos
  factory SharingResult.success(T data, {Map<String, dynamic>? metadata}) {
    return SharingResult(success: true, data: data, metadata: metadata);
  }

  /// Fábrica para resultados con error
  factory SharingResult.error(String error, {Map<String, dynamic>? metadata}) {
    return SharingResult(success: false, error: error, metadata: metadata);
  }
}

/// Modelo para elementos compartidos con validación y métodos auxiliares
class SharedItem {
  const SharedItem({
    required this.id,
    required this.itemId,
    required this.type,
    required this.ownerId,
    required this.ownerEmail,
    required this.recipientId,
    required this.recipientEmail,
    required this.permission,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.message,
    this.metadata,
  });

  final String id;
  final String itemId;
  final SharedItemType type;
  final String ownerId;
  final String ownerEmail;
  final String recipientId;
  final String recipientEmail;
  final PermissionLevel permission;
  final SharingStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final String? message;
  final Map<String, dynamic>? metadata;

  /// Verifica si la compartición ha expirado
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Verifica si la compartición está activa (accepted y no expirada)
  bool get isActive => status == SharingStatus.accepted && !isExpired;

  /// Verifica si la compartición está en un estado terminal
  bool get isTerminal {
    return status == SharingStatus.revoked ||
        status == SharingStatus.left ||
        status == SharingStatus.rejected ||
        isExpired;
  }

  /// Días restantes hasta la expiración
  int? get daysUntilExpiration {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return 0;
    final diff = expiresAt!.difference(now);
    final wholeDays = diff.inDays;
    // If there's any remaining partial day, count it as a full day.
    if (diff - Duration(days: wholeDays) > Duration.zero) {
      return wholeDays + 1;
    }
    return wholeDays;
  }

  /// Obtiene el título del elemento desde metadata
  String get itemTitle {
    return metadata?['noteTitle'] ??
        metadata?['folderName'] ??
        metadata?['collectionName'] ??
        'Sin título';
  }

  /// Obtiene el nombre del propietario desde metadata
  String get ownerName {
    return metadata?['ownerName'] ?? ownerEmail.split('@').first;
  }

  /// Crea una instancia desde un documento de Firestore
  factory SharedItem.fromMap(String id, Map<String, dynamic> data) {
    try {
      return SharedItem(
        id: id,
        itemId: _validateString(data['itemId'], 'itemId'),
        type: SharedItemType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => throw ValidationException(
            'type',
            'Tipo de compartición inválido',
          ),
        ),
        ownerId: _validateString(data['ownerId'], 'ownerId'),
        ownerEmail: _validateString(data['ownerEmail'], 'ownerEmail'),
        recipientId: _validateString(data['recipientId'], 'recipientId'),
        recipientEmail: _validateString(
          data['recipientEmail'],
          'recipientEmail',
        ),
        permission: PermissionLevel.values.firstWhere(
          (e) => e.name == data['permission'],
          orElse: () => throw ValidationException(
            'permission',
            'Nivel de permiso inválido',
          ),
        ),
        status: SharingStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => throw ValidationException(
            'status',
            'Estado de compartición inválido',
          ),
        ),
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
        message: data['message'] as String?,
        metadata: data['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      LoggingService.error(
        'Error parsing SharedItem from Firestore data',
        tag: 'SharedItem',
        data: {'id': id, 'rawData': data},
        error: e,
      );
      rethrow;
    }
  }

  /// Valida que un campo string no esté vacío
  static String _validateString(dynamic value, String fieldName) {
    if (value == null || value.toString().isEmpty) {
      throw ValidationException(
        fieldName,
        'Campo $fieldName no puede estar vacío',
      );
    }
    return value.toString();
  }

  /// Convierte la instancia a un mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'type': type.name,
      'ownerId': ownerId,
      'ownerEmail': ownerEmail,
      'recipientId': recipientId,
      'recipientEmail': recipientEmail,
      'permission': permission.name,
      'status': status.name,
      'createdAt': fs.FieldValue.serverTimestamp(),
      'updatedAt': fs.FieldValue.serverTimestamp(),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'message': message,
      'metadata': metadata,
    };
  }

  /// Crea una copia con campos modificados
  SharedItem copyWith({
    String? id,
    String? itemId,
    SharedItemType? type,
    String? ownerId,
    String? ownerEmail,
    String? recipientId,
    String? recipientEmail,
    PermissionLevel? permission,
    SharingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    return SharedItem(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      type: type ?? this.type,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      recipientId: recipientId ?? this.recipientId,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      permission: permission ?? this.permission,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      message: message ?? this.message,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Clase para cachear resultados y mejorar el rendimiento
class _SharingCache {
  static final Map<String, Map<String, dynamic>> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  static T? get<T>(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null ||
        DateTime.now().difference(timestamp) > _cacheExpiry) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }
    return _cache[key]?['data'] as T?;
  }

  static void set<T>(String key, T data) {
    _cache[key] = {'data': data};
    _cacheTimestamps[key] = DateTime.now();
  }

  static void clear([String? key]) {
    if (key != null) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    } else {
      _cache.clear();
      _cacheTimestamps.clear();
    }
  }
}

/// Servicio principal para manejar el sistema de compartir notas y carpetas
///
/// Este servicio maneja todas las operaciones relacionadas con compartir contenido:
/// - Compartir notas y carpetas con otros usuarios
/// - Gestionar permisos y estados de compartición
/// - Enlaces públicos para compartir de forma abierta
/// - Notificaciones automáticas
/// - Caché para mejorar rendimiento
class SharingService {
  static final SharingService _instance = SharingService._internal();
  static SharingService? _testOverride;

  /// Factory returns a test override when provided (tests can set via `testInstance`).
  factory SharingService() => _testOverride ?? _instance;
  SharingService._internal();

  /// Testing helper: set a fake instance for tests.
  static set testInstance(SharingService? v) => _testOverride = v;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;
  SharingConfig _config = const SharingConfig();

  /// Configuración actual del servicio
  SharingConfig get config => _config;

  /// Actualizar configuración del servicio
  void updateConfig(SharingConfig newConfig) {
    _config = newConfig;
    LoggingService.info(
      'SharingService configuration updated',
      tag: 'SharingService',
    );
  }

  /// UID del usuario autenticado
  String get currentUserId {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      throw const AuthenticationException();
    }
    return uid;
  }

  /// Email del usuario autenticado
  String get currentUserEmail {
    final email = _authService.currentUser?.email;
    if (email == null) {
      throw const AuthenticationException(
        'No se pudo obtener el email del usuario',
      );
    }
    return email;
  }

  // =====================================================================
  // GESTIÓN DE COMPARTICIONES POR ELEMENTO
  // =====================================================================

  /// Obtiene todas las comparticiones para un elemento específico
  ///
  /// [itemId]: ID del elemento (nota, carpeta, colección)
  /// [type]: Tipo del elemento que se está compartiendo
  /// [ownerId]: ID del propietario (opcional, usa el usuario actual si no se especifica)
  /// [includeInactive]: Si incluir comparticiones inactivas (revocadas, rechazadas, etc.)
  ///
  /// Retorna una lista de [SharedItem] asociados al elemento
  Future<List<SharedItem>> getSharingsForItem({
    required String itemId,
    required SharedItemType type,
    String? ownerId,
    bool includeInactive = false,
  }) async {
    try {
      LoggingService.debug(
        'Getting sharings for item',
        tag: 'SharingService',
        data: {'itemId': itemId, 'type': type.name, 'ownerId': ownerId},
      );

      final uid = ownerId ?? currentUserId;
      final cacheKey =
          'sharings_${uid}_${itemId}_${type.name}_$includeInactive';

      // Verificar caché primero
      final cached = _SharingCache.get<List<SharedItem>>(cacheKey);
      if (cached != null) {
        LoggingService.debug(
          'Returning cached sharings',
          tag: 'SharingService',
        );
        return cached;
      }

      Query query = _firestore
          .collection('shared_items')
          .where('itemId', isEqualTo: itemId)
          .where('type', isEqualTo: type.name)
          .where('ownerId', isEqualTo: uid);

      if (!includeInactive) {
        query = query.where(
          'status',
          whereIn: [SharingStatus.pending.name, SharingStatus.accepted.name],
        );
      }

      final querySnapshot = await query.get();
      final items = querySnapshot.docs
          .map(
            (doc) =>
                SharedItem.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .where((item) => includeInactive || !item.isExpired)
          .toList();

      // Guardar en caché
      _SharingCache.set(cacheKey, items);

      LoggingService.info(
        'Retrieved ${items.length} sharings for item $itemId',
        tag: 'SharingService',
      );
      return items;
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error getting sharings for item',
        tag: 'SharingService',
        data: {'itemId': itemId, 'type': type.name},
        error: e,
        stackTrace: stackTrace,
      );

      if (e is SharingException) rethrow;
      throw FirestoreException(
        'Error obteniendo comparticiones: ${e.toString()}',
      );
    }
  }

  /// Revoca una compartición y la elimina de forma segura
  ///
  /// Esta operación primero cambia el estado a 'revoked' y luego elimina el documento.
  /// Las reglas de Firestore solo permiten eliminar documentos en estados terminales.
  ///
  /// [shareId]: ID de la compartición a revocar y eliminar
  Future<void> revokeAndDelete(String shareId) async {
    try {
      LoggingService.info(
        'Revoking and deleting sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
      );

      await revokeSharing(shareId);
      await _firestore.collection('shared_items').doc(shareId).delete();

      // Limpiar caché relacionado
      _SharingCache.clear();

      LoggingService.info(
        'Successfully revoked and deleted sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
      );
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error revoking and deleting sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// El receptor abandona una compartición y la elimina
  ///
  /// [shareId]: ID de la compartición que el receptor desea abandonar
  Future<void> leaveAndDelete(String shareId) async {
    try {
      LoggingService.info(
        'Leaving and deleting sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
      );

      await leaveSharing(shareId);
      // Try to delete only when terminal state is persisted server-side.
      // If rules still block (race/replication), swallow and let cleanup happen later.
      await _tryDeleteSharingIfTerminal(shareId);

      // Limpiar caché relacionado
      _SharingCache.clear();

      LoggingService.info(
        'Successfully left and deleted sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
      );
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error leaving and deleting sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Elimina de forma segura una compartición sin importar su estado actual
  ///
  /// Transiciona la compartición a un estado terminal válido antes de eliminarla,
  /// basándose en el rol del usuario (propietario o receptor).
  ///
  /// [shareId]: ID de la compartición a eliminar
  Future<void> safeDeleteSharing(String shareId) async {
    try {
      LoggingService.info(
        'Safely deleting sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
      );

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw const AuthenticationException();
      }

      final ref = _firestore.collection('shared_items').doc(shareId);
      final snap = await ref.get();

      if (!snap.exists) {
        LoggingService.debug('Sharing already deleted', tag: 'SharingService');
        return;
      }

      final data = snap.data() as Map<String, dynamic>;
      final statusStr = (data['status'] as String?) ?? 'pending';
      final status = SharingStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => SharingStatus.pending,
      );

      final ownerId = data['ownerId']?.toString() ?? '';
      final recipientId = data['recipientId']?.toString() ?? '';

      final isOwner = currentUser.uid == ownerId;
      final isRecipient = currentUser.uid == recipientId;

      if (!isOwner && !isRecipient) {
        throw const PermissionDeniedException(
          'No tienes permisos para eliminar esta compartición',
        );
      }

      // Si ya está en estado terminal, solo eliminar
      if (status == SharingStatus.revoked ||
          status == SharingStatus.left ||
          status == SharingStatus.rejected) {
        await ref.delete();
        LoggingService.debug(
          'Deleted sharing in terminal state',
          tag: 'SharingService',
        );
        return;
      }

      // Transicionar a estado terminal basado en el rol
      if (isOwner) {
        await ref.update({
          'status': SharingStatus.revoked.name,
          'updatedAt': fs.FieldValue.serverTimestamp(),
        });
        LoggingService.debug('Revoked sharing as owner', tag: 'SharingService');
      } else if (isRecipient) {
        final newStatus = (status == SharingStatus.pending)
            ? SharingStatus.rejected
            : SharingStatus.left;
        await ref.update({
          'status': newStatus.name,
          'updatedAt': fs.FieldValue.serverTimestamp(),
        });
        LoggingService.debug(
          'Updated sharing status as recipient',
          tag: 'SharingService',
          data: {'newStatus': newStatus.name},
        );
      }

  // Re-read to ensure terminal state is visible to rules, then delete.
  await _tryDeleteSharingIfTerminal(shareId);

      // Limpiar caché
      _SharingCache.clear();

      LoggingService.info(
        'Successfully safely deleted sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
      );
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error safely deleting sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
        error: e,
        stackTrace: stackTrace,
      );

      if (e is SharingException) rethrow;
      throw FirestoreException(
        'Error eliminando compartición: ${e.toString()}',
      );
    }
  }

  /// Intenta eliminar el documento de compartición solo si está en un estado terminal
  /// y el usuario actual es el propietario o el receptor.
  /// Si falla por permisos (por una carrera de propagación), registra y continúa.
  Future<void> _tryDeleteSharingIfTerminal(String shareId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) throw const AuthenticationException();

      final ref = _firestore.collection('shared_items').doc(shareId);

      // Pequeño reintento con backoff para cubrir carreras de propagación
      const int maxAttempts = 3;
      const Duration backoff = Duration(milliseconds: 200);
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          // Releer estado actual en servidor
          final snap = await ref.get();
          if (!snap.exists) return; // ya eliminado
          final data = snap.data() as Map<String, dynamic>;
          final statusStr =
              (data['status'] as String?) ?? SharingStatus.pending.name;
          final status = SharingStatus.values.firstWhere(
            (s) => s.name == statusStr,
            orElse: () => SharingStatus.pending,
          );

          // Solo eliminar si el estado ya es terminal
          final isTerminal = status == SharingStatus.revoked ||
              status == SharingStatus.left ||
              status == SharingStatus.rejected;
          if (!isTerminal) {
            if (attempt < maxAttempts) {
              await Future.delayed(backoff);
              continue;
            }
            return; // no terminal después de reintentos; dejar limpieza para luego
          }

          final ownerId = data['ownerId']?.toString() ?? '';
          final recipientId = data['recipientId']?.toString() ?? '';
          final canDeleteAsOwner = currentUser.uid == ownerId;
          final canDeleteAsRecipient = currentUser.uid == recipientId;
          if (canDeleteAsOwner || canDeleteAsRecipient) {
            await ref.delete();
          }
          return; // eliminado o no se tenían permisos, en ambos casos salir
        } catch (inner) {
          final msg = inner.toString().toLowerCase();
          final isPermission =
              msg.contains('permission-denied') || msg.contains('permission');
          if (isPermission) {
            if (attempt < maxAttempts) {
              await Future.delayed(backoff);
              continue; // reintentar tras breve espera
            }
            // Ignorar definitivamente: el estado ya es terminal; limpieza posterior
            LoggingService.warning(
              'Delete blocked by rules; leaving status set',
              tag: 'SharingService',
              data: {
                'shareId': shareId,
                'error': inner.toString(),
                'attempt': attempt,
              },
            );
            return;
          }
          // Otros errores, propagar inmediatamente
          rethrow;
        }
      }
    } catch (e) {
      // Errores no relacionados con permisos ya fueron propagados; aquí sólo
      // hacemos logging por si algo inesperado ocurre a nivel superior.
      LoggingService.warning(
        'Unexpected error while trying to delete terminal sharing',
        tag: 'SharingService',
        data: {'shareId': shareId, 'error': e.toString()},
      );
    }
  }

  // =====================================================================
  // ENLACES PÚBLICOS
  // =====================================================================

  /// Genera o regenera un enlace público para una nota
  ///
  /// Los enlaces públicos permiten compartir una nota con cualquier persona
  /// que tenga el enlace, sin necesidad de que tengan cuenta en la aplicación.
  ///
  /// [noteId]: ID de la nota para la cual generar el enlace
  /// [expiresAt]: Fecha de expiración opcional para el enlace
  ///
  /// Retorna el token del enlace público generado
  Future<String> generatePublicLink({
    required String noteId,
    DateTime? expiresAt,
  }) async {
    try {
      LoggingService.info(
        'Generating public link for note',
        tag: 'SharingService',
        data: {'noteId': noteId},
      );

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw const AuthenticationException();
      }

      // Verificar que la nota existe y pertenece al usuario
      final note = await FirestoreService.instance.getNote(
        uid: currentUser.uid,
        noteId: noteId,
      );

      if (note == null) {
        throw const ResourceNotFoundException('Nota');
      }

      final token = _generateSecureToken(32);

      // Crear o actualizar en la colección global para resolución rápida
      await _firestore.collection('public_links').doc(token).set({
        'noteId': noteId,
        'ownerId': currentUser.uid,
        'createdAt': fs.FieldValue.serverTimestamp(),
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'enabled': true,
        'token': token,
        'accessCount': 0,
        'lastAccessedAt': null,
      });

      // Actualizar la nota con información del enlace
      Map<String, dynamic> shareData = {
        'shareToken': token,
        'shareEnabled': true,
        'sharedAt': fs.FieldValue.serverTimestamp(),
        'shareExpiresAt': expiresAt != null
            ? Timestamp.fromDate(expiresAt)
            : null,
      };
      try {
        shareData = attachFieldTimestamps(shareData);
      } catch (_) {}
      await FirestoreService.instance.updateNote(
        uid: currentUser.uid,
        noteId: noteId,
        data: shareData,
      );

      LoggingService.info(
        'Successfully generated public link',
        tag: 'SharingService',
        data: {'noteId': noteId, 'token': token},
      );

      return token;
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error generating public link',
        tag: 'SharingService',
        data: {'noteId': noteId},
        error: e,
        stackTrace: stackTrace,
      );

      if (e is SharingException) rethrow;
      throw FirestoreException(
        'Error generando enlace público: ${e.toString()}',
      );
    }
  }

  /// Revoca un enlace público existente
  ///
  /// [noteId]: ID de la nota cuyo enlace público se desea revocar
  Future<void> revokePublicLink({required String noteId}) async {
    try {
      LoggingService.info(
        'Revoking public link for note',
        tag: 'SharingService',
        data: {'noteId': noteId},
      );

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw const AuthenticationException();
      }

      // Obtener el token actual de la nota
      final note = await FirestoreService.instance.getNote(
        uid: currentUser.uid,
        noteId: noteId,
      );

      if (note == null) {
        throw const ResourceNotFoundException('Nota');
      }

      final token = note['shareToken']?.toString();
      if (token != null && token.isNotEmpty) {
        // Deshabilitar en la colección de enlaces públicos
        await _firestore.collection('public_links').doc(token).set({
          'enabled': false,
          'revokedAt': fs.FieldValue.serverTimestamp(),
        }, fs.SetOptions(merge: true));
      }

      // Actualizar la nota
      Map<String, dynamic> revokeData = {
        'shareEnabled': false,
        'shareRevokedAt': fs.FieldValue.serverTimestamp(),
      };
      try {
        revokeData = attachFieldTimestamps(revokeData);
      } catch (_) {}
      await FirestoreService.instance.updateNote(
        uid: currentUser.uid,
        noteId: noteId,
        data: revokeData,
      );

      LoggingService.info(
        'Successfully revoked public link',
        tag: 'SharingService',
        data: {'noteId': noteId},
      );
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error revoking public link',
        tag: 'SharingService',
        data: {'noteId': noteId},
        error: e,
        stackTrace: stackTrace,
      );

      if (e is SharingException) rethrow;
      throw FirestoreException(
        'Error revocando enlace público: ${e.toString()}',
      );
    }
  }

  /// Obtiene el token de enlace público para una nota (si está habilitado)
  ///
  /// [noteId]: ID de la nota
  ///
  /// Retorna el token del enlace público o null si no existe o está deshabilitado
  Future<String?> getPublicLinkToken({required String noteId}) async {
    try {
      LoggingService.debug(
        'Getting public link token for note',
        tag: 'SharingService',
        data: {'noteId': noteId},
      );

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw const AuthenticationException();
      }

      final note = await FirestoreService.instance.getNote(
        uid: currentUser.uid,
        noteId: noteId,
      );

      if (note == null) {
        return null;
      }

      if (note['shareEnabled'] != true) {
        return null;
      }

      final token = note['shareToken']?.toString();
      if (token == null || token.isEmpty) {
        return null;
      }

      // Verificar que el enlace aún está habilitado
      final linkDoc = await _firestore
          .collection('public_links')
          .doc(token)
          .get();
      if (!linkDoc.exists || (linkDoc.data()?['enabled'] != true)) {
        return null;
      }

      // Verificar expiración
      final expiresAt = linkDoc.data()?['expiresAt'] as Timestamp?;
      if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
        return null;
      }

      return token;
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error getting public link token',
        tag: 'SharingService',
        data: {'noteId': noteId},
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Resuelve un token público a información de la nota
  ///
  /// [token]: Token del enlace público
  ///
  /// Retorna un mapa con la información de la nota o null si el token es inválido
  Future<Map<String, String>?> resolvePublicToken(String token) async {
    try {
      LoggingService.debug(
        'Resolving public token',
        tag: 'SharingService',
        data: {'token': token},
      );

      if (token.isEmpty) {
        return null;
      }

      final linkDoc = await _firestore
          .collection('public_links')
          .doc(token)
          .get();
      if (!linkDoc.exists) {
        LoggingService.debug(
          'Public link token not found',
          tag: 'SharingService',
        );
        return null;
      }

      final data = linkDoc.data()!;
      if (data['enabled'] != true) {
        LoggingService.debug('Public link is disabled', tag: 'SharingService');
        return null;
      }

      // Verificar expiración
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
        LoggingService.debug('Public link has expired', tag: 'SharingService');
        return null;
      }

      final ownerId = data['ownerId']?.toString() ?? '';
      final noteId = data['noteId']?.toString() ?? '';

      if (ownerId.isEmpty || noteId.isEmpty) {
        LoggingService.warning(
          'Invalid public link data',
          tag: 'SharingService',
          data: {'ownerId': ownerId, 'noteId': noteId},
        );
        return null;
      }

      // Actualizar estadísticas de acceso
      await _firestore.collection('public_links').doc(token).update({
        'accessCount': fs.FieldValue.increment(1),
        'lastAccessedAt': fs.FieldValue.serverTimestamp(),
      });

      return {'ownerId': ownerId, 'noteId': noteId, 'token': token};
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error resolving public token',
        tag: 'SharingService',
        data: {'token': token},
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Genera un token seguro para enlaces públicos
  String _generateSecureToken(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // =====================================================================
  // GESTIÓN DE USUARIOS
  // =====================================================================

  /// Busca un usuario por email con validación y caché
  ///
  /// [email]: Email del usuario a buscar
  ///
  /// Retorna información del usuario o null si no se encuentra
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    try {
      if (email.trim().isEmpty) {
        throw const ValidationException('email', 'Email no puede estar vacío');
      }

      final normalizedEmail = email.trim().toLowerCase();

      LoggingService.debug(
        'Finding user by email',
        tag: 'SharingService',
        data: {'email': normalizedEmail},
      );

      // Verificar caché
      final cacheKey = 'user_email_$normalizedEmail';
      final cached = _SharingCache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        LoggingService.debug(
          'Returning cached user data',
          tag: 'SharingService',
        );
        return cached;
      }

      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        LoggingService.debug(
          'User not found by email',
          tag: 'SharingService',
          data: {'email': normalizedEmail},
        );
        return null;
      }

      final doc = snapshot.docs.first;
      final result = {
        'uid': doc.id,
        'email': doc.data()['email'],
        'fullName': doc.data()['fullName'],
        'username': doc.data()['username'],
      };

      // Guardar en caché
      _SharingCache.set(cacheKey, result);

      LoggingService.info(
        'User found by email',
        tag: 'SharingService',
        data: {'email': normalizedEmail, 'uid': result['uid']},
      );

      return result;
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error finding user by email',
        tag: 'SharingService',
        data: {'email': email},
        error: e,
        stackTrace: stackTrace,
      );

      if (e is SharingException) rethrow;

      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission') || errorStr.contains('denied')) {
        throw const PermissionDeniedException(
          'Sin permisos para buscar usuarios. Verifica las reglas de Firestore.',
        );
      }

      throw FirestoreException(
        'Error buscando usuario por email: ${e.toString()}',
      );
    }
  }

  /// Busca un usuario por username con validación y caché
  ///
  /// [username]: Username del usuario a buscar (sin @)
  ///
  /// Retorna información del usuario o null si no se encuentra
  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    try {
      if (username.trim().isEmpty) {
        throw const ValidationException(
          'username',
          'Username no puede estar vacío',
        );
      }

      final normalizedUsername = username.trim().toLowerCase().replaceAll(
        '@',
        '',
      );

      LoggingService.debug(
        'Finding user by username',
        tag: 'SharingService',
        data: {'username': normalizedUsername},
      );

      // Verificar caché
      final cacheKey = 'user_username_$normalizedUsername';
      final cached = _SharingCache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        LoggingService.debug(
          'Returning cached user data',
          tag: 'SharingService',
        );
        return cached;
      }

      final handle = await FirestoreService.instance.getHandle(
        username: normalizedUsername,
      );

      if (handle == null) {
        LoggingService.debug(
          'Handle not found for username',
          tag: 'SharingService',
          data: {'username': normalizedUsername},
        );
        return null;
      }

      final uid = handle['uid'];
      final userProfile = await FirestoreService.instance.getUserProfile(
        uid: uid,
      );

      if (userProfile == null) {
        LoggingService.warning(
          'User profile not found for handle',
          tag: 'SharingService',
          data: {'username': normalizedUsername, 'uid': uid},
        );
        return null;
      }

      final result = {
        'uid': uid,
        'email': userProfile['email'],
        'fullName': userProfile['fullName'],
        'username': userProfile['username'],
      };

      // Guardar en caché
      _SharingCache.set(cacheKey, result);

      LoggingService.info(
        'User found by username',
        tag: 'SharingService',
        data: {'username': normalizedUsername, 'uid': uid},
      );

      return result;
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error finding user by username',
        tag: 'SharingService',
        data: {'username': username},
        error: e,
        stackTrace: stackTrace,
      );

      if (e is SharingException) rethrow;

      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission') || errorStr.contains('denied')) {
        throw const PermissionDeniedException(
          'Sin permisos para buscar usuarios. Verifica las reglas de Firestore.',
        );
      }

      throw FirestoreException(
        'Error buscando usuario por username: ${e.toString()}',
      );
    }
  }

  // Placeholder methods that need to be implemented
  Future<void> revokeSharing(String shareId) async {
    try {
      LoggingService.info(
        'Revoking sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
      );

      final currentUser = _authService.currentUser;
      if (currentUser == null) throw const AuthenticationException();

      final ref = _firestore.collection('shared_items').doc(shareId);
      final snap = await ref.get();
      if (!snap.exists) throw const ResourceNotFoundException('Compartición');

      final data = snap.data() as Map<String, dynamic>;
      final ownerId = data['ownerId']?.toString() ?? '';
      if (ownerId != currentUser.uid) {
        throw const PermissionDeniedException(
          'Solo el propietario puede revocar la compartición',
        );
      }

      final statusStr =
          (data['status'] as String?) ?? SharingStatus.pending.name;
      final status = SharingStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => SharingStatus.pending,
      );

      if (status == SharingStatus.revoked ||
          status == SharingStatus.left ||
          status == SharingStatus.rejected) {
        // Already terminal
        LoggingService.debug(
          'Sharing already in terminal state',
          tag: 'SharingService',
          data: {'shareId': shareId, 'status': status.name},
        );
        return;
      }

      await ref.update({
        'status': SharingStatus.revoked.name,
        'updatedAt': fs.FieldValue.serverTimestamp(),
      });

      // Optionally send notification to recipient
      try {
        final recipientId = data['recipientId']?.toString();
        if (recipientId != null &&
            recipientId.isNotEmpty &&
            _config.enableNotifications) {
          // Use NotificationService helper for share revoked
          try {
            final ownerName = currentUser.email?.split('@').first ?? 'Usuario';
            final itemTitle =
                (data['metadata'] as Map<String, dynamic>?)?['noteTitle'] ??
                (data['metadata'] as Map<String, dynamic>?)?['folderName'] ??
                '';
            await NotificationService().notifyShareRevoked(
              recipientId: recipientId,
              ownerName: ownerName,
              itemTitle: itemTitle,
              shareId: shareId,
            );
          } catch (nErr) {
            LoggingService.warning(
              'Failed to send revoke notification',
              tag: 'SharingService',
              data: {'err': nErr.toString()},
            );
          }
        }
      } catch (_) {
        // silence notification failures
      }

      // Invalidate related cache entries
      _SharingCache.clear();

      LoggingService.info(
        'Sharing revoked',
        tag: 'SharingService',
        data: {'shareId': shareId},
      );
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error revoking sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
        error: e,
        stackTrace: stackTrace,
      );
      if (e is SharingException) rethrow;
      throw FirestoreException('Error revocando compartición: ${e.toString()}');
    }
  }

  Future<void> leaveSharing(String shareId) async {
    try {
      LoggingService.info(
        'Leaving sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
      );

      final currentUser = _authService.currentUser;
      if (currentUser == null) throw const AuthenticationException();

      final ref = _firestore.collection('shared_items').doc(shareId);
      final snap = await ref.get();
      if (!snap.exists) throw const ResourceNotFoundException('Compartición');

      final data = snap.data() as Map<String, dynamic>;
      final recipientId = data['recipientId']?.toString() ?? '';
      if (recipientId != currentUser.uid) {
        throw const PermissionDeniedException(
          'Solo el receptor puede abandonar la compartición',
        );
      }

      final statusStr =
          (data['status'] as String?) ?? SharingStatus.pending.name;
      final status = SharingStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => SharingStatus.pending,
      );

      if (status == SharingStatus.left ||
          status == SharingStatus.revoked ||
          status == SharingStatus.rejected) {
        LoggingService.debug(
          'Sharing already in terminal state',
          tag: 'SharingService',
          data: {'shareId': shareId, 'status': status.name},
        );
        return;
      }

      final newStatus = (status == SharingStatus.pending)
          ? SharingStatus.rejected
          : SharingStatus.left;

      await ref.update({
        'status': newStatus.name,
        'updatedAt': fs.FieldValue.serverTimestamp(),
      });

      // Send notification to owner if configured
      try {
        final ownerId = data['ownerId']?.toString();
        if (ownerId != null &&
            ownerId.isNotEmpty &&
            _config.enableNotifications) {
          try {
            final recipientName =
                currentUser.email?.split('@').first ?? 'Usuario';
            final recipientEmail = currentUser.email ?? '';
            final itemTitle =
                (data['metadata'] as Map<String, dynamic>?)?['noteTitle'] ??
                (data['metadata'] as Map<String, dynamic>?)?['folderName'] ??
                '';
            await NotificationService().notifyShareLeft(
              ownerId: ownerId,
              recipientName: recipientName,
              recipientEmail: recipientEmail,
              itemTitle: itemTitle,
              shareId: shareId,
            );
          } catch (nErr) {
            LoggingService.warning(
              'Failed to send leave notification',
              tag: 'SharingService',
              data: {'err': nErr.toString()},
            );
          }
        }
      } catch (_) {}

      _SharingCache.clear();

      LoggingService.info(
        'User left sharing',
        tag: 'SharingService',
        data: {'shareId': shareId, 'newStatus': newStatus.name},
      );
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error leaving sharing',
        tag: 'SharingService',
        data: {'shareId': shareId},
        error: e,
        stackTrace: stackTrace,
      );
      if (e is SharingException) rethrow;
      throw FirestoreException(
        'Error abandonando compartición: ${e.toString()}',
      );
    }
  }
}
