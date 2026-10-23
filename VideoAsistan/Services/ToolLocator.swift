import Foundation

/// Harici araçların (ffmpeg, ffprobe, whisper-cli) ve Whisper modelinin konumunu bulur.
///
/// Finder'dan başlatılan uygulamaların PATH değişkeni minimaldir, bu yüzden
/// Homebrew ve sistem klasörleri açıkça taranır.
enum ToolLocator {
    /// Türkçe için kullanılan Whisper modeli.
    static let defaultModelFileName = "ggml-large-v3-turbo.bin"

    /// Arama sırasına konan standart ikili dosya klasörleri.
    static let binarySearchDirectories: [String] = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/opt/homebrew/sbin",
        "/usr/sbin",
        "/usr/local/sbin"
    ]

    /// Verilen adlı ikili dosyayı bulur (yoksa nil).
    static func locateBinary(named name: String) -> URL? {
        var candidates = binarySearchDirectories.map { URL(fileURLWithPath: $0).appendingPathComponent(name) }

        // PATH içindeki klasörler de sonra denenir.
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates += path.split(separator: ":").map {
                URL(fileURLWithPath: String($0)).appendingPathComponent(name)
            }
        }

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    static var ffmpeg: URL? { locateBinary(named: "ffmpeg") }
    static var ffprobe: URL? { locateBinary(named: "ffprobe") }
    static var whisperCLI: URL? { locateBinary(named: "whisper-cli") }

    /// Whisper modelinin aranacağı klasörler (öncelik sırasıyla).
    static var modelSearchDirectories: [URL] {
        [
            AppPaths.modelsDirectory,
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".cache/whisper.cpp", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew/share/whisper.cpp/models", isDirectory: true),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches/whisper.cpp", isDirectory: true)
        ]
    }

    /// Whisper model dosyasını bulur.
    static func locateModel(fileName: String = defaultModelFileName) -> URL? {
        for directory in modelSearchDirectories {
            let candidate = directory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Modelin olması gereken (ama bulunamayan) beklenen konum.
    static var expectedModelURL: URL {
        AppPaths.modelsDirectory.appendingPathComponent(defaultModelFileName)
    }

    /// Modelin indirilmesi için kullanılan komut (README ve hata mesajlarında kullanılır).
    static var modelDownloadCommand: String {
        let target = expectedModelURL.path.replacingOccurrences(of: " ", with: "\\ ")
        return "curl -L -C - -o \"\(target)\" "
            + "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(defaultModelFileName)"
    }

    /// Eksik araçlar için kullanıcıya gösterilecek Türkçe açıklama.
    static func missingToolsDescription() -> String? {
        var missing: [String] = []
        if ffmpeg == nil { missing.append("ffmpeg") }
        if ffprobe == nil { missing.append("ffprobe") }
        if whisperCLI == nil { missing.append("whisper-cli") }
        guard !missing.isEmpty else { return nil }
        return "Eksik araçlar: \(missing.joined(separator: ", ")). "
            + "Kurulum: brew install ffmpeg whisper.cpp"
    }
}
