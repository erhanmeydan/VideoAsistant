#!/bin/bash
#
# Tanıtım sitesinin Tailwind CSS'ini yeniden derler ve HTML'e gömer.
#
#   ./Tools/build_site_css.sh
#
# Sayfa, Tailwind CDN'ine değil burada üretilen derlenmiş CSS'e dayanır; böylece
# site dış bağımlılık olmadan, çevrimdışı da çalışır. Play CDN Tailwind v3
# kullandığı için derleme de v3 ile yapılır (görsel birebir aynı kalır).
#
# Gerekli: node + npm (yalnızca bu betik için; depo bağımlılığı yoktur)
#   npm install --no-save tailwindcss@3.4.17

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CLIENT="miniapps/video-asistan-site/miniapp/client/index.html"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

echo "==> Bağımlılık kuruluyor (geçici)"
cd "$BUILD"
npm init -y >/dev/null 2>&1
npm install --silent --no-save tailwindcss@3.4.17

cat > tailwind.config.js <<'JS'
module.exports = {
  content: ['./site/index.html'],
  theme: { extend: {} },
  plugins: []
}
JS

cat > input.css <<'CSS'
@tailwind base;
@tailwind components;
@tailwind utilities;
CSS

mkdir -p site
cp "$ROOT/$CLIENT" site/index.html

echo "==> CSS derleniyor"
npx tailwindcss -c tailwind.config.js -i input.css -o output.css --minify

echo "==> HTML'e gömülüyor"
cd "$ROOT"
python3 - "$BUILD/output.css" "$CLIENT" <<'PY'
import pathlib, re, sys

css = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").strip()
client = pathlib.Path(sys.argv[2])
s = client.read_text(encoding="utf-8")

block = re.search(
    r"[ \t]*/\* ---- tailwind:start.*?/\* ---- tailwind:end ---- \*/\n",
    s, re.S)
if not block:
    raise SystemExit("HATA: tailwind işaretleri bulunamadı")

new = (f"        /* ---- tailwind:start (Tools/build_site_css.sh ile üretilir) ---- */\n"
       f"        {css}\n"
       f"        /* ---- tailwind:end ---- */\n\n")
s = s[:block.start()] + new + s[block.end():]
client.write_text(s, encoding="utf-8")
print(f"    {len(css)} bayt CSS gömüldü")
PY

echo "==> Tamamlandı"
