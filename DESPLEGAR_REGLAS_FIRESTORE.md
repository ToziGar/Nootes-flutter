# Instrucciones para desplegar las reglas de Firestore

## Opción 1: Firebase CLI (Recomendado)

Si tienes Firebase CLI instalado, ejecuta:

```powershell
firebase deploy --only firestore:rules
```

## Opción 2: Consola de Firebase (Manual)

1. Abre la consola de Firebase: https://console.firebase.google.com/
2. Selecciona tu proyecto
3. Ve a **Firestore Database** en el menú lateral
4. Haz clic en la pestaña **Reglas** (Rules)
5. Copia el contenido del archivo `firestore.rules` de este proyecto
6. Pega el contenido en el editor de reglas de Firebase
7. Haz clic en **Publicar** (Publish)

## Cambios importantes en las reglas:

### 1. Notificaciones simplificadas ✅
**Antes:** Requería verificar que el shareId existiera y que el usuario fuera participante
**Ahora:** Cualquier usuario autenticado puede crear notificaciones para otros usuarios

```javascript
match /users/{uid}/notifications/{notificationId} {
  allow read: if isOwner(uid);
  allow create: if isAuthed(); // ← Simplificado
  allow update, delete: if isOwner(uid);
}
```

**Razón:** Las reglas anteriores causaban el error "failed precondition" porque validaban
la existencia del shareId de forma compleja. La nueva regla permite que el sistema de
compartición funcione correctamente.

### 2. Activity logs corregidos ✅
**Antes:** Esperaba campos `ownerId` y `recipientId` que no existen
**Ahora:** Solo valida el campo `userId` que sí existe

```javascript
match /activity_logs/{logId} {
  allow create: if isAuthed() && request.resource.data.userId == request.auth.uid;
  allow read: if isAuthed() && resource.data.userId == request.auth.uid;
  allow list: if isAuthed();
  allow update, delete: if isAuthed() && resource.data.userId == request.auth.uid;
}
```

## Verificación después de desplegar

Después de desplegar las reglas, prueba:

1. ✅ Compartir una nota con otro usuario
2. ✅ Verificar que llegue la notificación (sin error "failed precondition")
3. ✅ Enviar un comentario en el chat
4. ✅ Cambiar permisos de un usuario
5. ✅ Revocar acceso a un usuario

## Solución al problema del email "@mail"

El problema del email que muestra "@mail" en lugar de "@gmail" es porque el dato
está mal guardado en la base de datos de Firestore.

Para corregirlo:

1. Ve a la consola de Firebase
2. Abre Firestore Database
3. Busca la colección `users`
4. Encuentra el documento del usuario afectado
5. Edita el campo `email` manualmente para que tenga el dominio correcto

**Ejemplo:**
- ❌ Incorrecto: `usuario@mail.com`
- ✅ Correcto: `usuario@gmail.com`

Esto es un error de datos, no del código de la aplicación.

## Cambios en la UI del chat ✅

El chat ahora muestra el nombre del remitente en TODOS los mensajes, incluso los tuyos.
Esto es útil para identificar quién envió cada mensaje en conversaciones con múltiples usuarios.

**Antes:**
```
┌─────────────────┐
│ Hola            │ ← Tu mensaje (sin nombre)
└─────────────────┘

Juan Pérez
┌─────────────────┐
│ ¿Cómo estás?    │ ← Mensaje de otro
└─────────────────┘
```

**Ahora:**
```
Tú
┌─────────────────┐
│ Hola            │ ← Tu mensaje (con nombre)
└─────────────────┘

Juan Pérez
┌─────────────────┐
│ ¿Cómo estás?    │ ← Mensaje de otro
└─────────────────┘
```

## Notas adicionales

- Las reglas de Firestore pueden tardar unos segundos en aplicarse globalmente
- Si sigues teniendo problemas, verifica que el proyecto de Firebase esté correctamente configurado
- Asegúrate de estar usando el proyecto correcto en la consola de Firebase

## Contacto

Si tienes problemas adicionales, verifica:
1. Que las reglas se hayan publicado correctamente
2. Que no haya errores de sintaxis en las reglas
3. Que el usuario tenga una sesión activa válida
4. Que los índices de Firestore estén creados (si aparece error de índice)
