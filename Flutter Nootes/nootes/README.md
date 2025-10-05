# nootes

A new Flutter project.

## Ejecución por plataforma

- Web (recomendado para escritorio):
  - `flutter pub get`
  - `flutter run -d chrome`

- Android/iOS:
  - Configura Firebase con FlutterFire o añade los archivos nativos (`google-services.json` / `GoogleService-Info.plist`).
  - `flutter run -d android` o `flutter run -d ios`

- Windows y macOS como Web:
  - Compila/serve la versión web (por ejemplo `flutter run -d chrome` o `flutter build web` y sirve en un puerto local).
  - O usa los scripts incluidos para automatizarlo (sirven la web y lanzan el escritorio con la URL adecuada):
    - Windows: `powershell -ExecutionPolicy Bypass -File scripts\run_windows_as_web.ps1`
    - macOS: `bash scripts/run_macos_as_web.sh`
    - Linux: `bash scripts/run_linux_as_web.sh`
  - Los scripts usan el dispositivo `web-server` en el puerto 5500 y lanzan escritorio con `--dart-define=WEB_APP_URL=http://localhost:5500`.

Notas:
- En Windows y macOS la app no inicializa Firebase nativamente; se usa la versión Web.
- Ajusta `WEB_APP_URL` a tu hosting local o producción (p.ej. Firebase Hosting).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
