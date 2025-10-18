Guía rápida: ejecutar Firestore Emulator y tests SDK localmente

Objetivo
- Arrancar el Firestore Emulator localmente (Firebase CLI) y ejecutar los tests de integración que usan el SDK de Firebase (no solo REST mocks).

Resumen de pasos
1) Instalar JDK 21 (requisito para la versión actual del emulator).  
2) Arrancar el emulator con `firebase emulators:start` o ejecutar tests con `firebase emulators:exec`.  
3) Si arrancas el emulator por separado, exporta `FIRESTORE_EMULATOR_HOST` y ejecuta los tests en otra terminal.  

Requisitos mínimos
- Firebase CLI (v14+ recomendado): `firebase --version`  
- Java JDK 21+ en PATH: `java --version` debe mostrar `21.x`  
- Flutter SDK y dependencias (ya presentes si corres `flutter test`)  

Instalación de JDK 21 (Windows)
- Comprobar versión actual:
```powershell
java -version
```

- Con winget (recomendado si lo tienes):
```powershell
winget install --exact --id Eclipse.Adoptium.Temurin.21
# o
# winget install --exact --id Microsoft.OpenJDK.21
```

- Con Chocolatey (requiere PowerShell como Administrador):
```powershell
choco install temurin21jdk -y
```

- Instalación manual:
  - Descarga Temurin 21 o Microsoft OpenJDK 21 desde sus webs oficiales.
  - Ejecuta el instalador y acepta que agregue JAVA_HOME y PATH (o configúralos manualmente).

Verificar instalación
- Cierra y reabre la terminal.
- Ejecuta:
```powershell
java -version
```
Deberías ver: `openjdk version "21.0.x"` o similar.

Arrancar el emulator (opción A: control manual)
- En una terminal (A) arranca:
```powershell
firebase emulators:start --only firestore --project nootes
```
- Observa en la salida la dirección y puerto (normalmente `localhost:8080`).
- En otra terminal (B), exporta la variable y corre los tests:
```powershell
$env:FIRESTORE_EMULATOR_HOST = 'localhost:8080'
flutter test test/_integration_clean -r expanded
```

Arrancar y ejecutar tests en un solo comando (opción B: emulators:exec)
- Uso recomendado para CI o ejecuciones puntuales — evita problemas de timing y export de variables:
```powershell
# Ejecuta el emulador y dentro corre el wrapper PowerShell que ya existe en el repo
firebase emulators:exec --only firestore --project nootes -- scripts/run_emulator_tests.ps1
```
- Nota: el `scripts/run_emulator_tests.ps1` llama internamente a `flutter test test/_integration_clean -r expanded`.

Problemas comunes y soluciones
- Error: "Unsupported java version" o el emulador sale con código 1:
  - Instala JDK 21+ y reinicia la terminal.
- Error: "Emulator advertised but unreachable" o `Connection timed out`:
  - Verifica que el emulador está en ejecución y escucha en el puerto informado.
  - Firewall/antivirus puede bloquear conexiones locales; permite Java/Firebase CLI en el firewall.
  - Si el puerto ya está en uso, detén el proceso que lo ocupa o arranca el emulador con una opción para cambiar el puerto (añade `--host`/`--port` en un config avanzado o en `firebase.json` si es necesario).
- SDK tests still skip because "Firebase platform channels are unavailable":
  - Los tests con Firebase SDK usan platform channels que solo están activos en entornos de Flutter con el binding correcto; para algunos tests ejecutados con `flutter test` en modo unit, puede faltar soporte de canal. Si eso ocurre, ejecuta tests en un entorno que soporte los plugins nativos o modifica el test para usar la capa REST mocks.

Registro de logs
- El emulator escribe un log `firestore-debug.log` en el directorio del proyecto. Úsalo para diagnosticar errores del emulador.

Qué haré por ti cuando digas "listo"
- Reanudo aquí la ejecución: arrancaré el emulador y ejecutaré la suite `test/_integration_clean` (usando `emulators:exec` o el flujo manual).  
- Comprobaré que los tests que antes se saltaban por falta de emulador ahora se ejecutan y pasan.

Opciones alternativas (si no quieres cambiar Java ahora)
- Ejecutar el conjunto de tests que ya pasan (unit + integration_mocked). Estos cubren la mayor parte de la lógica (incluyendo `attachFieldTimestamps`) y son apropiados para CI.
- Ejecutar el emulator en Docker (requiere Docker instalado). Puedo preparar un `Dockerfile` / `docker-compose` si quieres intentar esa vía.

Si quieres que proceda a reintentar aquí mismo, instala JDK 21 y dime "listo"; entonces relanzaré el emulador y ejecutaré los tests de integración.
