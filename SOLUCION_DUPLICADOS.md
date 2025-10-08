# 🛠️ SOLUCIÓN FINAL - Errores Duplicate GlobalKey

## Problema Identificado

```
Duplicate keys found: [<'1759932444550'>]
Column has multiple children with key [<'1759932444550'>]
```

**Causa Raíz**: Hay **2 carpetas "test"** con el mismo ID `1759932444550` en Firestore.

## Solución Aplicada

### 1. Filtro de Carpetas Duplicadas en Código

**Archivo**: `lib/notes/workspace_page.dart` (línea 136)

```dart
Future<void> _loadFolders() async {
  try {
    final foldersData = await FirestoreService.instance.listFolders(uid: _uid);
    debugPrint('📁 Carpetas cargadas: ${foldersData.length}');
    
    // NUEVO: Eliminar duplicados por ID
    final seen = <String>{};
    final uniqueFolders = <Folder>[];
    
    for (var data in foldersData) {
      final folder = Folder.fromJson(data);
      if (!seen.contains(folder.id)) {
        seen.add(folder.id);
        uniqueFolders.add(folder);
      } else {
        debugPrint('⚠️ Carpeta duplicada ignorada: ${folder.name} (${folder.id})');
      }
    }
    
    setState(() {
      _folders = uniqueFolders;
      debugPrint('✅ Carpetas únicas: ${_folders.length}');
    });
  } catch (e) {
    debugPrint('❌ Error loading folders: $e');
    setState(() => _folders = []);
  }
}
```

### 2. Protección de Overflow en Drag & Drop

**Archivo**: `lib/widgets/workspace_widgets.dart` (línea 175)

```dart
// Antes:
Row(
  children: [
    Icon(...),
    SizedBox(width: 8),
    Expanded(child: Text(...)), // ❌ Causa overflow
  ],
)

// Ahora:
Row(
  mainAxisSize: MainAxisSize.min, // ✅ Evita overflow
  children: [
    Icon(...),
    SizedBox(width: 8),
    Flexible(child: Text(...)), // ✅ Se adapta al espacio
  ],
)
```

### 3. Keys Únicas para Notas en Carpetas

**Archivo**: `lib/notes/workspace_page.dart` (línea 756)

```dart
// Notas dentro de carpetas
...notesInFolder.map((note) {
  final id = note['id'].toString();
  return Padding(
    key: ValueKey('folder_note_${folder.id}_$id'), // ✅ Key única
    padding: const EdgeInsets.only(left: 32, bottom: 2),
    child: NotesSidebarCard(
      note: note,
      enableDrag: false, // ✅ Desactivar drag dentro de carpetas
      compact: true,
    ),
  );
}),
```

## Cómo Limpiar Firestore (Manual)

Para eliminar permanentemente las carpetas duplicadas:

### Opción 1: Firebase Console (Recomendado)

1. Ir a [Firebase Console](https://console.firebase.google.com/)
2. Seleccionar proyecto
3. Cloud Firestore → Data
4. Navegar a: `users/{uid}/folders`
5. Buscar carpetas con ID `1759932444550`
6. Eliminar los duplicados manualmente

### Opción 2: Código de Limpieza (Una sola vez)

```dart
// Agregar temporalmente en workspace_page.dart initState()
Future<void> _cleanDuplicateFolders() async {
  try {
    final foldersData = await FirestoreService.instance.listFolders(uid: _uid);
    final seen = <String, String>{}; // ID -> DocumentID
    final toDelete = <String>[];
    
    for (var data in foldersData) {
      final id = data['id'].toString();
      final docId = data['docId'].toString(); // Necesitas el document ID
      
      if (seen.containsKey(id)) {
        // Es duplicado, marcarlo para eliminar
        toDelete.add(docId);
        debugPrint('🗑️ Marcando para eliminar: $docId');
      } else {
        seen[id] = docId;
      }
    }
    
    // Eliminar duplicados
    for (var docId in toDelete) {
      await FirestoreService.instance.deleteFolder(
        uid: _uid,
        folderId: docId,
      );
      debugPrint('✅ Carpeta duplicada eliminada: $docId');
    }
    
    debugPrint('🎉 Limpieza completada: ${toDelete.length} duplicados eliminados');
  } catch (e) {
    debugPrint('❌ Error limpiando duplicados: $e');
  }
}
```

## Estado Actual

### ✅ Problemas Resueltos en Código:
1. **Filtro de duplicados**: La app ahora ignora carpetas duplicadas
2. **Keys únicas**: Cada widget tiene key única
3. **Overflow protegido**: Drag & drop no causa overflow
4. **Drag desactivado**: Notas en carpetas no se pueden arrastrar (evita bugs)

### ⚠️ Problema Pendiente en Firestore:
- **2 carpetas "test"** con mismo ID en base de datos
- **Solución temporal**: El código las filtra
- **Solución permanente**: Eliminar duplicados de Firestore

## Próximos Pasos

1. **Inmediato**: La app ya funciona con el filtro
2. **Opcional**: Limpiar Firestore manualmente (Firebase Console)
3. **Preventivo**: Agregar validación al crear carpetas:

```dart
Future<String> createFolder(...) async {
  // Verificar que no existe
  final existing = await listFolders(uid: uid);
  final ids = existing.map((f) => f['id']).toSet();
  
  // Generar ID único
  String newId;
  do {
    newId = DateTime.now().millisecondsSinceEpoch.toString();
  } while (ids.contains(newId));
  
  // Crear con ID único garantizado
  await _db.collection('users').doc(uid)
      .collection('folders').add({
    'id': newId,
    'name': name,
    // ...
  });
  
  return newId;
}
```

## Resultado Final

**Aplicación funcional** ✅  
- Carpetas duplicadas filtradas automáticamente
- Sin crashes por GlobalKey
- Sin overflow en UI
- Drag & drop funcionando correctamente

**Para eliminar duplicados permanentemente**: Usa Firebase Console o el código de limpieza

---

**Fecha**: 8 de octubre de 2025  
**Estado**: ✅ FUNCIONAL (con duplicados filtrados en memoria)  
**Acción Recomendada**: Limpiar Firestore cuando sea conveniente
