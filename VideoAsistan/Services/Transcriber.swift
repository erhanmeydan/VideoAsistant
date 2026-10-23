import Foundation

/// whisper.cpp ile (yerel, internetsiz) Türkçe yazıya çevirme yapar.
enum Transcriber {
    /// Kanalın teknik terimlerini Whisper'a ön ipucu olarak verir; Türkçe
    /// yazım/terim eğilimini iyileştirir.
    static let prompt = "Yapay zeka, Claude, Claude Code, MiniMax, OpenAI, Gemini, agent, token, API, GitHub, prompt, model, benchmark."

    /// Segment başına azami karakter sayısı (YouTube altyazı satırına uygun).
    static let maxSegmentCharacters = 80

    enum TranscriptionError: LocalizedError {
        case whisperNotFound
        case modelNotFound(expected: String)
        case processFailed(String)
        case emptyTranscript

        var errorDescription: String? {
            switch self {
            case .whisperNotFound:
                return "whisper-cli bulunamadı. Kurulum: brew install whisper.cpp"
            case .modelNotFound(let expected):
                return "Whisper modeli bulunamadı: \(expected)\n"
                    + "Modeli indirmek için:\n\(ToolLocator.modelDownloadCommand)"
            case .processFailed(let detail):
                return "Yazıya çevirme başarısız. \(detail)"
            case .emptyTranscript:
                return "Videodan konuşma algılanmadı."
            }
        }
    }

    /// Sesi Türkçeye çevirir ve zaman damgalı segmentleri döndürür.
    static func transcribe(
        audio: URL,
        into workDirectory: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [TranscriptSegment] {
        guard let whisper = ToolLocator.whisperCLI else { throw TranscriptionError.whisperNotFound }
        guard let model = ToolLocator.locateModel() else {
            throw TranscriptionError.modelNotFound(expected: ToolLocator.expectedModelURL.path)
        }

        let outputBase = workDirectory.appendingPathComponent("transcript").path
        let threads = max(2, min(ProcessInfo.processInfo.activeProcessorCount, 8))

        // `-ml` ile segmentler YouTube altyazı satırına uygun uzunlukta parçalara
        // bölünür; bölme işlemini Whisper yapar, böylece zaman damgaları yine
        // Whisper'ın kendi çıktısından gelir.
        let arguments = [
            "-m", model.path,
            "-f", audio.path,
            "-l", "tr",
            "-osrt",
            "-of", outputBase,
            "-pp",
            "-np",
            "-t", String(threads),
            "-ml", String(Self.maxSegmentCharacters),
            "-sow",
            "--prompt", prompt
        ]

        let result = try await ProcessRunner.run(
            executable: whisper,
            arguments: arguments,
            toolName: "whisper-cli",
            onErrorLine: { line in
                guard let progress = Self.parseProgressLine(line) else { return }
                onProgress?(progress)
            }
        )

        guard result.succeeded else {
            throw TranscriptionError.processFailed(AudioExtractor.tail(of: result.standardError, lines: 12))
        }

        let srtURL = URL(fileURLWithPath: outputBase + ".srt")
        guard let content = try? String(contentsOf: srtURL, encoding: .utf8) else {
            throw TranscriptionError.processFailed("Çıktı SRT dosyası okunamadı.")
        }

        let segments = SRTParser.parse(content)
        guard !segments.isEmpty else { throw TranscriptionError.emptyTranscript }
        return segments
    }

    /// whisper stderr'ındaki `progress = 42%` satırını 0...1 oranına çevirir.
    static func parseProgressLine(_ line: String) -> Double? {
        guard let range = line.range(of: #"progress\s*=\s*(\d+)%"#, options: .regularExpression) else {
            return nil
        }
        let value = line[range]
        guard let percent = Double(value.replacingOccurrences(of: "%", with: "")
            .components(separatedBy: "=").last ?? "") else { return nil }
        return min(max(percent / 100.0, 0), 1)
    }
}
