param(
  [int]$Port = 5500
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[*] $msg" }

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Comando '$name' no encontrado. Añádelo al PATH."
  }
}

Require-Command "flutter"

$Url = "http://localhost:$Port"

Write-Info "Comprobando soporte Web en Flutter..."
$devices = flutter devices | Out-String
if ($devices -notmatch "web-server") {
  Write-Warning "No se detecta 'web-server'. Habilita Web: flutter config --enable-web"
}

Write-Info "Lanzando servidor Web en $Url ..."
$webArgs = "run -d web-server --web-port=$Port"
$webProc = Start-Process -FilePath "flutter" -ArgumentList $webArgs -PassThru -WindowStyle Minimized

# Espera a que el puerto esté disponible
$maxWait = 90
$elapsed = 0
while ($true) {
  $up = Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -InformationLevel Quiet
  if ($up) { break }
  Start-Sleep -Seconds 1
  $elapsed++
  if ($elapsed -ge $maxWait) {
    try { Stop-Process -Id $webProc.Id -Force } catch { }
    throw "El servidor Web no inició en $maxWait segundos"
  }
}

Write-Info "Servidor activo. Iniciando app de Windows apuntando a $Url ..."
try {
  flutter run -d windows --dart-define="WEB_APP_URL=$Url"
} finally {
  Write-Info "Deteniendo servidor Web ..."
  try { Stop-Process -Id $webProc.Id -Force } catch { }
}

