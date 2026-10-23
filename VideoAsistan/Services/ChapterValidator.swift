import Foundation

/// Bölüm başlıklarını YouTube kurallarına uydurur ve onarır.
///
/// Kurallar: ilk bölüm 00:00'da başlar, en az 3 bölüm vardır, her bölüm en az
/// 10 saniye aralıkla başlar, bölümler sıralıdır ve video süresini aşmaz.
enum ChapterValidator {
    static let minimumChapterCount = 3
    static let minimumChapterLength = 10

    /// Gelen bölümleri doğrular, kurallara uymayanları onarır.
    static func validate(_ chapters: [Chapter], videoDuration: Int) -> [Chapter] {
        let duration = max(videoDuration, 0)
        var result = chapters
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.startSeconds < $1.startSeconds }

        // Sürenin dışına taşan başlangıçları kırp.
        for index in result.indices {
            result[index].startSeconds = min(max(0, result[index].startSeconds), duration)
        }

        // İlk bölüm daima 00:00.
        if !result.isEmpty {
            result[0].startSeconds = 0
        }

        // Bölümler arası en az 10 saniye olmalı.
        if result.count > 1 {
            for index in 1..<result.count {
                let minimum = result[index - 1].startSeconds + minimumChapterLength
                result[index].startSeconds = max(result[index].startSeconds, minimum)
            }
        }

        // Süreyi aşan bölümleri at.
        result = result.filter { $0.startSeconds <= duration }

        // En az 3 bölüm kuralı.
        if result.count < minimumChapterCount {
            result = expand(result, target: minimumChapterCount, videoDuration: duration)
        }

        return result
    }

    /// Bölüm sayısı yetersizse aralıkları eşit bölerek tamamlar.
    private static func expand(_ chapters: [Chapter], target: Int, videoDuration: Int) -> [Chapter] {
        guard !chapters.isEmpty else { return [] }
        let step = max(minimumChapterLength, videoDuration / max(target, 1))
        var expanded: [Chapter] = []
        for index in 0..<target {
            let start = min(index * step, videoDuration)
            let title = chapters.last(where: { $0.startSeconds <= start })?.title ?? chapters[0].title
            expanded.append(Chapter(startSeconds: start, title: title))
        }
        // Aynı başlangıçları tekrarlama.
        var unique: [Chapter] = []
        for chapter in expanded where !unique.contains(where: { $0.startSeconds == chapter.startSeconds }) {
            unique.append(chapter)
        }
        return unique
    }

    /// Model çıktısı bozulursa kullanılacak yedek bölümler.
    static func fallbackChapters(segments: [TranscriptSegment], videoDuration: Int) -> [Chapter] {
        let duration = max(videoDuration, 0)
        let count = max(minimumChapterCount, Int(Double(duration) / 60.0))
        let step = max(minimumChapterLength, duration / max(count, 1))
        var chapters: [Chapter] = []
        for index in 0..<count {
            let start = min(index * step, duration)
            let title = segments.first(where: { $0.startSeconds >= start })
                .map { $0.text.split(separator: " ").prefix(6).joined(separator: " ") }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
            chapters.append(Chapter(startSeconds: start, title: title.isEmpty ? "Bölüm \(index + 1)" : title))
        }
        return validate(chapters, videoDuration: duration)
    }
}
