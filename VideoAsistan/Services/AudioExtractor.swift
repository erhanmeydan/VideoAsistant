import Foundation

/// ffmpeg ile videodan ses çıkarır ve video süresini ölçer.
enum AudioExtractor {
    enum ExtractionError: LocalizedError {
        case ffmpegNotFound
        case probeNotFound
        case noAudioStream
        case processFailed(String)

        var errorDescription: String? {
            switch self {
            case .ffmpegNotFound:
                return "ffmpeg bulunamadı. Kurulum: brew install ffmpeg"
            case .probeNotFound:
                return "ffprobe bulunamadı. Kurulum: brew install ffmpeg"
            case .noAudioStream:
                return "Videoda ses akışı bulunamadı."
            case .processFailed(let detail):
                return "Ses çıkarılamadı. \(detail)"
            }
        }
    }

    /// Whisper'ın beklediği biçimde (16 kHz, mono, 16-bit PCM) WAV üretir.
    static func extractAudio(
        from video: URL,
        into workDirectory: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        guard let ffmpeg = ToolLocator.ffmpeg else { throw ExtractionError.ffmpegNotFound }

        let output = workDirectory.appendingPathComponent("audio.wav")
        let duration = (try? await videoDuration(at: video)) ?? 0

        let arguments = [
            "-hide_banner",
            "-nostdin",
            "-y",
            "-i", video.path,
            "-map", "0:a:0",
            "-vn",
            "-ac", "1",
            "-ar", "16000",
            "-c:a", "pcm_s16le",
            "-progress", "pipe:1",
            "-nostats",
            output.path
        ]

        let result = try await ProcessRunner.run(
            executable: ffmpeg,
            arguments: arguments,
            toolName: "ffmpeg",
            onOutputLine: { line in
                guard let progress = Self.parseProgressLine(line, videoDuration: duration) else { return }
                onProgress?(progress)
            }
        )

        guard result.succeeded else {
            let tail = Self.tail(of: result.standardError, lines: 12)
            if tail.contains("matches no streams") || tail.contains("does not contain any stream") {
                throw ExtractionError.noAudioStream
            }
            throw ExtractionError.processFailed(tail)
        }

        guard FileManager.default.fileExists(atPath: output.path) else {
            throw ExtractionError.processFailed("Ses dosyası oluşturulamadı.")
        }
        return output
    }

    /// ffprobe ile video süresini (saniye) döndürür.
    static func videoDuration(at video: URL) async throws -> Double {
        guard let ffprobe = ToolLocator.ffprobe else { throw ExtractionError.probeNotFound }
        let result = try await ProcessRunner.run(
            executable: ffprobe,
            arguments: [
                "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=nw=1:nk=1",
                video.path
            ],
            toolName: "ffprobe"
        )
        let text = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let duration = Double(text), duration > 0 else {
            throw ExtractionError.processFailed("Video süresi okunamadı.")
        }
        return duration
    }

    /// ffmpeg `-progress` çıktısındaki `out_time_us` satırını yüzdeye çevirir.
    static func parseProgressLine(_ line: String, videoDuration: Double) -> Double? {
        guard line.hasPrefix("out_time_us=") else { return nil }
        guard let microseconds = Double(line.dropFirst("out_time_us=".count)) else { return nil }
        guard videoDuration > 0 else { return nil }
        let seconds = microseconds / 1_000_000
        return min(max(seconds / videoDuration, 0), 1)
    }

    /// Hata çıktısının son satırlarını özetler.
    static func tail(of text: String, lines: Int) -> String {
        let all = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return all.suffix(lines).joined(separator: "\n")
    }
}
