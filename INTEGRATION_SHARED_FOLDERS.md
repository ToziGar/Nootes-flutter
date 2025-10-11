# Integración de Carpetas y Notas Compartidas en el Menú Lateral

## 🎯 Objetivo

Mostrar en el menú lateral (drawer) del workspace:
1. **Carpetas compartidas** mezcladas con carpetas propias
2. **Notas dentro de carpetas compartidas** automáticamente visibles
3. **Indicador visual** de carpetas/notas compartidas
4. **Sincronización**: Si el dueño elimina, desaparece para todos

---

## ⚠️ ESTADO ACTUAL

**HAY ERRORES DE SINTAXIS** en `lib/notes/workspace_page.dart` que necesitan corrección.

El código quedó mal formateado al intentar modificar `_buildFolderCard`. Necesita limpiarse.

---

## ✅ Cambios Implementados en SharingService

### Archivo: `lib/services/sharing_service.dart`

#### 1. Nuevo método: `getSharedFolders()`

```dart
/// Obtiene carpetas compartidas conmigo que he aceptado
Future<List<Map<String, dynamic>>> getSharedFolders() async {
  final currentUser = _authService.currentUser;
  if (currentUser == null) return [];

  final sharedItems = await _firestore
      .collection('shared_items')
      .where('recipientId', isEqualTo: currentUser.uid)
      .where('type', isEqualTo: SharedItemType.folder.name)
      .where('status', isEqualTo: SharingStatus.accepted.name)
      .get();

  final List<Map<String, dynamic>> folders = [];

  for (final doc in sharedItems.docs) {
    final sharing = SharedItem.fromMap(doc.id, doc.data());
    
    // Obtener la carpeta desde el propietario
    final folder = await FirestoreService.instance.getFolder(
      uid: sharing.ownerId,
      folderId: sharing.itemId,
    );

    if (folder != null) {
      folders.add({
        ...folder,
        'isShared': true,
        'sharingId': sharing.id,
        'sharedBy': sharing.ownerEmail,
        'ownerId': sharing.ownerId,
        'permission': sharing.permission.name,
        'sharedAt': sharing.createdAt,
      });
    }
  }

  return folders;
}
```

#### 2. Nuevo método: `getNotesInSharedFolder()`

```dart
/// Obtiene las notas dentro de una carpeta compartida
Future<List<Map<String, dynamic>>> getNotesInSharedFolder({
  required String folderId,
  required String ownerId,
}) async {
  final currentUser = _authService.currentUser;
  if (currentUser == null) return [];

  // Verificar que tengo acceso a la carpeta
  final folderAccess = await _firestore
      .collection('shared_items')
      .where('itemId', isEqualTo: folderId)
      .where('ownerId', isEqualTo: ownerId)
      .where('recipientId', isEqualTo: currentUser.uid)
      .where('type', isEqualTo: SharedItemType.folder.name)
      .where('status', isEqualTo: SharingStatus.accepted.name)
      .get();

  if (folderAccess.docs.isEmpty) return [];

  final sharing = SharedItem.fromMap(folderAccess.docs.first.id, folderAccess.docs.first.data());

  // Obtener la carpeta para saber qué notas contiene
  final folder = await FirestoreService.instance.getFolder(
    uid: ownerId,
    folderId: folderId,
  );

  if (folder == null || folder['noteIds'] == null) return [];

  final noteIds = List<String>.from(folder['noteIds'] ?? []);
  final List<Map<String, dynamic>> notes = [];

  // Obtener cada nota
  for (final noteId in noteIds) {
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
  }

  return notes;
}
```

---

## 🔨 Cambios Necesarios en workspace_page.dart

### 1. Añadir campo para tracking de carpetas compartidas

```dart
// En la sección de state variables:
List<Folder> _folders = [];
Map<String, Map<String, dynamic>> _sharedFoldersInfo = {}; // INFO EXTRA DE CARPETAS COMPARTIDAS
```

### 2. Modificar `_loadFolders()` para incluir carpetas compartidas

```dart
Future<void> _loadFolders() async {
  try {
    // Cargar carpetas propias
    final foldersData = await FirestoreService.instance.listFolders(uid: _uid);
    debugPrint('📁 Carpetas propias: ${foldersData.length}');
    
    // Cargar carpetas compartidas conmigo
    final sharedFoldersData = await SharingService().getSharedFolders();
    debugPrint('📁 Carpetas compartidas: ${sharedFoldersData.length}');
    
    if (!mounted) return;
    
    // Combinar carpetas
    final allFoldersData = [...foldersData, ...sharedFoldersData];
    
    // Eliminar duplicados
    final seen = <String>{};
    final uniqueFolders = <Folder>[];
    final sharedInfo = <String, Map<String, dynamic>>{};
    
    for (var data in allFoldersData) {
      final logicalId = data['folderId']?.toString() ?? data['id'].toString();
      if (!seen.contains(logicalId)) {
        seen.add(logicalId);
        final folder = Folder.fromJson(Map<String, dynamic>.from(data));
        uniqueFolders.add(folder);
        
        // Guardar info de carpetas compartidas
        if (data['isShared'] == true) {
          sharedInfo[folder.id] = {
            'isShared': true,
            'sharedBy': data['sharedBy'],
            'ownerId': data['ownerId'],
            'permission': data['permission'],
            'sharedAt': data['sharedAt'],
          };
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _folders = uniqueFolders;
        _sharedFoldersInfo = sharedInfo;
      });
    }
    
    await _cleanOrphanedNoteReferences();
  } catch (e) {
    debugPrint('❌ Error: $e');
    if (mounted) setState(() => _folders = []);
  }
}
```

### 3. Modificar `_loadNotes()` para incluir notas de carpetas compartidas

```dart
Future<void> _loadNotes() async {
  // ... código existente de __SHARED_WITH_ME__ y __SHARED_BY_ME__ ...
  
  // Cargar notas propias
  List<Map<String, dynamic>> allNotes = await svc.listNotesSummary(uid: _uid);
  
  // NUEVO: Cargar notas de carpetas compartidas
  final sharedFoldersData = await SharingService().getSharedFolders();
  for (final folderData in sharedFoldersData) {
    final folderId = folderData['id'] as String;
    final ownerId = folderData['ownerId'] as String;
    final notesInSharedFolder = await SharingService().getNotesInSharedFolder(
      folderId: folderId,
      ownerId: ownerId,
    );
    allNotes.addAll(notesInSharedFolder);
  }
  
  // NUEVO: Cargar notas compartidas individuales
  final sharedNotes = await SharingService().getSharedNotes();
  allNotes.addAll(sharedNotes);
  
  if (!mounted) return;
  
  // ... resto del código de filtrado ...
}
```

### 4. Modificar `_buildFolderCard()` para mostrar indicador visual

```dart
Widget _buildFolderCard(Folder folder, int noteCount) {
  final isExpanded = _expandedFolders.contains(folder.id);
  final notesInFolder = _notes.where((n) => folder.noteIds.contains(n['id'].toString())).toList();
  
  // NUEVO: Detectar si es compartida
  final isShared = _sharedFoldersInfo.containsKey(folder.id);
  final sharedInfo = _sharedFoldersInfo[folder.id];
  
  return DragTarget<String>(
    key: ValueKey('folder_${folder.id}'),
    onWillAcceptWithDetails: (details) => !isShared, // NO permitir drag en carpetas compartidas
    onAcceptWithDetails: (details) => _onNoteDroppedInFolder(details.data, folder.id),
    builder: (context, candidateData, rejectedData) {
      // ... código existente ...
      
      return Column(
        children: [
          Container(
            // ... decoración existente ...
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedFolders.remove(folder.id);
                    } else {
                      _expandedFolders.add(folder.id);
                    }
                  });
                },
                // NUEVO: Deshabilitar long press en carpetas compartidas
                onLongPress: isShared ? null : () => _confirmDeleteFolder(folder),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      // Flecha de expandir
                      Icon(isExpanded ? Icons.arrow_drop_down : Icons.arrow_right),
                      
                      // Icono de carpeta
                      Icon(Icons.folder_rounded, color: folder.color),
                      
                      // Nombre
                      Expanded(
                        child: Text(folder.name),
                      ),
                      
                      // NUEVO: Indicador de compartida
                      if (isShared)
                        Tooltip(
                          message: 'Compartida por ${sharedInfo?['sharedBy']}',
                          child: Icon(
                            Icons.people_rounded,
                            size: 14,
                            color: AppColors.info,
                          ),
                        ),
                      
                      // Contador
                      if (noteCount > 0)
                        Text('$noteCount'),
                      
                      // Botón editar (NUEVO: solo si NO es compartida)
                      if (!isShared)
                        IconButton(
                          icon: Icon(Icons.brush_rounded),
                          onPressed: () => _showFolderIconPicker(folder.id),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Notas dentro (expandidas)
          if (isExpanded && notesInFolder.isNotEmpty)
            ...notesInFolder.map((note) {
              final noteIsShared = note['isShared'] == true;
              final noteIsInSharedFolder = note['isInSharedFolder'] == true;
              
              return NoteCard(
                note: note,
                // NUEVO: Deshabilitar edición/eliminación para notas compartidas sin permiso
                canEdit: !noteIsShared || note['permission'] == 'edit',
                canDelete: !noteIsShared,
                showSharedIcon: noteIsShared || noteIsInSharedFolder,
              );
            }),
        ],
      );
    },
  );
}
```

---

## 🎨 UI Esperada

### Carpeta Propia
```
📁 Mis Documentos (5)        [🖌️]
```

### Carpeta Compartida
```
📁 Proyectos Equipo (3)  👥
   └─ (sin botón editar, sin long press)
```

### Nota en Carpeta Compartida
```
  📝 Diseño App
     👥 Compartida por juan@example.com
     🔐 Solo lectura / 💬 Comentarios / ✏️ Edición
```

---

## 🔄 Sincronización Automática

### Cuando el Dueño Elimina una Nota de una Carpeta Compartida:

1. **Dueño ejecuta:** `FirestoreService().removeNoteFromFolder()`
2. **Firestore actualiza:** `folder.noteIds` (quita el ID)
3. **Todos los receptores:** 
   - Al hacer `_loadNotes()` → `getNotesInSharedFolder()` 
   - Lee `folder.noteIds` actualizada
   - La nota ya no aparece en la lista

### Flujo de datos:

```
Dueño elimina nota de carpeta
  ↓
Firestore: folder.noteIds actualizado
  ↓
Receptor llama getNotesInSharedFolder()
  ↓
Lee folder.noteIds actual (sin la nota eliminada)
  ↓
Solo obtiene notas que siguen en noteIds
  ↓
Nota desaparece del UI del receptor
```

**NO** se necesita notificar explícitamente porque cada vez que `_loadNotes()` se ejecuta, se consulta el estado actual de la carpeta en Firestore.

---

## 🔐 Permisos por Nivel

| Permiso | Ver Carpeta | Ver Notas | Editar Notas | Eliminar Notas |
|---------|-------------|-----------|--------------|----------------|
| `read` | ✅ | ✅ | ❌ | ❌ |
| `comment` | ✅ | ✅ | 💬 Solo comentarios | ❌ |
| `edit` | ✅ | ✅ | ✅ | ❌ |
| owner | ✅ | ✅ | ✅ | ✅ |

---

## ⚙️ Optimización Futura

### Problema: Muchas consultas a Firestore

Actualmente se hace:
1. `getSharedFolders()` - 1 consulta
2. Para cada carpeta compartida:
   - `getFolder()` - N consultas
   - Para cada nota en carpeta:
     - `getNote()` - M consultas

**Total:** 1 + N + (N × M) consultas

### Solución Futura: Batch Loading

```dart
Future<List<Map<String, dynamic>>> getNotesInSharedFoldersOptimized() async {
  // 1. Obtener todas las carpetas compartidas aceptadas
  final sharedFolders = await getSharedFolders();
  
  // 2. Extraer todos los noteIds de todas las carpetas
  final allNoteIds = <String>{};
  final folderOwners = <String, String>{}; // noteId -> ownerId
  
  for (final folder in sharedFolders) {
    final noteIds = List<String>.from(folder['noteIds'] ?? []);
    final ownerId = folder['ownerId'] as String;
    
    for (final noteId in noteIds) {
      allNoteIds.add(noteId);
      folderOwners[noteId] = ownerId;
    }
  }
  
  // 3. Agrupar por owner para hacer consultas por lote
  final notesByOwner = <String, List<String>>{};
  for (final entry in folderOwners.entries) {
    notesByOwner.putIfAbsent(entry.value, () => []).add(entry.key);
  }
  
  // 4. Consultar todas las notas de cada owner en una sola query
  final allNotes = <Map<String, dynamic>>[];
  for (final entry in notesByOwner.entries) {
    final ownerId = entry.key;
    final noteIds = entry.value;
    
    // Firestore permite hasta 10 items en whereIn
    for (var i = 0; i < noteIds.length; i += 10) {
      final batch = noteIds.skip(i).take(10).toList();
      final snapshot = await _firestore
          .collection('users')
          .doc(ownerId)
          .collection('notes')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      
      allNotes.addAll(snapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
        'isShared': true,
        'isInSharedFolder': true,
        'ownerId': ownerId,
      }));
    }
  }
  
  return allNotes;
}
```

Esto reduce de **1 + N + (N × M)** a **1 + ceil(totalNotes / 10)** consultas.

---

## 📋 Checklist de Implementación

- [x] Crear `getSharedFolders()` en SharingService
- [x] Crear `getNotesInSharedFolder()` en SharingService
- [ ] **ARREGLAR SINTAXIS** en workspace_page.dart (URGENTE)
- [ ] Añadir `_sharedFoldersInfo` en workspace_page state
- [ ] Modificar `_loadFolders()` para incluir compartidas
- [ ] Modificar `_loadNotes()` para incluir notas de carpetas compartidas
- [ ] Modificar `_buildFolderCard()` para mostrar indicador 👥
- [ ] Deshabilitar drag-and-drop en carpetas compartidas
- [ ] Deshabilitar edición de carpetas compartidas
- [ ] Mostrar permisos en notas de carpetas compartidas
- [ ] Probar sincronización (dueño elimina → receptor ve cambio)
- [ ] Implementar optimización batch (opcional, futuro)

---

## 🐛 Problema Actual

**ARCHIVO ROTO:** `lib/notes/workspace_page.dart` tiene errores de sintaxis por modificación incompleta.

**SOLUCIÓN INMEDIATA:** 
1. Revertir cambios en `_buildFolderCard()` 
2. Mantener cambios en `_loadFolders()` y `_loadNotes()`
3. Hacer modificación simple en `_buildFolderCard()` después

**Comando para revertir:**
```bash
git checkout lib/notes/workspace_page.dart
```

Luego aplicar cambios uno por uno con cuidado.

---

**Fecha:** 2025-01-XX  
**Estado:** ⚠️ Implementación parcial con errores de sintaxis
