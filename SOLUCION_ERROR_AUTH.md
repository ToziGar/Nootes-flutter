# 🔧 Solución de Problemas - Error de Autenticación 400

## ❌ Error Detectado

```
identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=[KEY]:1
Failed to load resource: the server responded with a status of 400 ()
```

## 🔍 Causas Comunes

### 1. Usuario No Existe
El email que intentas usar no está registrado en Firebase.

**Solución**: 
- Crear una cuenta nueva usando el botón "Crear cuenta"
- O verificar que el email esté escrito correctamente

### 2. Contraseña Incorrecta
La contraseña no coincide con la registrada.

**Solución**:
- Verificar que escribiste la contraseña correctamente
- Usar "¿Olvidaste tu contraseña?" para resetearla

### 3. Usuario Deshabilitado
La cuenta fue deshabilitada en Firebase Console.

**Solución**:
1. Ir a Firebase Console
2. Authentication → Users
3. Buscar el usuario y habilitarlo

### 4. Configuración de Firebase Incompleta
Faltan configuraciones en Firebase.

**Solución**:
1. Verificar que Firebase esté inicializado:
   - `google-services.json` (Android)
   - `GoogleService-Info.plist` (iOS)
   - `firebase_options.dart` generado

2. Verificar que Authentication esté habilitado:
   - Firebase Console → Authentication
   - Sign-in method → Email/Password → Habilitado

### 5. Reglas de Seguridad Muy Restrictivas
Las reglas de Firestore bloquean el acceso.

**Solución**:
Verificar reglas en Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Permite lectura/escritura a usuarios autenticados
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## ✅ Mejoras Implementadas

He mejorado el manejo de errores en `login_page.dart` para mostrar mensajes más claros:

### Antes
```
Error: Exception: [error_code]
```

### Después
```
✅ "Email o contraseña incorrectos"
✅ "Usuario no encontrado. ¿Deseas crear una cuenta?"
✅ "Esta cuenta ha sido deshabilitada"
✅ "Demasiados intentos. Intenta más tarde"
✅ "Error de conexión. Verifica tu internet"
```

---

## 🛠️ Pasos de Verificación

### 1. Verificar Firebase Console

#### A. Authentication Habilitado
```
Firebase Console → Build → Authentication
  └─ Sign-in method
      └─ Email/Password → ✅ Enabled
```

#### B. Usuario Existe
```
Firebase Console → Authentication → Users
  └─ Buscar tu email
      └─ Estado: ✅ Enabled
```

#### C. API Key Válida
```
Firebase Console → Project Settings → General
  └─ Web API Key: AIzaSyC5J4Bqc32E6qUATwQYLdGX8TYL8FcKzrI
```

### 2. Verificar Configuración Local

#### A. firebase_options.dart
```bash
# Verificar que existe
ls lib/firebase_options.dart
```

Si no existe, regenerarlo:
```bash
flutterfire configure
```

#### B. Verificar Internet
```bash
ping 8.8.8.8
```

### 3. Crear Usuario de Prueba

Si no tienes usuario, créalo manualmente:

#### Opción 1: Desde la App
1. Click en "Crear cuenta"
2. Ingresar email y contraseña
3. Confirmar registro

#### Opción 2: Desde Firebase Console
1. Firebase Console → Authentication → Users
2. Click "Add user"
3. Ingresar:
   - Email: `test@example.com`
   - Password: `Test123456`
4. Click "Add user"

---

## 🧪 Probar la Autenticación

### Test Manual
1. Abrir la app: `flutter run -d chrome`
2. Intentar login con:
   - **Email**: `test@example.com`
   - **Password**: `Test123456`
3. Observar el mensaje de error mejorado

### Test con Usuario Nuevo
1. Click en "Crear cuenta"
2. Registrar nuevo usuario:
   - Email: tu email real
   - Password: mínimo 6 caracteres
3. Confirmar que te redirige a Home

---

## 🔐 Mejores Prácticas de Seguridad

### 1. Contraseñas Seguras
- Mínimo 8 caracteres
- Incluir mayúsculas, minúsculas, números
- Usar contraseñas únicas

### 2. Validación de Email
- Verificar formato antes de enviar
- Implementar verificación por email

### 3. Rate Limiting
Firebase ya incluye protección contra:
- Intentos de login excesivos
- Fuerza bruta
- Ataques DDoS

### 4. Multi-Factor Authentication (Opcional)
Para mayor seguridad, considera habilitar:
```
Firebase Console → Authentication → Sign-in method
  └─ Advanced → Multi-factor authentication
```

---

## 📊 Códigos de Error Comunes

| Código | Significado | Solución |
|--------|-------------|----------|
| `invalid-email` | Email mal formateado | Verificar formato |
| `wrong-password` | Contraseña incorrecta | Verificar contraseña |
| `user-not-found` | Usuario no existe | Crear cuenta |
| `user-disabled` | Cuenta deshabilitada | Contactar admin |
| `too-many-requests` | Demasiados intentos | Esperar 1 hora |
| `network-request-failed` | Sin internet | Verificar conexión |
| `invalid-credential` | Credenciales inválidas | Verificar email y password |

---

## 🎯 Solución Rápida

### Si no tienes usuario:
```bash
1. Click en "Crear cuenta"
2. Ingresar email y contraseña (mín. 6 caracteres)
3. Click "Registrarse"
```

### Si olvidaste tu contraseña:
```bash
1. Click en "¿Olvidaste tu contraseña?"
2. Ingresar tu email
3. Revisar inbox para link de reset
4. Crear nueva contraseña
```

### Si el error persiste:
```bash
1. Abrir DevTools (F12)
2. Ir a Console
3. Buscar el error completo
4. Compartir screenshot del error
```

---

## 🆘 Obtener Ayuda

### Información a Proporcionar
1. **Error completo** de la consola
2. **Screenshot** del error
3. **Pasos** que realizaste
4. **Email** que intentas usar (sin contraseña)
5. **Navegador** y versión

### Recursos
- [Firebase Auth Docs](https://firebase.google.com/docs/auth)
- [Troubleshooting Guide](https://firebase.google.com/docs/auth/web/troubleshooting)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/firebase-authentication)

---

## ✅ Checklist de Verificación

- [ ] Firebase Authentication está habilitado
- [ ] Email/Password provider está activado
- [ ] Usuario existe en Firebase Console
- [ ] Usuario está habilitado (no disabled)
- [ ] Internet funciona correctamente
- [ ] API Key es correcta
- [ ] firebase_options.dart existe
- [ ] Contraseña tiene mínimo 6 caracteres
- [ ] Email tiene formato válido

---

## 🎉 Después de Resolver

Una vez que puedas iniciar sesión:

1. ✅ Prueba crear notas
2. ✅ Prueba las nuevas funcionalidades
3. ✅ Explora el dashboard
4. ✅ Crea plantillas personalizadas

---

**Nota**: El mensaje de error ahora es más claro y te guiará mejor. Si el problema persiste, revisa los pasos anteriores.
