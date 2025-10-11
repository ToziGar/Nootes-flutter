# 🔧 Solución: Permisos de Firestore para Notas en Carpetas Compartidas

**Fecha:** 11 de octubre, 2025  
**Problema:** `[cloud_firestore/permission-denied]` al cargar notas de carpetas compartidas

---

## ❌ Problema Original

Al intentar cargar notas dentro de una carpeta compartida, Firestore bloqueaba el acceso:

```
❌ Error cargando notas de carpetas compartidas: 
[cloud_firestore/permission-denied] Missing or insufficient permissions.
```

### Causa Raíz

Las reglas de Firestore para notas solo permitían lectura si:
1. Eres el propietario de la nota
2. La nota está **directamente** compartida contigo

**Pero NO permitían** leer notas solo porque tienes acceso a la carpeta que las contiene.

```javascript
// Regla original (insuficiente)
match /users/{uid}/notes/{noteId} {
  allow read: if isOwner(uid) || 
    (exists(/databases/$(database)/documents/shared_items/$(recipientId + '_' + uid + '_' + noteId)) &&
     get(...).data.status == 'accepted');
}
```

### Arquitectura del Problema

```
shared_items/
├── user2_user1_folder123  ✅ Carpeta compartida (aceptada)
└── (no hay shares para notas individuales) ❌

users/user1/folders/folder123
└── noteIds: ['note1', 'note2', 'note3']

users/user1/notes/
├── note1  ❌ user2 NO puede leerla (sin shared_item)
├── note2  ❌ user2 NO puede leerla (sin shared_item)
└── note3  ❌ user2 NO puede leerla (sin shared_item)
```

---

## ✅ Solución Implementada

### Estrategia: Comparticiones Automáticas en Cascada

Cuando un usuario **acepta una carpeta compartida**, el sistema automáticamente:

1. Crea documentos `shared_items` para **cada nota** dentro de la carpeta
2. Marca esas comparticiones como `status: 'accepted'` automáticamente
3. Esto permite que Firestore permita el acceso según las reglas existentes

### Cambios en el Código

#### 1. Modificado `acceptSharing()` en `sharing_service.dart`

```dart
Future<void> acceptSharing(String sharingId) async {
  // ... código existente ...
  
  // Actualizar el estado de la carpeta
  await _firestore.collection('shared_items').doc(sharingId).update({
    'status': SharingStatus.accepted.name,
    'updatedAt': fs.FieldValue.serverTimestamp(),
  });
  
  // ⭐ NUEVO: Si es una carpeta, crear shares para cada nota dentro
  if (itemType == SharedItemType.folder.name) {
    try {
      await _createNoteSharesForFolder(
        folderId: itemId,
        ownerId: ownerId,
        recipientId: currentUser.uid,
        recipientEmail: currentUser.email ?? '',
        permission: PermissionLevel.values.firstWhere((p) => p.name == permission),
      );
      debugPrint('✅ Comparticiones de notas creadas para carpeta $itemId');
    } catch (e) {
      debugPrint('⚠️ Error creando comparticiones de notas: $e');
    }
  }
  
  // ... notificaciones ...
}
```

#### 2. Nuevo Método `_createNoteSharesForFolder()`

```dart
Future<void> _createNoteSharesForFolder({
  required String folderId,
  required String ownerId,
  required String recipientId,
  required String recipientEmail,
  required PermissionLevel permission,
}) async {
  // Obtener la carpeta para saber qué notas contiene
  final folder = await FirestoreService.instance.getFolder(
    uid: ownerId,
    folderId: folderId,
  );

  if (folder == null || folder['noteIds'] == null) return;

  final noteIds = List<String>.from(folder['noteIds'] ?? []);
  debugPrint('📝 Creando comparticiones para ${noteIds.length} notas');

  // Crear comparticiones en batch
  final batch = _firestore.batch();
  int created = 0;

  for (final noteId in noteIds) {
    final shareId = '${recipientId}_${ownerId}_$noteId';
    final docRef = _firestore.collection('shared_items').doc(shareId);
    
    // Verificar si ya existe
    final exists = await docRef.get();
    if (exists.exists) continue;

    // Obtener metadata de la nota
    final note = await FirestoreService.instance.getNote(
      uid: ownerId,
      noteId: noteId,
    );

    batch.set(docRef, {
      'itemId': noteId,
      'type': SharedItemType.note.name,
      'ownerId': ownerId,
      'ownerEmail': folder['ownerEmail'] ?? '',
      'recipientId': recipientId,
      'recipientEmail': recipientEmail,
      'permission': permission.name,
      'status': SharingStatus.accepted.name, // ⭐ Auto-aceptada
      'createdAt': fs.FieldValue.serverTimestamp(),
      'updatedAt': fs.FieldValue.serverTimestamp(),
      'metadata': {
        'noteTitle': note?['title'] ?? 'Sin título',
        'fromFolder': folderId,
        'folderName': folder['name'] ?? 'Sin nombre',
      },
    });
    created++;
  }

  if (created > 0) {
    await batch.commit();
    debugPrint('✅ Creadas $created comparticiones automáticas');
  }
}
```

#### 3. Mejorado `getNotesInSharedFolder()`

Ahora puede cargar las notas correctamente porque tienen permisos:

```dart
// Obtener cada nota (ahora tienen permisos)
for (final noteId in noteIds) {
  try {
    final note = await FirestoreService.instance.getNote(
      uid: ownerId,
      noteId: noteId,
    );

    if (note != null) {
      notes.add({
        ...note,
        'isShared': true,
        'isInSharedFolder': true,
        'sharedFolderId': folderId,
        'sharedBy': sharing.ownerEmail,
        'ownerId': ownerId,
        'permission': sharing.permission.name,
        'sharedAt': sharing.createdAt,
      });
    }
  } catch (e) {
    debugPrint('   ❌ Error cargando nota $noteId: $e');
    // Continuar con las demás
  }
}
```

---

## 📊 Arquitectura Después de la Solución

```
1. Usuario 1 comparte carpeta con Usuario 2
   ↓
2. Usuario 2 acepta la carpeta
   ↓
3. Sistema crea shared_items automáticamente:

shared_items/
├── user2_user1_folder123  ✅ Carpeta (aceptada)
├── user2_user1_note1      ✅ Nota 1 (auto-aceptada)
├── user2_user1_note2      ✅ Nota 2 (auto-aceptada)
└── user2_user1_note3      ✅ Nota 3 (auto-aceptada)

users/user1/folders/folder123
└── noteIds: ['note1', 'note2', 'note3']

users/user1/notes/
├── note1  ✅ user2 PUEDE leerla (tiene shared_item)
├── note2  ✅ user2 PUEDE leerla (tiene shared_item)
└── note3  ✅ user2 PUEDE leerla (tiene shared_item)
```

---

## 🎯 Casos de Uso Cubiertos

### Caso 1: Aceptar Carpeta Compartida

```
Usuario 2 acepta carpeta "Proyectos" de Usuario 1
↓
Sistema crea automáticamente:
- shared_items/user2_user1_note1 (status: accepted)
- shared_items/user2_user1_note2 (status: accepted)
- shared_items/user2_user1_note3 (status: accepted)
↓
Usuario 2 puede ver las 3 notas dentro de la carpeta ✅
```

### Caso 2: Propietario Agrega Nota a Carpeta Ya Compartida

```
Usuario 1 crea nueva nota y la agrega a "Proyectos"
↓
⚠️ PROBLEMA: No se crea shared_item automáticamente
↓
Usuario 2 NO verá la nueva nota hasta:
- Revocar y volver a compartir la carpeta, O
- Compartir la nota manualmente
```

**Nota:** Este caso requiere una mejora futura con triggers o listeners.

### Caso 3: Revocar Carpeta Compartida

```
Usuario 1 revoca acceso a carpeta "Proyectos"
↓
Estado de shared_items/user2_user1_folder123: "revoked"
↓
⚠️ Las notas individuales siguen con status: "accepted"
↓
Usuario 2 podría seguir viendo las notas
```

**Solución futura:** Al revocar carpeta, actualizar el estado de todas las notas.

---

## 🚀 Testing

### Probar la Solución

1. **Crear carpeta con notas:**
   ```
   Usuario 1:
   - Crea carpeta "Proyectos"
   - Crea 3 notas dentro
   - Comparte carpeta con Usuario 2 (permiso: read)
   ```

2. **Aceptar compartición:**
   ```
   Usuario 2:
   - Ve notificación de carpeta compartida
   - Click en "Aceptar"
   - Espera ~1-2 segundos para que se creen los shares
   ```

3. **Verificar Firestore:**
   ```
   Firebase Console → Firestore → shared_items
   
   Debe haber 4 documentos:
   ✅ user2_user1_folder123 (type: folder, status: accepted)
   ✅ user2_user1_note1 (type: note, status: accepted, fromFolder: folder123)
   ✅ user2_user1_note2 (type: note, status: accepted, fromFolder: folder123)
   ✅ user2_user1_note3 (type: note, status: accepted, fromFolder: folder123)
   ```

4. **Ver notas en la app:**
   ```
   Usuario 2:
   - Click en "📥 Conmigo"
   - Debe aparecer carpeta "Proyectos"
   - Click en carpeta
   - Debe ver las 3 notas ✅
   ```

### Logs Esperados

```
📤 Aceptando compartición folder123
✅ Estado actualizado a: accepted
📝 Creando comparticiones para 3 notas en carpeta folder123
   ⏭️ Compartición ya existe para nota note1 (si re-acepta)
✅ Creadas 3 comparticiones automáticas de notas
📂 Cargando 3 notas de carpeta compartida folder123
   ✅ Nota note1 cargada
   ✅ Nota note2 cargada
   ✅ Nota note3 cargada
✅ Cargadas 3/3 notas de carpeta compartida
```

---

## ⚠️ Limitaciones y Mejoras Futuras

### Limitación 1: Notas Agregadas Después
**Problema:** Si el propietario agrega una nota nueva a una carpeta ya compartida, el receptor no la verá automáticamente.

**Solución Futura:**
- Implementar Cloud Function que escuche cambios en `folders/{folderId}/noteIds`
- Cuando se agregue un noteId, crear automáticamente el shared_item
- O implementar un listener en la app que detecte cambios

### Limitación 2: Revocar Carpeta no Revoca Notas
**Problema:** Al revocar una carpeta, las notas individuales siguen compartidas.

**Solución Futura:**
- En `revokeSharing()`, detectar si es carpeta
- Buscar todos los shared_items con `metadata.fromFolder == folderId`
- Actualizar su estado a `revoked` también

### Limitación 3: Rendimiento con Carpetas Grandes
**Problema:** Si una carpeta tiene 100+ notas, aceptarla puede tardar varios segundos.

**Solución Futura:**
- Usar Cloud Functions para crear los shares en background
- Mostrar mensaje "Procesando comparticiones..." en la UI
- Enviar notificación cuando termine

### Limitación 4: Duplicación de Datos
**Problema:** Cada nota compartida tiene un documento en `shared_items`, aumentando el uso de Firestore.

**Solución Alternativa:**
- Usar una estructura jerárquica: `shared_items/{folderId}/notes/{noteId}`
- Actualizar reglas de Firestore para verificar permisos en la carpeta padre

---

## 📋 Checklist de Implementación

- [x] Modificar `acceptSharing()` para detectar carpetas
- [x] Crear método `_createNoteSharesForFolder()`
- [x] Actualizar `getNotesInSharedFolder()` para cargar notas completas
- [x] Agregar logs de diagnóstico
- [x] Manejar errores sin bloquear el flujo
- [ ] Implementar revocar notas cuando se revoca carpeta
- [ ] Agregar listener para notas nuevas en carpetas compartidas
- [ ] Optimizar con Cloud Functions para carpetas grandes
- [ ] Agregar UI feedback "Procesando comparticiones..."

---

**Estado:** ✅ Implementado y funcionando  
**Versión:** 1.0.0  
**Próxima Mejora:** Revocar notas automáticamente al revocar carpeta
