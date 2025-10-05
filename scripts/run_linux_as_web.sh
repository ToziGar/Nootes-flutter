#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-5500}"
URL="http://localhost:${PORT}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter no está instalado o no está en PATH" >&2
  exit 1
fi

echo "[*] Lanzando web-server en ${URL} ..."
nohup flutter run -d web-server --web-port="${PORT}" > /tmp/flutter-web-server.log 2>&1 &
WEB_PID=$!

# Esperar a que responda
for i in $(seq 1 90); do
  if curl -sSf "${URL}" >/dev/null; then
    break
  fi
  sleep 1
done

if ! curl -sSf "${URL}" >/dev/null; then
  echo "El servidor web no inició a tiempo" >&2
  kill ${WEB_PID} || true
  exit 1
fi

echo "[*] Iniciando app de Linux apuntando a ${URL} ..."
trap 'kill ${WEB_PID} || true' EXIT
flutter run -d linux --dart-define="WEB_APP_URL=${URL}"

