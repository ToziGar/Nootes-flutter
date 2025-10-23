# Nootes — Aplicación de notas Offline‑First en Flutter (MVP expandido)

Este repositorio contiene Nootes, una app de toma de notas hecha en Flutter con enfoque "offline‑first": cola local de sincronización, manejo de errores (dead‑letter), y un demo que corre sin depender de Firebase.

---

## Índice

- Acerca del proyecto
- Objetivos y MVP
- Arquitectura (resumen)
- Componentes clave y contratos
- Desarrollo local (arranque rápido)
- Ejecutar la demo
- Ejecutar pruebas y analizador
- Diseño del sync (cola, backoff, dead‑letter)
- Providers y wiring (Riverpod)
- Archivos importantes
- Tareas frecuentes y comandos
- Roadmap y siguientes pasos
- Contribuir
- Solución de problemas

---

## Acerca del proyecto

Nootes es una app multiplataforma (web, móvil, escritorio) pensada para ofrecer edición de notas con sincronización segura y tolerante a fallos hacia Firestore. La rama `feature/expanded-mvp` implementa características para el MVP expandido: cola local persistente, dead‑letter, y utilidades de desarrollo.

Este README explica la estructura del proyecto, cómo ejecutar la demo sin Firebase, el diseño de sincronización y cómo contribuir.

---

## Objetivos y MVP

Objetivos principales:
- Edición local y sincronización fiable con Firestore mediante una cola local.
- Centralizar y proteger las escrituras remotas para evitar sobrescrituras cruzadas entre notas.
- Repositorio local (actualmente in‑memory; Isar planificado) con ruta de migración.
- Demo (`main_demo.dart`) para desarrollo sin credenciales de Firebase.

Criterios de éxito (ejemplos):
- Crear una nota offline → quedará en cola local → se sincroniza al reconectarse.
- Evitar que una operación incorrecta sobreescriba otras notas.
- Cola persistente en plataformas nativas (usando `SecureQueueStorage`).

---

## Arquitectura (resumen)

Capas principales:

- `domain/` — modelos de dominio (p. ej. `Note`).
- `data/` — interfaces y repositorios locales (`InMemoryNoteRepository`, plan para `IsarNoteRepository`).
- `services/` — integraciones externas y lógica de soporte (Firestore abstraction, SyncService, QueueStorage).
- `widgets/`, `pages/` — UI y páginas.
- `test/` — pruebas unitarias y de integración.

Decisiones clave:
- Uso de Riverpod (`flutter_riverpod`) para DI/estado.
- `FirestoreService` centraliza todas las operaciones remotas.
- `SyncService` gestiona la cola local, backoff y dead‑letter.

---

## Componentes clave y contratos

- `lib/domain/note.dart` — modelo `Note` con `toMap()` / `fromMap()`.
- `lib/data/note_repository.dart` — interfaz `NoteRepository`.
- `lib/services/firestore_service.dart` — abstracción para Firestore.
- `lib/services/firestore_dev.dart` — implementación en memoria para desarrollo.
- `lib/services/sync_service.dart` — cola y worker de sincronización.
- `lib/services/queue_storage.dart` — persistencia de la cola (InMemory / Secure).
- `lib/services/providers.dart` — bindings de Riverpod.

Contratos importantes: `SyncService.enqueue(note)`, `loadFromStorage()`, `start()`, `processOnce(ignoreSchedule: true)` (hook de tests), `getDeadLetter()`, `retryDeadLetter()`, `removeDeadLetter()`.

---

## Desarrollo local (arranque rápido)

Requisitos
- Flutter (canal estable recomendado) instalado.

Clonar y dependencias:

```pwsh
git clone <repo-url>
cd Nootes-flutter
flutter pub get
```

Ejecutar la demo (sin Firebase):

```pwsh
flutter run -t lib/main_demo.dart -d chrome
```

La demo usa `DevFirestoreService` (in‑memory) mediante overrides de Riverpod. Usa el FAB para encolar notas y observa la consola/terminal para ver actividad.

---

## Ejecutar pruebas y analizador

Analizar el código:

```pwsh
flutter analyze
```

Ejecutar pruebas:

```pwsh
# Todas las pruebas
flutter test

# Un fichero de prueba en concreto
flutter test test/demo_sync_integration_test.dart -r expanded
```

Las pruebas del SyncService son deterministas y usan `InMemoryQueueStorage` y `DevFirestoreService`.

---

## Diseño del sync (resumen)

`SyncService` sigue un patrón simple y robusto:

- Encolar cambios locales con `enqueue(note)`.
- Cada item es: `{ note, retries, nextAttempt }` y se persiste.
- Un worker procesa la cola periódicamente respetando `nextAttempt`.
- En fallo: backoff exponencial (1 << retries), y si supera `maxRetries` se mueve a dead‑letter.

APIs de recuperación: `retryDeadLetter(index)` para reencolar, `removeDeadLetter(index)` para descartar.

---

## Providers y wiring

`lib/services/providers.dart` exporta providers principales:
- `queueStorageProvider` — `InMemoryQueueStorage` (web) o `SecureQueueStorage` (nativo).
- `noteRepositoryProvider` — `InMemoryNoteRepository` por defecto.
- `firestoreServiceProvider` — debe ser sobreescrito en `main.dart` para producción.
- `syncServiceProvider` — crea e inicializa `SyncService` y lo detiene al disponer.

---

## Archivos importantes

- `lib/main.dart` — entrada para la app completa (producción).
- `lib/main_demo.dart` — demo para desarrollo sin Firebase.
- `lib/services/sync_service.dart` — implementa la cola y lógica de reintentos.
- `lib/services/firestore_dev.dart` — backend in‑memory para pruebas/demo.
- `test/` — contiene pruebas, por ejemplo `test/demo_sync_integration_test.dart`.

---

## Tareas frecuentes y comandos

- Ejecutar demo:

```pwsh
flutter run -t lib/main_demo.dart -d chrome
```

- Ejecutar tests rápidos:

```pwsh
flutter test test/path_to_test.dart -r expanded
```

- Ejecutar analizador:

```pwsh
flutter analyze
```

---

## Roadmap y siguientes pasos

Ver `ROADMAP.md` para detalles; puntos clave:

1. Integración de Isar para persistencia local.
2. Pruebas de integración con Firestore emulator.
3. Mejoras del editor (autosave, rich text / markdown).
4. Autenticación (Google Sign-In) y wiring de `FirestoreService` para producción.

---

## Contribuir

- Haz fork, crea rama y PR hacia `feature/expanded-mvp` (o `main` para fixes pequeños).
- Corre `flutter analyze` y tests antes de abrir PR.

---

## Solución de problemas

- Si `flutter pub get` falla, usa `flutter pub outdated` para ver incompatibilidades.
- Si tests lanzan navegador/dispositivo, asegura `TestWidgetsFlutterBinding.ensureInitialized()` en el test.

---

## Contacto

- Mantenedor: `ToziGar` (GitHub). Abre issues con pasos reproducibles y logs.

---

He creado también `README.es.md` con la misma información (archivo de copia). Si quieres, traduzco además los encabezados en `main.dart` u otros archivos que muestran textos de ayuda o `README` embebido.

