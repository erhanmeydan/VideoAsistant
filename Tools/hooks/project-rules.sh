#!/bin/sh
# UserPromptSubmit hook: projenin çalışma kurallarını her mesaja bağlam olarak ekler.
#
# Çıktı düz metin + çıkış kodu 0 → metin Agent'a bağlam olarak verilir.
# Girdi (stdin): hook JSON nesnesi.

cat <<'RULES'
[VideoAsistan — proje kuralları]
- Açıklama/başlık metinlerinde uzun tire (— / –) kullanma; virgül veya ayrı cümle kullan.
- API anahtarı koda gömülmez: yalnızca macOS Keychain veya MINIMAX_API_KEY ortam değişkeni.
- Altyazı zaman damgaları Whisper çıktısından gelir; model yalnızca metni düzeltir, zamanlamaya dokunmaz.
- Her çalışan adımdan sonra commit at (git add -A && git commit -m "...").
- İşlevsel değişiklikten sonra ./Tools/smoke_test.sh ile uçtan uca doğrula.
- Proje XcodeGen ile üretilir: project.yml değiştiyse xcodegen generate çalıştır.
- Tanıtım sitesi HTML'i değiştiyse ./Tools/build_site_css.sh çalıştır (derlenmiş CSS bayatlar).
RULES

exit 0
