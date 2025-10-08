# 🚨 Problema Detectado: Referencias a Carpetas Eliminadas

## 🔴 Problema
En los logs se observa un error recurrente:
```
❌ Error al mover nota: [cloud_firestore/not-found] No document to update: 
projects/.../folders/1759936109466
```

Este error ocurre cuando se intenta hacer drag & drop de notas a una carpeta que **ya no existe** en Firestore.

## 🔍 Diagnóstico

### Carpetas Fantasma Detectadas
- `1759936109466` ← Intenta agregar notas pero la carpeta no existe
- `1759932961343` (mencionada en errores previos)
- `1759932475598` (mencionada en errores previos)
- `1759932700395` (mencionada en errores previos)

### ¿Por qué ocurre?
1. Usuario elimina una carpeta
2. La carpeta se borra de Firestore
3. Pero la aplicación mantiene una referencia local a esa carpeta
4. Al hacer drag & drop, intenta actualizar una carpeta que ya no existe

## ⚠️ Impacto
- **Errores** al hacer drag & drop
- **Confusión** del usuario (ve carpetas que no existen)
- **Logs contaminados** con errores recurrentes

## ✅ Solución Propuesta

Similar a `_cleanOrphanedNoteReferences()`, necesitamos:

```dart
/// Limpia carpetas locales que ya no existen en Firestore
Future<void> _cleanDeletedFolders() async {
  try {
    // Obtener IDs de carpetas que existen en Firestore
    final remoteFolders = await FirestoreService.instance.listFolders(uid: _uid);
    final existingFolderIds = remoteFolders.map((f) => f.id).toSet();
    
    // Filtrar carpetas locales
    final validFolders = _folders.where((folder) => 
      existingFolderIds.contains(folder.id)
    ).toList();
    
    final removedCount = _folders.length - validFolders.length;
    if (removedCount > 0) {
      debugPrint('🧹 Removidas $removedCount carpetas eliminadas de la memoria local');
      setState(() => _folders = validFolders);
    }
  } catch (e) {
    debugPrint('⚠️ Error al limpiar carpetas eliminadas: $e');
  }
}
```

## 🎯 Beneficios Esperados
- ✅ No más errores de "folder not found"
- ✅ UI sincronizada con Firestore
- ✅ Mejor experiencia de usuario
- ✅ Logs limpios

## 📋 Estado
- ❌ **No implementado aún**
- Se recomienda implementar en próxima iteración
- Prioridad: **Media** (no rompe funcionalidad crítica pero molesta)

---

**Fecha:** 8 de octubre de 2025  
**Estado:** ⚠️ Detectado, pendiente de solución
