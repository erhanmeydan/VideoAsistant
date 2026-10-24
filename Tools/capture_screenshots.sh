#!/bin/bash
#
# Uygulamanın gerçek ekran görüntülerini yakalar.
#
#   ./Tools/capture_screenshots.sh <video> <çıktı-dizini>
#
# Uygulamayı "--open <video>" ile başlatır, pencere konumunu dinamik olarak
# bulur ve işlem sırasındaki ve sonuç ekranındaki görüntüleri kaydeder.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VIDEO="${1:-$HOME/Desktop/YouTube/Test/Evde Sığır Besleyin.mp4}"
OUT="${2:-$ROOT/Resources/Screenshots}"
APP="build/Build/Products/Debug/VideoAsistant.app/Contents/MacOS/VideoAsistant"

mkdir -p "$OUT"

capture() {
  local name="$1"
  local bounds
  bounds="$(swift Tools/find_window.swift 2>/dev/null | head -1)"
  if [ -z "$bounds" ]; then
    echo "  pencere bulunamadı, atlanıyor: $name"
    return
  fi
  IFS=',' read -r x y w h <<< "$bounds"
  screencapture -x -R"$x,$y,$w,$h" "$OUT/$name.png" 2>/dev/null
  echo "  kaydedildi: $OUT/$name.png"
}

echo "==> Uygulama başlatılıyor"
pkill -f "VideoAsistant.app/Contents/MacOS/VideoAsistant" 2>/dev/null
sleep 1
"$APP" --open "$VIDEO" >/dev/null 2>&1 &
sleep 9
echo "==> İşlem ekranı"
capture "processing"

echo "==> Sonuç ekranı bekleniyor"
for _ in $(seq 1 30); do
  sleep 5
  # Sonuç ekranı token göstergesi görünür olduğunda yakalanır.
  if swift Tools/find_window.swift 2>/dev/null | grep -q "Sonuç"; then
    break
  fi
done
sleep 2
capture "results"

echo "==> Bitti"
ls -la "$OUT" | tail -5
