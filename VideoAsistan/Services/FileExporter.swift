import Foundation

/// Üretilen sonuçları videonun bulunduğu klasöre dosya olarak yazar.
enum FileExporter {
    enum ExportError: LocalizedError {
        case invalidBaseName

        var errorDescription: String? {
            switch self {
            case .invalidBaseName:
                return "Dosya adı üretilemedi."
            }
        }
    }

    /// Video dosya adından çıktı dosyaları için taban ad üretir.
    static func baseName(for video: URL) -> String {
        let raw = video.deletingPathExtension().lastPathComponent
        let invalid = CharacterSet(charactersIn: "/\\:\0")
        let cleaned = raw.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return "video" }
        return String(cleaned.prefix(80))
    }

    /// Sonuçları yazar ve yazılan dosyaların yollarını döndürür.
    @discardableResult
    static func export(_ content: GeneratedContent, nextTo video: URL) throws -> [URL] {
        let directory = video.deletingLastPathComponent()
        let base = baseName(for: video)
        var written: [URL] = []

        if !content.subtitleSegments.isEmpty {
            written.append(try write(content.srt, to: directory.appendingPathComponent("\(base)-altyazi.srt")))
        }
        if !content.chapters.isEmpty {
            written.append(try write(content.chaptersText + "\n", to: directory.appendingPathComponent("\(base)-bolumler.txt")))
        }
        if !content.description.isEmpty {
            written.append(try write(content.description + "\n", to: directory.appendingPathComponent("\(base)-aciklama.txt")))
        }
        if !content.titles.isEmpty {
            written.append(try write(content.titlesText + "\n", to: directory.appendingPathComponent("\(base)-basliklar.txt")))
        }
        if !content.tags.isEmpty {
            written.append(try write(content.tagsText + "\n", to: directory.appendingPathComponent("\(base)-etiketler.txt")))
        }

        return written
    }

    private static func write(_ content: String, to url: URL) throws -> URL {
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
