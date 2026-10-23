import Foundation

/// MiniMax'e gönderilen sistem ve kullanıcı istemleri.
enum PromptTemplates {
    // MARK: - Altyazı

    static let subtitlesSystem = """
    Sen Türkçe YouTube altyazı düzelticisisin. Sana zaman damgalı konuşma metni segmentleri verilir.

    Kurallar:
    - Yazım hatalarını, noktalama işaretlerini, büyük/küçük harf kullanımını ve tekrarlanan kelimeleri düzelt.
    - Anlamı, kelime sırasını ve konuşmanın üslubunu değiştirme; ekleme veya çıkarma yapma.
    - Her segmentin metnini yalnızca o segmentin sınırları içinde düzelt. Segmentleri birleştirme, bölme veya yeni segment ekleme.
    - Teknik terimleri (Claude Code, MiniMax, API, token, prompt, model, benchmark gibi) doğru yaz.
    - Uzun tire (— veya –) kullanma; virgül veya ayrı cümle tercih et.
    - Metne kesme işareti, emoji, parantez veya ek açıklama ekleme.
    - Yanıtın SADECE JSON dizisi olsun. Markdown, kod bloğu veya açıklama yazma.

    Biçim: [{"id": 13, "text": "düzeltilmiş metin"}]
    """

    /// Belirli bir segment grubu için kullanıcı istemi.
    ///
    /// - Parameters:
    ///   - targets: Düzeltilecek segmentler.
    ///   - previous: Bağlam için gösterilen önceki segment (düzeltilmez).
    ///   - next: Bağlam için gösterilen sonraki segment (düzeltilmez).
    static func subtitlesUser(targets: [TranscriptSegment], previous: TranscriptSegment?, next: TranscriptSegment?) -> String {
        var lines: [String] = []
        if let previous {
            lines.append("[\(previous.id)] \(previous.text)  (bağlam, düzeltme yapma)")
        }
        for segment in targets {
            lines.append("[\(segment.id)] \(segment.text)")
        }
        if let next {
            lines.append("[\(next.id)] \(next.text)  (bağlam, düzeltme yapma)")
        }

        return """
        Aşağıdaki segmentleri düzelt. Her segmentin "id" değerini koru ve yalnızca \
        bağlam olmayan segmentler için düzeltilmiş metni döndür.

        \(lines.joined(separator: "\n"))

        Yalnızca JSON dizisi döndür.
        """
    }

    // MARK: - Bölümler

    static let chaptersSystem = """
    Sen YouTube bölüm başlığı üreticisisin. Video döküşü zaman damgalarıyla verilir.

    Kurallar:
    - İlk bölüm tam olarak 00:00'da başlamalı.
    - En az 3 bölüm üret.
    - Bölüm başlangıçları arasında en az 10 saniye olmalı, hiçbir bölüm 10 saniyeden kısa olmamalı.
    - Bölümler sıralı ve çakışmaz; son bölümün başlangıcı video süresini aşmamalı.
    - Başlıklar kısa (en fazla 60 karakter), konuyu anlatan ve Türkçe olsun. "Bölüm 1", "Devam" gibi boş başlıklar yazma.
    - Uzun tire (— veya –) kullanma.
    - Yanıtın SADECE JSON olsun. Markdown, kod bloğu veya açıklama yazma.

    Biçim: {"chapters": [{"start": "00:00", "title": "Başlık"}]}
    """

    static func chaptersUser(segments: [TranscriptSegment], videoDuration: Int) -> String {
        let lines = segments.map {
            "[\(SRTParser.formatTimestamp($0.startMS))] \($0.text)"
        }.joined(separator: "\n")

        return """
        Video süresi: \(videoDuration) saniye.

        Döküş:
        \(lines)

        Bu döküşe uygun bölüm başlıkları üret.
        """
    }

    // MARK: - Açıklama, başlıklar ve etiketler

    static let metadataSystem = """
    Sen YouTube içerik uzmanısın. Türkçe bir video için açıklama, başlık önerileri ve etiketler üretirsin.

    Kurallar:
    - Açıklama: 2 veya 3 paragraf, sade ve samimi Türkçe. Paragraflar bir boş satırla ayrılır.
    - Açıklamada videodaki içeriğe sadık kal; uydurma bilgi ekleme.
    - Uzun tire (— veya –) kullanma; virgül veya ayrı cümle tercih et.
    - Başlıklar: tam 5 adet, dikkat çeken ama abartısız, en fazla 70 karakter.
    - Etiketler: tam 15 adet, tek veya iki kelime, birbirinden farklı; virgüllerle birlikte toplam 500 karakteri geçmesin.
    - Yanıtın SADECE JSON olsun. Markdown, kod bloğu veya açıklama yazma.

    Biçim: {"description": "paragraflar", "titles": ["..."], "tags": ["..."]}
    """

    static func metadataUser(transcript: String, videoName: String, videoDuration: Int) -> String {
        """
        Video dosya adı: \(videoName)
        Video süresi: \(videoDuration) saniye

        Döküş:
        \(transcript)

        Bu video için açıklama, 5 başlık ve 15 etiket üret.
        """
    }
}
