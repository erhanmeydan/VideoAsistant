import Foundation

/// Üretilen tüm içerikler ve bunların token kullanımı.
struct GeneratedContent {
    /// Zaman damgaları korunmuş, düzeltilmiş altyazı segmentleri.
    var subtitleSegments: [TranscriptSegment] = []
    /// YouTube bölüm başlıkları.
    var chapters: [Chapter] = []
    /// Video açıklaması (2-3 paragraf).
    var description: String = ""
    /// 5 başlık önerisi.
    var titles: [String] = []
    /// 15 etiket.
    var tags: [String] = []
    /// Tüm API çağrılarının toplam gerçek token kullanımı.
    var tokenUsage: TokenUsage = .zero
    /// Kısmi hatalar ve uyarılar.
    var warnings: [String] = []

    var srt: String { SRTParser.build(subtitleSegments) }
    var chaptersText: String {
        chapters.map { "\($0.timestamp) \($0.title)" }.joined(separator: "\n")
    }
    var titlesText: String { titles.joined(separator: "\n") }
    var tagsText: String { tags.joined(separator: "\n") }
    /// Panoya kopyalanacak etiket metni (virgüllü tek satır).
    var tagsForCopy: String { TextSanitizer.joinTags(tags) }
}
