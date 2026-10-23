import Foundation

/// `--selfcheck` komutunun gövdesi.
///
/// Araçların, modelin, API anahtarının ve saf metin dönüşümlerinin doğru
/// çalıştığını doğrular; başarısız kontroller varsa sıfırdan farklı çıkış kodu döner.
enum SelfCheck {
    private static var failures = 0

    static func run(videoPath: String?) -> Int32 {
        failures = 0

        print("== VideoAsistan selfcheck ==")

        // Araçlar
        check(ToolLocator.ffmpeg != nil, "ffmpeg bulundu", ToolLocator.ffmpeg?.path ?? "bulunamadı")
        check(ToolLocator.ffprobe != nil, "ffprobe bulundu", ToolLocator.ffprobe?.path ?? "bulunamadı")
        check(ToolLocator.whisperCLI != nil, "whisper-cli bulundu", ToolLocator.whisperCLI?.path ?? "bulunamadı")

        // Whisper modeli
        if let model = ToolLocator.locateModel() {
            check(true, "Whisper modeli bulundu", model.path)
        } else {
            check(false, "Whisper modeli bulunamadı", "Beklenen konum: \(ToolLocator.expectedModelURL.path)")
            print("   Modeli indirmek için:\n   \(ToolLocator.modelDownloadCommand)")
        }

        // Dizinler
        do {
            let work = try AppPaths.ensureDirectories()
            check(true, "Çalışma dizini hazır", work.path)
        } catch {
            check(false, "Çalışma dizini oluşturulamadı", error.localizedDescription)
        }

        // API anahtarı (ortam değişkeni veya Keychain)
        let keySource = APIKeyProvider.resolveSource()
        switch keySource {
        case .environment:
            check(true, "API anahtarı ortam değişkeninde", "MINIMAX_API_KEY")
        case .keychain:
            check(true, "API anahtarı Keychain'de", "com.erhanmeydan.videoasistan")
        case .none:
            check(false, "API anahtarı bulunamadı", "MINIMAX_API_KEY tanımlayın veya uygulamadan girin")
        }

        // Video (varsa) ve saf metin dönüşümleri
        if let videoPath {
            checkVideo(at: videoPath)
        }
        checkTextTransforms()

        print("== Sonuç: \(failures == 0 ? "TÜM KONTROLLER GEÇTİ" : "\(failures) KONTROL BAŞARISIZ") ==")
        return failures == 0 ? 0 : 1
    }

    private static func checkVideo(at path: String) {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            check(false, "Video dosyası bulunamadı", path)
            return
        }
        let ext = url.pathExtension.lowercased()
        check(ext == "mp4" || ext == "mov", "Video uzantısı destekleniyor", ext)

        guard let ffprobe = ToolLocator.ffprobe else { return }
        let process = Process()
        process.executableURL = ffprobe
        process.arguments = ["-v", "error", "-show_entries", "format=duration",
                            "-of", "default=nw=1:nk=1", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let seconds = Double(text), seconds > 0 {
                check(true, "Video süresi okundu", String(format: "%.1f sn", seconds))
            } else {
                check(false, "Video süresi okunamadı", text.isEmpty ? "boş çıktı" : text)
            }
        } catch {
            check(false, "ffprobe çalıştırılamadı", error.localizedDescription)
        }
    }

    /// SRT ayrıştırma/üretme, bölüm doğrulama, tire temizliği ve etiket sınırı kontrolleri.
    private static func checkTextTransforms() {
        let sample = """
        1
        00:00:01,000 --> 00:00:04,500
        Bu bir — deneme, cümlesidir.

        2
        00:00:04,500 --> 00:00:08,000
        İkinci segment.
        """
        let segments = SRTParser.parse(sample)
        check(segments.count == 2, "SRT ayrıştırma", "\(segments.count) segment")
        check(segments.first?.startMS == 1000 && segments.last?.endMS == 8000,
              "SRT zaman damgaları doğru",
              "\(segments.map { "\($0.startMS)-\($0.endMS)" }.joined(separator: ", "))")

        let rebuilt = SRTParser.build(segments)
        check(SRTParser.parse(rebuilt).count == 2, "SRT yeniden üretimi geri okunabilir", "")
        check(rebuilt.contains("00:00:01,000 --> 00:00:04,500"), "SRT zaman biçimi korunuyor", "")

        // Bölüm doğrulama ve onarımı
        let chapters = ChapterValidator.validate(
            [Chapter(startSeconds: 0, title: "Giriş"),
             Chapter(startSeconds: 2, title: "Çok kısa"),
             Chapter(startSeconds: 900, title: "Çok geç")],
            videoDuration: 60
        )
        check(chapters.count >= 3, "Bölüm sayısı en az 3", "\(chapters.count)")
        check(chapters.first?.startSeconds == 0, "İlk bölüm 00:00", "\(chapters.first?.startSeconds ?? -1)")
        check(chapters.allSatisfy { $0.startSeconds <= 60 }, "Bölümler süreyi aşmıyor", "")
        let minGap = zip(chapters, chapters.dropFirst()).map { $1.startSeconds - $0.startSeconds }.min() ?? 0
        check(minGap >= 10, "Bölümler arası en az 10 sn", "\(minGap) sn")

        // Uzun tire temizliği
        let cleaned = TextSanitizer.removeLongDashes("Başlık — burada bitiyor ve devam ediyor")
        check(!cleaned.contains("—") && !cleaned.contains("–"), "Uzun tire temizlendi", cleaned)

        // Etiket 500 karakter sınırı
        let longTags = (1...15).map { "etiket numarası \($0) çok uzun bir etiket" }
        let limited = TextSanitizer.limitTags(longTags, maxTotalLength: 500)
        let joined = limited.joined(separator: ", ")
        check(joined.count <= 500, "Etiketler 500 karakter sınırında", "\(joined.count) karakter")
    }

    private static func check(_ condition: Bool, _ title: String, _ detail: String) {
        if condition {
            print("[OK]   \(title)\(detail.isEmpty ? "" : " — \(detail)")")
        } else {
            failures += 1
            print("[HATA] \(title)\(detail.isEmpty ? "" : " — \(detail)")")
        }
    }
}
