import Foundation

/// `--transcribe` komutu: ses çıkarma ve yerel yazıya çevirme adımlarını çalıştırır.
enum TranscribeRunner {
    static func run(videoPath: String) async -> Int32 {
        let videoURL = URL(fileURLWithPath: videoPath)
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("HATA: Video bulunamadı: \(videoURL.path)")
            return 1
        }

        print("== Ses çıkarma + yerel yazıya çevirme ==")
        print("Video: \(videoURL.lastPathComponent)")

        do {
            let duration = try await AudioExtractor.videoDuration(at: videoURL)
            print(String(format: "Süre: %.1f sn", duration))

            let workDirectory = try AppPaths.makeWorkDirectory()
            defer { try? FileManager.default.removeItem(at: workDirectory) }

            let audio = try await AudioExtractor.extractAudio(from: videoURL, into: workDirectory) { progress in
                let percent = Int(progress * 100)
                print("  ses çıkarma: %\(percent)")
            }
            print("Ses dosyası: \(audio.path)")

            let segments = try await Transcriber.transcribe(audio: audio, into: workDirectory) { progress in
                let percent = Int(progress * 100)
                print("  yazıya çevirme: %\(percent)")
            }

            print("Segment sayısı: \(segments.count)")
            for segment in segments.prefix(5) {
                let start = SRTParser.formatTimestamp(segment.startMS)
                let end = SRTParser.formatTimestamp(segment.endMS)
                print("  [\(start) → \(end)] \(segment.text)")
            }
            if segments.count > 5 {
                print("  … (\(segments.count - 5) segment daha)")
            }
            print("== Sonuç: BAŞARILI ==")
            return 0
        } catch {
            print("HATA: \(error.localizedDescription)")
            print("== Sonuç: BAŞARISIZ ==")
            return 1
        }
    }
}
