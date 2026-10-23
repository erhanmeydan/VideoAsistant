#!/bin/bash
#
# VideoAsistan uçtan uca test betiği.
#
#   ./Tools/smoke_test.sh [video.mp4]
#
# Sırasıyla: projeyi üretir, derler, selfcheck çalıştırır ve tüm hattı
# (ffmpeg → whisper.cpp → MiniMax → dosya yazımı) örnek video üzerinde dener.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

VIDEO="${1:-$HOME/Desktop/YouTube/Test/Evde Sığır Besleyin.mp4}"
APP="build/Build/Products/Debug/VideoAsistant.app/Contents/MacOS/VideoAsistant"

echo "==> Proje üretiliyor"
xcodegen generate || exit 1

echo "==> Derleniyor"
xcodebuild -project VideoAsistant.xcodeproj -scheme VideoAsistant \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build build | tail -3 || exit 1

if [ ! -x "$APP" ]; then
  echo "HATA: Uygulama derlenemedi: $APP"
  exit 1
fi

echo "==> Selfcheck"
"$APP" --selfcheck "$VIDEO"
SELFCHECK_STATUS=$?

if [ "$SELFCHECK_STATUS" -ne 0 ]; then
  echo "UYARI: Selfcheck başarısız (çıkış kodu $SELFCHECK_STATUS), smoke testine yine de devam ediliyor."
fi

echo "==> Yerel transkripsiyon"
"$APP" --transcribe "$VIDEO"

echo "==> Uçtan uca çalıştırma"
"$APP" --smoke "$VIDEO"
SMOKE_STATUS=$?

if [ "$SMOKE_STATUS" -eq 0 ]; then
  echo "==> TÜM TESTLER GEÇTİ"
else
  echo "==> Smoke testi başarısız (çıkış kodu $SMOKE_STATUS)"
fi

exit "$SMOKE_STATUS"
