# VideoAsistan

Türkçe YouTube videoları için **altyazı (SRT), bölüm başlıkları, açıklama, başlık önerileri ve etiketler** üreten yerel macOS uygulaması.

Video döküşü (Whisper) tamamen **yerelde** çalışır; sadece düzeltilmiş metinler MiniMax M3.1 Flash modeline gönderilir.

## Özellikler

- Pencereye mp4/mov sürükle-bırak → ses çıkarma → Türkçe yazıya çevirme → metin üretimi
- Zaman damgaları korunmuş, yazım ve noktalama düzeltilmiş SRT
- YouTube bölüm başlıkları (ilk bölüm `00:00`, en az 3 bölüm, her bölüm en az 10 saniye)
- 2-3 paragraflık açıklama, 5 başlık önerisi, 15 etiket (virgüllerle birlikte en fazla 500 karakter)
- Her sekmede "Kopyala" düğmesi; sonuçlar videonun bulunduğu klasöre dosya olarak da yazılır
- İşlem sonunda API yanıtındaki gerçek giriş/çıktı token sayıları gösterilir

## Gereksinimler

- macOS 14 (Big Sur veya üzeri), Xcode 15+
- [Homebrew](https://brew.sh): `ffmpeg` ve `whisper.cpp`
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```bash
brew install ffmpeg whisper.cpp xcodegen
```

## Whisper modeli

Türkçe için `large-v3-turbo` modeli kullanılır (~1,6 GB):

```bash
mkdir -p ~/Library/Application\ Support/VideoAsistant/models
curl -L -C - -o ~/Library/Application\ Support/VideoAsistant/models/ggml-large-v3-turbo.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
```

## Derleme

```bash
xcodegen generate
xcodebuild -project VideoAsistant.xcodeproj -scheme VideoAsistant \
  -configuration Debug -destination 'platform=macOS,arch=arm64' build
```

## API anahtarı

MiniMax API anahtarı **koda gömülmez**. Çözümleme sırası:

1. `MINIMAX_API_KEY` ortam değişkeni (geliştirme/test için pratik)
2. macOS Keychain (`com.erhanmeydan.videoasistan` / `minimax-api-key`)
3. Yoksa uygulama ilk açılışta sorar ve Keychain'e kaydeder

## Komut satırı testleri

```bash
# Araç/model/çıktı doğrulamaları
build/Debug/VideoAsistant.app/Contents/MacOS/VideoAsistant --selfcheck "video.mp4"

# Uçtan uca çalıştırma (ffmpeg → whisper → MiniMax → dosya yazımı)
build/Debug/VideoAsistant.app/Contents/MacOS/VideoAsistant --smoke "video.mp4"
```

## Lisans

MIT
