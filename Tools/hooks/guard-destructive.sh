#!/bin/sh
# PreToolUse hook (bash): geri döndürülemez komutları durdurur.
#
# Çıkış kodu 2 → komut engellenir, stderr mesajı Agent'a sebep olarak gider.
# Girdi (stdin): hook JSON nesnesi (tool_input.command).

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[ -n "$COMMAND" ] || exit 0

case "$COMMAND" in
  *"git push --force"*|*"git push -f"*|*"git reset --hard"*|*"git clean -fd"*)
    echo "Bu komut depoyu geri döndürülemez biçimde değiştirir ve açık kaynak bir depoda kullanılmaz. Önce kullanıcıya sor." >&2
    exit 2
    ;;
esac

case "$COMMAND" in
  *"rm"*ggml-large-v3-turbo.bin*)
    echo "Whisper modeli silinmez (yeniden indirmek 1,6 GB). Önce kullanıcıya sor." >&2
    exit 2
    ;;
esac

exit 0
