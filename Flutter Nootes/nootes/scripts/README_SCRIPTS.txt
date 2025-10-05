Scripts para ejecutar escritorio como Web

Windows
- scripts\run_windows_as_web.ps1
  Ejecuta el servidor Web (web-server) en http://localhost:5500
  y lanza la app de Windows con WEB_APP_URL configurada.

  Uso:
    powershell -ExecutionPolicy Bypass -File scripts\run_windows_as_web.ps1
    powershell -ExecutionPolicy Bypass -File scripts\run_windows_as_web.ps1 -Port 6000

macOS
- scripts/run_macos_as_web.sh
  Uso:
    bash scripts/run_macos_as_web.sh
    PORT=6000 bash scripts/run_macos_as_web.sh

Linux
- scripts/run_linux_as_web.sh
  Uso:
    bash scripts/run_linux_as_web.sh
    PORT=6000 bash scripts/run_linux_as_web.sh

Requisitos
- Tener Web habilitado en Flutter: flutter config --enable-web
- Tener un navegador por defecto disponible
