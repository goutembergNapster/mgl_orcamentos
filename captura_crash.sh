#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
APP_ID="com.mgl.orcamento_app"
OUTDIR="./logs"
TS="$(date +'%Y-%m-%d_%H-%M-%S')"
OUTFILE="$OUTDIR/logcat_${TS}.txt"

mkdir -p "$OUTDIR"

echo "🔌 Verificando dispositivo..."
adb get-state 1>/dev/null

echo "🧹 Limpando logcat..."
adb logcat -c || true

echo "⛔ Forçando stop do app ($APP_ID)..."
adb shell am force-stop "$APP_ID" || true

echo "📝 Iniciando captura filtrada (salvando em $OUTFILE)..."
# Usamos awk para filtrar (funciona no macOS e Linux sem precisar de --line-buffered)
# Filtros: AndroidRuntime | FATAL EXCEPTION | E/flutter | nome do pacote
adb logcat -v time | awk '
  /AndroidRuntime/ || /FATAL EXCEPTION/ || /E\/flutter/ || /com\.mgl\.orcamento_app/
' | tee "$OUTFILE" &
LOGCAT_PID=$!

# Garante que o logcat encerra se o script for interrompido
cleanup() {
  echo -e "\n🧯 Encerrando captura (pid $LOGCAT_PID)..."
  kill $LOGCAT_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep 1

echo "🚀 Abrindo o app via monkey..."
adb shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1

# (Opcional) Tentar capturar o PID e mostrar um cabeçalho
sleep 1
PID="$(adb shell pidof -s "$APP_ID" 2>/dev/null || true)"
if [[ -n "${PID:-}" ]]; then
  echo "📌 PID do app: $PID"
else
  echo "⚠️  Não consegui obter o PID agora (pode ter crashado muito rápido)."
fi

echo "👀 Capturando… Reproduza o crash. Quando terminar, pressione Ctrl+C."
wait $LOGCAT_PID || true

echo "✅ Log salvo em: $OUTFILE"
