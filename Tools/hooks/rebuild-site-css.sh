#!/bin/sh
# PostToolUse hook (edit|write): tanıtım sitesi HTML'i değiştiyse Tailwind
# CSS'ini yeniden derler. Böylece derlenmiş CSS bayatlamaz.
#
# Girdi (stdin): hook JSON nesnesi (tool_input.file_path).

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

[ -n "$FILE" ] || exit 0

case "$FILE" in
  */miniapps/video-asistan-site/miniapp/client/index.html) ;;
  *) exit 0 ;;
esac

PROJECT_DIR="${MINIMAX_PROJECT_DIR:-.}"
if [ ! -f "$PROJECT_DIR/Tools/build_site_css.sh" ]; then
  exit 0
fi

if sh "$PROJECT_DIR/Tools/build_site_css.sh" >/dev/null 2>&1; then
  echo "Tanıtım sitesi CSS'i yeniden derlendi."
else
  echo "Tanıtım sitesi CSS'i derlenemedi; ./Tools/build_site_css.sh çalıştırılmalı." >&2
fi

exit 0
