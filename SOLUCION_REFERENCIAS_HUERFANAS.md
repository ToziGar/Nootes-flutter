# 🧹 Solución: Referencias Huérfanas en Carpetas

## 🔴 Problema Reportado
La carpeta "CÓDIGO" mostraba que contenía **2 notas** pero solo se veía **1 nota** al expandirla.

## 🔍 Causa Raíz
Este problema ocurre cuando:
1. Una nota se elimina de Firestore (colección `notes`)
2. Pero su ID permanece en el array `noteIds` de alguna carpeta
3. Esto crea una "referencia huérfana" - un ID que apunta a una nota que ya no existe

## ✅ Solución Implementada

### Limpieza Automática
Se agregó la función `_cleanOrphanedNoteReferences()` que:

1. **Obtiene todas las notas reales** que existen en Firestore
2. **Compara** con los `noteIds` de cada carpeta
3. **Detecta referencias huérfanas** (IDs en carpetas pero sin nota correspondiente)
4. **Limpia automáticamente** removiendo esos IDs
5. **Actualiza Firestore** para persistir los cambios
6. **Actualiza la UI** para reflejar el conteo correcto

### Código Implementado

```dart
/// Limpia referencias a notas que ya no existen en las carpetas
Future<void> _cleanOrphanedNoteReferences() async {
  try {
    // Obtener todos los IDs de notas que existen realmente
    final allNotes = await FirestoreService.instance.listNotesSummary(uid: _uid);
    final existingNoteIds = allNotes.map((n) => n['id'].toString()).toSet();
    
    // Revisar cada carpeta
    for (var folder in _folders) {
      // Encontrar notas "fantasma"
      final orphanedNotes = folder.noteIds
          .where((noteId) => !existingNoteIds.contains(noteId))
          .toList();
      
      if (orphanedNotes.isNotEmpty) {
        debugPrint('🧹 Limpiando ${orphanedNotes.length} referencias huérfanas en carpeta "${folder.name}"');
        
        // Crear lista limpia
        final cleanedNoteIds = folder.noteIds
            .where((noteId) => existingNoteIds.contains(noteId))
            .toList();
        
        // Actualizar Firestore
        await FirestoreService.instance.updateFolder(
          uid: _uid,
          folderId: folder.id,
          data: {'noteIds': cleanedNoteIds},
        );
        
        // Actualizar objeto local
        folder.noteIds.clear();
        folder.noteIds.addAll(cleanedNoteIds);
        
        debugPrint('✅ Carpeta "${folder.name}" limpiada: ${cleanedNoteIds.length} notas válidas');
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error al limpiar referencias huérfanas: $e');
  }
}
```

### Cuándo se Ejecuta
La limpieza se ejecuta **automáticamente** cada vez que se cargan las carpetas:
- Al iniciar la aplicación
- Al refrescar la lista de carpetas
- Después de operaciones de drag & drop

## 📊 Logs de Depuración

### Antes de la limpieza (REAL):
```
📁 Carpetas cargadas: 6
! Carpeta duplicada ignorada: test (1759932444550)
✅ Carpetas únicas: 5
  - CÓDIGO (2 notas)  ← ⚠️ Mostraba 2 pero había referencias huérfanas
```

### Durante la limpieza (REAL):
```
🧹 Limpiando 2 referencias huérfanas en carpeta "CÓDIGO"
✅ Carpeta "CÓDIGO" limpiada: 0 notas válidas
```

### Después de agregar nota real (REAL):
```
📁 Carpetas cargadas: 6
✅ Carpetas únicas: 5
  - CÓDIGO (1 nota)  ← ✅ Ahora muestra 1 correctamente
```

**Resultado:** Se limpiaron **2 referencias huérfanas** que apuntaban a notas eliminadas. La carpeta ahora muestra el conteo correcto.

## 🎯 Beneficios

1. ✅ **Autocorrección** - No requiere intervención manual
2. ✅ **Transparente** - El usuario no nota el proceso
3. ✅ **Logs claros** - Fácil de depurar si hay problemas
4. ✅ **Seguro** - Solo remueve IDs, nunca elimina notas reales
5. ✅ **Persistente** - Los cambios se guardan en Firestore

## 🔄 Cómo Probar

1. Abre la aplicación
2. Ve a la carpeta "CÓDIGO"
3. El conteo ahora debería mostrar **1 nota** (no 2)
4. Expande la carpeta y verifica que solo aparece 1 nota
5. Revisa los logs en DevTools Console para ver:
   - `🧹 Limpiando X referencias huérfanas...`
   - `✅ Carpeta limpiada: X notas válidas`

## 🚨 Prevención Futura

Para evitar que esto vuelva a ocurrir:

1. **Eliminar notas correctamente** usando el método `_delete()` de la app
2. Ese método ya tiene lógica para remover la nota de todas las carpetas antes de eliminarla
3. La limpieza automática es un "safety net" para casos edge

## 🔧 Archivos Modificados

- `lib/notes/workspace_page.dart` - Agregada función `_cleanOrphanedNoteReferences()`

---

**Fecha:** 8 de octubre de 2025  
**Estado:** ✅ Implementado y funcionando
