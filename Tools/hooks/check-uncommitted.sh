#!/bin/sh
# Stop hook: çalışma bitmeden önce commit edilmemiş değişiklik var mı diye bakar.
#
# Çıkış kodu 2 → Agent bir kez daha devam eder ve stderr'ı talimat olarak alır.
# stop_hook_active=true iken çıkış kodu 0 döner (döngüsel devamı önler).
# Girdi (stdin): hook JSON nesnesi (stop_hook_active).

INPUT=$(cat)
ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)

if [ "$ACTIVE" = "true" ]; then
  exit 0
fi

PROJECT_DIR="${MINIMAX_PROJECT_DIR:-.}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

CHANGES=$(git status --porcelain 2>/dev/null)
[ -z "$CHANGES" ] && exit 0

COUNT=$(printf '%s\n' "$CHANGES" | grep -c .)
echo "Commit edilmemiş $COUNT değişiklik var. Proje kuralı gereği şimdi commit at: git add -A && git commit -m \"...\" (çalıştıktan sonra tekrar kontrol et)." >&2
exit 2
