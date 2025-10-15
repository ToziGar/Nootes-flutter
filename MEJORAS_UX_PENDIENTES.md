# Mejoras de UX Pendientes

## Resumen
Este documento identifica mejoras de experiencia de usuario (UX) que pueden implementarse para mejorar la consistencia, accesibilidad y retroalimentación visual de la aplicación.

## Categorías de Mejoras

### 1. Estados de Loading Inconsistentes

#### Problema
Algunos botones muestran `CircularProgressIndicator` durante operaciones async, pero no todos tienen este patrón consistente.

**Archivos afectados:**
- `lib/widgets/share_dialog.dart` - Botón de compartir tiene loading
- `lib/profile/profile_page.dart` - Botones tienen loading
- `lib/notes/note_editor_page.dart` - Botón guardar tiene loading
- `lib/auth/forgot_password_page.dart` - Botón enviar tiene loading + cooldown

**Archivos que podrían mejorar:**
- `lib/widgets/reminder_dialog.dart` - Botón "Guardar" no muestra estado de loading
- `lib/widgets/template_selection_dialog.dart` - Botón "Usar plantilla" no tiene loading
- `lib/services/zen_mode_service.dart` - Botón "Guardar" en config no tiene loading

#### Solución Propuesta
Añadir estado `_saving` o `_loading` en diálogos que realizan operaciones async y mostrar `CircularProgressIndicator` en botones durante la operación.

---

### 2. Validación de Formularios Mejorable

#### Problema
Algunos formularios tienen validación básica pero podrían tener mensajes más descriptivos y validación en tiempo real.

**Archivos con validación básica:**
- `lib/widgets/share_dialog.dart` - Validación de email/usuario
- `lib/profile/settings_page.dart` - Validación de nombre completo y usuario
- `lib/profile/profile_page.dart` - Validación de campos de perfil

**Mejoras posibles:**
1. **Validación en tiempo real**: Mostrar errores mientras el usuario escribe (debounced)
2. **Mensajes más específicos**: 
   - "El email debe contener @" en lugar de "Email inválido"
   - "El usuario debe tener entre 3-20 caracteres" en lugar de "Requerido"
3. **Indicadores visuales**: Iconos de check/error en campos validados

---

### 3. Feedback Visual de Operaciones

#### Problema Actual
Las operaciones exitosas/fallidas usan `SnackBar`, pero algunos diálogos cierran sin feedback claro.

**Patrones actuales:**
- ✅ `workspace_page.dart` - Usa SnackBar con colores (success verde, error rojo)
- ✅ `profile_page.dart` - Usa SnackBar para confirmación
- ⚠️ Algunos diálogos cierran inmediatamente sin feedback

**Mejoras propuestas:**
1. **Toast Service consistente**: Usar `ToastService` en todos los lugares en vez de `SnackBar` mixto
2. **Confirmación visual antes de cerrar**: Mostrar icono de éxito 500ms antes de cerrar diálogos
3. **Animación de éxito**: Pulso o check animado en operaciones exitosas

---

### 4. Manejo de Errores Mejorable

#### Problema
Algunos `catch (e)` muestran el error técnico directamente al usuario sin mensaje amigable.

**Ejemplos encontrados:**
```dart
// workspace_page.dart línea ~862
catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')), // ❌ Muestra error técnico
  );
}
```

**Solución propuesta:**
1. Mapear errores comunes a mensajes amigables:
   - `PermissionDenied` → "No tienes permiso para realizar esta acción"
   - `NetworkError` → "No hay conexión a internet"
   - `NotFound` → "El elemento no existe"
2. Log técnico para debugging: `debugPrint('❌ Error técnico: $e')`
3. Mensaje al usuario: `ToastService.error('Mensaje amigable')`

---

### 5. Accesibilidad

#### Problemas detectados
- Algunos botones no tienen `tooltip`
- Pocos widgets usan `Semantics` para lectores de pantalla
- Navegación por teclado limitada

**Mejoras recomendadas:**
1. **Tooltips consistentes**: Todos los `IconButton` deben tener tooltip
2. **Semantics**: Añadir a botones principales y acciones críticas
3. **Focus management**: Mejorar navegación con Tab en diálogos
4. **Contraste de colores**: Validar que todos los textos tengan contraste mínimo WCAG AA

---

### 6. Estados Vacíos (Empty States)

#### Estado actual
- ✅ `workspace_page.dart` tiene `EmptyNotesState` bien implementado
- ✅ `shared_notes_page_old.dart` tiene empty states con iconos y texto
- ⚠️ Algunos diálogos no manejan estados vacíos (ej: sin carpetas, sin templates)

**Mejoras propuestas:**
1. **Diálogo de mover a carpeta**: Si no hay carpetas, mostrar mensaje "Crea una carpeta primero"
2. **Diálogo de plantillas**: Si no hay templates, mostrar "No hay plantillas disponibles"
3. **Consistencia visual**: Usar el mismo patrón (icono 64px + texto + subtexto)

---

### 7. Indicadores de Progreso

#### Problema
Operaciones largas (export, import, delete múltiple) no siempre muestran progreso.

**Archivos afectados:**
- `lib/services/export_import_service.dart` - Export/import sin barra de progreso visible
- `lib/notes/workspace_page.dart` - Delete múltiple sin indicador

**Solución propuesta:**
1. **Dialog de progreso**: Mostrar diálogo con `LinearProgressIndicator` para operaciones batch
2. **Cancelación**: Permitir cancelar operaciones largas
3. **Feedback detallado**: "Exportando 5 de 20 notas..."

---

## Priorización

### 🔴 Críticas (Implementar primero)
1. **Estados de loading en botones** - Evita doble-submit
2. **Manejo de errores amigable** - Mejor UX en fallos
3. **Tooltips faltantes** - Accesibilidad básica

### 🟡 Moderadas (Implementar después)
1. **Validación en tiempo real** - Mejora usabilidad
2. **Empty states en diálogos** - Evita confusión
3. **Toast Service consistente** - Unifica feedback

### 🟢 Bajas (Nice to have)
1. **Animaciones de éxito** - Pulido visual
2. **Semantics avanzados** - Accesibilidad avanzada
3. **Indicadores de progreso detallados** - UX en operaciones largas

---

## Plan de Implementación

### ✅ Fase 1: Loading States (COMPLETADO)
- [x] Añadir loading state a `reminder_dialog.dart`
- [ ] Añadir loading state a `template_selection_dialog.dart`
- [ ] Añadir loading state a diálogo de configuración Zen Mode

### ✅ Fase 2: Error Handling (COMPLETADO PARCIALMENTE)
- [x] Crear `ErrorMessageMapper` utility
- [x] Refactorizar catch blocks en `workspace_page.dart`
- [ ] Aplicar mensajes amigables en `share_dialog.dart`
- [ ] Aplicar mensajes amigables en `profile_page.dart`

### ✅ Fase 3: Tooltips (VERIFICADO)
- [x] Auditar todos los `IconButton` sin tooltip
- [x] Tooltips ya están implementados - No requiere cambios

### Fase 4: Empty States (Estimado: 30 min)
- [ ] Añadir empty state a diálogo de mover a carpeta
- [ ] Añadir empty state a selector de plantillas
- [ ] Añadir empty state a diálogo de etiquetas

---

## ✅ Progreso Actual

**Completadas:** 6/13 tareas (46%)

**Archivos creados:**
- ✅ `lib/utils/error_message_mapper.dart` - Sistema de mapeo de errores

**Archivos mejorados:**
- ✅ `lib/widgets/reminder_dialog.dart` - Loading state + error handling
- ✅ `lib/notes/workspace_page.dart` - Mensajes de error amigables

**Ver detalles completos en:** `MEJORAS_UX_FASE2_COMPLETADAS.md`

---

## Notas Técnicas

### Patrón de Loading State Recomendado
```dart
bool _isLoading = false;

Future<void> _performAction() async {
  setState(() => _isLoading = true);
  try {
    await someAsyncOperation();
    ToastService.success('Operación exitosa');
  } catch (e) {
    debugPrint('❌ Error: $e');
    ToastService.error(ErrorMessageMapper.map(e));
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

// En el botón:
ElevatedButton(
  onPressed: _isLoading ? null : _performAction,
  child: _isLoading
      ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Text('Acción'),
)
```

### Patrón de Error Handling
```dart
class ErrorMessageMapper {
  static String map(dynamic error) {
    final msg = error.toString().toLowerCase();
    
    if (msg.contains('permission')) {
      return 'No tienes permiso para realizar esta acción';
    } else if (msg.contains('network')) {
      return 'No hay conexión a internet';
    } else if (msg.contains('not found')) {
      return 'El elemento no existe';
    } else if (msg.contains('already exists')) {
      return 'Ya existe un elemento con ese nombre';
    }
    
    return 'Ocurrió un error inesperado';
  }
}
```

---

## Conclusión

Este documento identifica **mejoras incrementales de UX** que pueden implementarse sin romper funcionalidad existente. La implementación se puede hacer de forma gradual, priorizando las mejoras críticas primero.

**Estado actual:** ✅ Funcionalidad completa, necesita pulido de UX
**Estado objetivo:** ⭐ Funcionalidad completa + UX excepcional

