#!/bin/bash
#
# Uygulama ikonunu üretir: PNG master → macOS .iconset → .icns → Xcode asset kataloğu.
#
#   ./Tools/make_icon.sh
#
# Çıktılar:
#   Resources/AppIcon/icon-1024.png        (master PNG)
#   Resources/AppIcon/AppIcon.icns         (tek dosya ikon, elle kullanım için)
#   VideoAsistant/Assets.xcassets/AppIcon.appiconset/  (Xcode derlemesi için)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MASTER_DIR="Resources/AppIcon"
MASTER="$MASTER_DIR/icon-1024.png"
ICONSET="build/AppIcon.iconset"

# Kaynak klasör adı elle yazılırsa hata yapılabiliyor; git'ten türetiyoruz.
SRC_DIR="$(git ls-files | grep 'AppPaths.swift' | cut -d/ -f1)"
APPCONNECT="$SRC_DIR/Assets.xcassets/AppIcon.appiconset"

echo "==> Master PNG üretiliyor"
mkdir -p "$MASTER_DIR"
swift Tools/make_icon.swift "$MASTER_DIR"

echo "==> Boyutlar üretiliyor"
rm -rf "$ICONSET"
mkdir -p "$ICONSET" "$APPCONNECT"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$MASTER" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" "$MASTER" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

echo "==> .icns oluşturuluyor"
iconutil -c icns "$ICONSET" -o "$MASTER_DIR/AppIcon.icns"

echo "==> Asset kataloğü hazırlanıyor"
cp "$ICONSET"/*.png "$APPCONNECT/"

cat > "$APPCONNECT/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

cat > "$SRC_DIR/Assets.xcassets/Contents.json" <<'JSON'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "==> Tamamlandı"
echo "   $MASTER"
echo "   $MASTER_DIR/AppIcon.icns"
echo "   $APPCONNECT"
