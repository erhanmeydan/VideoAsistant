import Foundation

/// `--smoke` komutu: tüm hattı arayüz olmadan çalıştırır.
///
/// ffmpeg → whisper.cpp → MiniMax (3 çağrı) → dosya yazımı.
enum SmokeRunner {
    static func run(sourcePath: String) async -> Int32 {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            print("HATA: Dosya bulunamadı: \(sourceURL.path)")
            return 1
        }

        if let missing = ToolLocator.missingToolsDescription() {
            print("HATA: \(missing)")
            return 1
        }
        guard ToolLocator.locateModel() != nil else {
            print("HATA: Whisper modeli bulunamadı. Beklenen: \(ToolLocator.expectedModelURL.path)")
            print("   \(ToolLocator.modelDownloadCommand)")
            return 1
        }
        guard let apiKey = try? APIKeyProvider.apiKey(), !apiKey.isEmpty else {
            print("HATA: API anahtarı bulunamadı. MINIMAX_API_KEY tanımlayın veya uygulamadan girin.")
            return 1
        }

        let start = Date()
        print("== Uçtan uca çalıştırma ==")
        print("Giriş: \(sourceURL.path)")

        do {
            let duration = Int(try await AudioExtractor.duration(of: sourceURL).rounded())
            print(String(format: "Süre: %d sn", duration))

            let workDirectory = try AppPaths.makeWorkDirectory()
            defer { try? FileManager.default.removeItem(at: workDirectory) }

            print("[1/5] Ses çıkarılıyor…")
            let audio = try await AudioExtractor.extractAudio(from: sourceURL, into: workDirectory) { progress in
                print(String(format: "      ses: %%%d", Int(progress * 100)))
            }

            print("[2/5] Yazıya çevriliyor…")
            let segments = try await Transcriber.transcribe(audio: audio, into: workDirectory) { progress in
                print(String(format: "      yazı: %%%d", Int(progress * 100)))
            }
            print("      \(segments.count) segment")

            print("[3/5] Metinler hazırlanıyor…")
            let generator = ContentGenerator(client: MiniMaxClient(apiKey: apiKey))
            let content = try await generator.generate(
                segments: segments,
                videoDuration: duration,
                sourceName: sourceURL.lastPathComponent
            ) { detail in
                print("      \(detail)")
            }

            print("[4/5] Dosyalar kaydediliyor…")
            let written = try FileExporter.export(content, nextTo: sourceURL)
            for url in written {
                print("      \(url.path)")
            }

            print("[5/5] Özet")
            print("      Token — girdi: \(content.tokenUsage.inputTokens), çıktı: \(content.tokenUsage.outputTokens), toplam: \(content.tokenUsage.totalTokens)")
            if content.tokenUsage.thinkingTokens > 0 {
                print("      (thinking: \(content.tokenUsage.thinkingTokens))")
            }
            print("      Bölümler: \(content.chapters.count) — \(content.chaptersText.prefix(120))")
            print("      Başlıklar: \(content.titles.count) — \(content.titles.first ?? "-")")
            print("      Etiketler: \(content.tags.count) — \(content.tagsForCopy.count) karakter")
            print("      Açıklama: \(content.description.split(separator: "\n\n").count) paragraf")

            // Zaman damgaları kontrolü: üretilen SRT, Whisper çıktısıyla eşleşmeli.
            let original = segments.map { "\($0.startMS)-\($0.endMS)" }
            let rebuilt = SRTParser.parse(content.srt).map { "\($0.startMS)-\($0.endMS)" }
            print("      Zaman damgaları korundu: \(original == rebuilt ? "EVET" : "HAYIR")")

            for warning in content.warnings {
                print("      Uyarı: \(warning)")
            }

            print(String(format: "== Sonuç: BAŞARILI (%.1f sn) ==", Date().timeIntervalSince(start)))
            return 0
        } catch {
            print("HATA: \(error.localizedDescription)")
            print("== Sonuç: BAŞARISIZ ==")
            return 1
        }
    }
}
