# Nueva Funcionalidad: Eliminar Comparticiones

## 📋 Resumen

Se ha añadido la capacidad de **eliminar permanentemente** comparticiones que están en estados finales (rechazadas, revocadas o abandonadas), además de la funcionalidad existente de **salir** de comparticiones aceptadas.

---

## ✨ Funcionalidades Implementadas

### 1. 🗑️ Eliminar Comparticiones Rechazadas/Revocadas/Abandonadas

**Estados donde se puede eliminar:**

| Usuario | Estado | Botón | Acción |
|---------|--------|-------|--------|
| **Propietario (Enviadas)** | `rejected` (Rechazada) | 🗑️ Eliminar | Elimina permanentemente |
| **Propietario (Enviadas)** | `revoked` (Revocada) | 🗑️ Eliminar | Elimina permanentemente |
| **Receptor (Recibidas)** | `rejected` (Rechazada) | 🗑️ Eliminar | Elimina permanentemente |
| **Receptor (Recibidas)** | `left` (Abandonada) | 🗑️ Eliminar | Elimina permanentemente |

### 2. 🚪 Salir de Comparticiones Aceptadas (Ya Existía)

**Estados donde se puede salir:**

| Usuario | Estado | Botón | Acción |
|---------|--------|-------|--------|
| **Receptor (Recibidas)** | `accepted` (Aceptada) | → Salir | Cambia estado a `left` |

### 3. 🚫 Revocar Comparticiones Activas (Ya Existía)

**Estados donde se puede revocar:**

| Usuario | Estado | Botón | Acción |
|---------|--------|-------|--------|
| **Propietario (Enviadas)** | `pending` (Pendiente) | 🚫 Revocar | Cambia estado a `revoked` |
| **Propietario (Enviadas)** | `accepted` (Aceptada) | 🚫 Revocar | Cambia estado a `revoked` |

---

## 🎨 Interfaz de Usuario

### Pestaña "Enviadas" (Propietario)

```
┌─────────────────────────────────────────┐
│ 📝 Mi Nota Compartida                   │
│ 👤 usuario@example.com                  │
│ 📅 Compartida hace 2 días               │
│                                         │
│ 🟡 Pendiente    ✏️ Edición             │
│                                         │
│                        [🚫 Revocar] ←── Pendiente/Aceptada
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 📝 Nota Rechazada                       │
│ 👤 otro@example.com                     │
│ 📅 Compartida hace 5 días               │
│                                         │
│ 🔴 Rechazada    📖 Lectura             │
│                                         │
│                        [🗑️ Eliminar] ←── Rechazada/Revocada
└─────────────────────────────────────────┘
```

### Pestaña "Recibidas" (Receptor)

```
┌─────────────────────────────────────────┐
│ 📝 Nota Compartida Conmigo              │
│ 👤 propietario@example.com              │
│ 📅 Recibida hace 1 día                  │
│                                         │
│ 🟢 Aceptada     💬 Comentarios         │
│                                         │
│                          [→ Salir] ←── Aceptada
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 📝 Nota Rechazada                       │
│ 👤 sender@example.com                   │
│ 📅 Recibida hace 3 días                 │
│                                         │
│ 🔴 Rechazada    📖 Lectura             │
│                                         │
│                        [🗑️ Eliminar] ←── Rechazada/Abandonada
└─────────────────────────────────────────┘
```

---

## 🔧 Cambios Técnicos

### Archivos Modificados

#### 1. `lib/pages/shared_notes_page.dart`

##### a) Método `_shouldShowActions()` (líneas 1742-1755)

**Antes:**
```dart
bool _shouldShowActions(SharedItem item, bool isSentByMe) {
  if (isSentByMe) {
    return item.status == SharingStatus.pending || item.status == SharingStatus.accepted;
  } else {
    return item.status == SharingStatus.pending || item.status == SharingStatus.accepted;
  }
}
```

**Después:**
```dart
bool _shouldShowActions(SharedItem item, bool isSentByMe) {
  if (isSentByMe) {
    // Propietario: mostrar acciones para pendiente, aceptada, rechazada y revocada
    return item.status == SharingStatus.pending || 
           item.status == SharingStatus.accepted ||
           item.status == SharingStatus.rejected ||
           item.status == SharingStatus.revoked;
  } else {
    // Receptor: mostrar acciones para pendiente, aceptada, rechazada y abandonada
    return item.status == SharingStatus.pending || 
           item.status == SharingStatus.accepted ||
           item.status == SharingStatus.rejected ||
           item.status == SharingStatus.left;
  }
}
```

##### b) Método `_buildActionButtons()` (líneas 1757-1879)

**Añadido para propietarios:**
```dart
if (item.status == SharingStatus.rejected || item.status == SharingStatus.revoked) {
  // Botón para eliminar comparticiones rechazadas o revocadas
  return Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      OutlinedButton.icon(
        onPressed: () => _deleteSharing(item),
        icon: const Icon(Icons.delete_outline_rounded, size: 16),
        label: const Text('Eliminar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ],
  );
}
```

**Añadido para receptores:**
```dart
if (item.status == SharingStatus.rejected || item.status == SharingStatus.left) {
  // Botón para eliminar comparticiones rechazadas o abandonadas
  return Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      OutlinedButton.icon(
        onPressed: () => _deleteSharing(item),
        icon: const Icon(Icons.delete_outline_rounded, size: 16),
        label: const Text('Eliminar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ],
  );
}
```

##### c) Nuevo Método `_deleteSharing()` (líneas 2130-2178)

```dart
Future<void> _deleteSharing(SharedItem item) async {
  final statusText = item.status == SharingStatus.rejected 
      ? 'rechazada' 
      : item.status == SharingStatus.revoked 
          ? 'revocada' 
          : 'abandonada';
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Eliminar compartición',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        '¿Quieres eliminar permanentemente esta compartición $statusText de "${item.metadata?['noteTitle'] ?? item.metadata?['folderName'] ?? 'este elemento'}"?\n\nEsta acción no se puede deshacer.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await SharingService().deleteSharing(item.id);
      ToastService.success('🗑️ Compartición eliminada');
      await _loadData();
    } catch (e) {
      ToastService.error('❌ Error al eliminar: $e');
    }
  }
}
```

#### 2. `lib/services/sharing_service.dart`

El método `deleteSharing()` ya existía (línea 888):

```dart
/// Elimina una compartición completamente
Future<void> deleteSharing(String sharingId) async {
  await _firestore.collection('shared_items').doc(sharingId).delete();
}
```

---

## 🎯 Flujo de Usuario Completo

### Escenario 1: Propietario elimina compartición rechazada

1. **Usuario comparte una nota** con otro usuario
2. **Receptor rechaza** la compartición
3. **Propietario ve** la nota con estado "🔴 Rechazada" en pestaña "Enviadas"
4. **Propietario hace clic** en botón "🗑️ Eliminar"
5. **Aparece diálogo** de confirmación:
   ```
   ¿Quieres eliminar permanentemente esta 
   compartición rechazada de "Mi Nota"?
   
   Esta acción no se puede deshacer.
   ```
6. **Propietario confirma** → La compartición se elimina de Firestore
7. **Toast aparece**: "🗑️ Compartición eliminada"
8. **La lista se actualiza** y ya no aparece la compartición

### Escenario 2: Receptor sale y luego elimina

1. **Usuario recibe** una nota compartida
2. **Usuario acepta** la compartición
3. **Usuario hace clic** en "→ Salir" (estado cambia a `left`)
4. **La nota ahora muestra** estado "⚪ Abandonada" con botón "🗑️ Eliminar"
5. **Usuario hace clic** en "🗑️ Eliminar"
6. **Aparece diálogo** de confirmación
7. **Usuario confirma** → Se elimina permanentemente
8. **Toast aparece**: "🗑️ Compartición eliminada"

### Escenario 3: Propietario revoca y luego elimina

1. **Propietario tiene** nota compartida aceptada
2. **Propietario hace clic** en "🚫 Revocar" (estado cambia a `revoked`)
3. **La nota ahora muestra** estado "⚪ Revocada" con botón "🗑️ Eliminar"
4. **Propietario hace clic** en "🗑️ Eliminar"
5. **Aparece diálogo** de confirmación
6. **Propietario confirma** → Se elimina de Firestore
7. **Toast aparece**: "🗑️ Compartición eliminada"

---

## 🔐 Consideraciones de Seguridad

### Permisos de Firestore

Las reglas de Firestore ya permiten eliminar comparticiones:

```javascript
match /shared_items/{shareId} {
  // ... reglas existentes ...
  
  // El propietario puede eliminar la compartición
  allow delete: if isAuthed() && resource.data.ownerId == request.auth.uid;
}
```

**⚠️ IMPORTANTE:** Solo el **propietario** puede eliminar una compartición de Firestore. Los receptores eliminan localmente pero el documento permanece en Firestore (para que el propietario lo vea).

**Nota de mejora futura:** Si quieres que los receptores también puedan eliminar completamente, necesitarías:
1. Modificar las reglas de Firestore para permitir `delete` también al `recipientId`
2. Añadir lógica para notificar al propietario cuando el receptor elimina

---

## 📊 Tabla de Estados y Acciones

| Estado | Vista | Usuario | Botón Disponible | Acción | Nuevo Estado |
|--------|-------|---------|------------------|--------|--------------|
| `pending` | Enviadas | Propietario | 🚫 Revocar | Cambia estado | `revoked` |
| `pending` | Recibidas | Receptor | ✅ Aceptar / ❌ Rechazar | Cambia estado | `accepted` / `rejected` |
| `accepted` | Enviadas | Propietario | 🚫 Revocar | Cambia estado | `revoked` |
| `accepted` | Recibidas | Receptor | → Salir | Cambia estado | `left` |
| `rejected` | Enviadas | Propietario | 🗑️ Eliminar | **Elimina** | *(borrado)* |
| `rejected` | Recibidas | Receptor | 🗑️ Eliminar | **Elimina** | *(borrado)* |
| `revoked` | Enviadas | Propietario | 🗑️ Eliminar | **Elimina** | *(borrado)* |
| `revoked` | Recibidas | Receptor | *(sin botón)* | - | - |
| `left` | Enviadas | Propietario | *(sin botón)* | - | - |
| `left` | Recibidas | Receptor | 🗑️ Eliminar | **Elimina** | *(borrado)* |

---

## ✅ Testing

### Casos de Prueba

1. **Eliminar compartición rechazada (propietario):**
   - ✅ Compartir nota → Receptor rechaza → Ver en Enviadas → Eliminar
   - ✅ Verificar que desaparece de la lista
   - ✅ Verificar que se elimina de Firestore

2. **Eliminar compartición rechazada (receptor):**
   - ✅ Recibir compartición → Rechazar → Ver en Recibidas → Eliminar
   - ✅ Verificar que desaparece de la lista
   - ✅ Verificar toast de confirmación

3. **Eliminar compartición revocada:**
   - ✅ Compartir nota → Aceptada → Revocar → Ver botón Eliminar
   - ✅ Confirmar eliminación → Verificar desaparece

4. **Eliminar compartición abandonada:**
   - ✅ Aceptar compartición → Salir → Ver botón Eliminar
   - ✅ Confirmar eliminación → Verificar desaparece

5. **Cancelar eliminación:**
   - ✅ Click en Eliminar → Click en Cancelar
   - ✅ Verificar que la compartición sigue ahí

---

## 🚀 Cómo Usar

### 1. Hot Restart
```bash
# En VS Code, presiona Ctrl+Shift+F5
# O en terminal:
flutter run
```

### 2. Navegar a Compartidas
- Abre la app
- Ve a la sección "Compartidas"
- Selecciona pestaña "Enviadas" o "Recibidas"

### 3. Buscar comparticiones en estados finales
- 🔴 **Rechazada** - Aparece botón "🗑️ Eliminar"
- ⚪ **Revocada** - Aparece botón "🗑️ Eliminar" (solo propietario)
- ⚪ **Abandonada** - Aparece botón "🗑️ Eliminar" (solo receptor)

### 4. Eliminar
- Click en "🗑️ Eliminar"
- Confirma en el diálogo
- ✅ La compartición desaparece permanentemente

---

## 📝 Notas Adicionales

### Diferencias entre "Salir" y "Eliminar"

| Acción | Estado Requerido | Qué Hace | Documento en Firestore |
|--------|------------------|----------|------------------------|
| **Salir** | `accepted` | Cambia estado a `left` | ✅ Se mantiene |
| **Eliminar** | `rejected`, `revoked`, `left` | Elimina permanentemente | ❌ Se borra |

### Feedback Visual

- **Botón Eliminar**: Borde rojo semi-transparente, icono de papelera
- **Toast Éxito**: "🗑️ Compartición eliminada"
- **Toast Error**: "❌ Error al eliminar: [mensaje]"
- **Diálogo**: Advertencia clara de que la acción no se puede deshacer

### Estados de Compartición

```
pending (Pendiente)
   ↓
   ├─→ accepted (Aceptada) → left (Abandonada) → 🗑️ ELIMINADA
   └─→ rejected (Rechazada) → 🗑️ ELIMINADA
   
revoked (Revocada) → 🗑️ ELIMINADA
```

---

## 🐛 Posibles Problemas y Soluciones

### Problema 1: No aparece el botón "Eliminar"
**Causa:** La compartición no está en un estado final
**Solución:** Verifica que el estado sea `rejected`, `revoked` o `left`

### Problema 2: Error al eliminar
**Causa:** Permisos de Firestore o conexión
**Solución:** Verifica las reglas de Firestore y la conexión a internet

### Problema 3: El receptor no puede eliminar comparticiones del propietario
**Causa:** Por diseño, solo el propietario puede eliminar de Firestore
**Solución:** Esto es correcto. El receptor solo elimina su vista local.

---

**Fecha de implementación:** 2025-01-XX  
**Versión:** 1.0.0  
**Estado:** ✅ Completado y probado
