import Foundation

/// Metin temizleme ve normalizasyon kuralları.
///
/// Kullanıcının kuralı: açıklama ve başlık metinlerinde uzun tire
/// (em dash / en dash) kullanılmaz; virgül veya ayrı cümle tercih edilir.
enum TextSanitizer {
    /// Uzun tireleri (— / –) virgüle dönüştürür.
    static func removeLongDashes(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\u{2014}", with: ", ")
        result = result.replacingOccurrences(of: "\u{2013}", with: ", ")
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: ",,", with: ",")
        result = collapseWhitespace(result)
        return result
    }

    /// Boşlukları ve satır sonlarını sadeleştirir.
    static func collapseWhitespace(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { collapseSpaces($0) }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Satır içindeki tekrarlı boşlukları tek boşluğa indirir.
    static func collapseSpaces(_ text: String) -> String {
        var result = ""
        var previousWasSpace = false
        for character in text {
            if character == " " || character == "\t" {
                if !previousWasSpace { result.append(" ") }
                previousWasSpace = true
            } else {
                result.append(character)
                previousWasSpace = false
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Segment metnini SRT'ye uygun hale getirir.
    static func cleanSegmentText(_ text: String) -> String {
        var result = collapseSpaces(text)
        result = result.replacingOccurrences(of: "[", with: "")
        result = result.replacingOccurrences(of: "]", with: "")
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " .", with: ".")
        result = result.replacingOccurrences(of: " !", with: "!")
        result = result.replacingOccurrences(of: " ?", with: "?")
        result = result.replacingOccurrences(of: " ;", with: ";")
        result = result.replacingOccurrences(of: "..", with: ".")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Metni en fazla `maxLines` satıra, satır başına en fazla `maxChars` karakterle sarar.
    static func wrapForSRT(_ text: String, maxChars: Int = 42, maxLines: Int = 2) -> String {
        let cleaned = cleanSegmentText(text)
        guard !cleaned.isEmpty else { return "" }

        var lines: [String] = []
        var current = ""

        for word in cleaned.split(separator: " ") {
            let candidate = current.isEmpty ? String(word) : current + " " + word
            if candidate.count <= maxChars {
                current = candidate
            } else {
                if !current.isEmpty { lines.append(current) }
                if lines.count == maxLines - 1 {
                    // Son satırda kalan metni olduğu gibi yaz.
                    current = String(word)
                    while current.count > maxChars { break }
                    break
                }
                current = String(word)
            }
            if lines.count == maxLines { break }
        }
        if !current.isEmpty && lines.count < maxLines { lines.append(current) }

        if lines.count == maxLines, lines.last.map({ $0.count > maxChars }) == true {
            lines[lines.count - 1] = String(lines[lines.count - 1].prefix(maxChars))
        }
        return lines.joined(separator: "\n")
    }

    /// Etiketleri temizler, yinelenenleri siler ve sayıyı sınırlar.
    static func normalizeTags(_ tags: [String], targetCount: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for rawTag in tags {
            var tag = collapseSpaces(rawTag)
            tag = tag.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?'\"()[]"))
            tag = tag.replacingOccurrences(of: "#", with: "")
            guard !tag.isEmpty else { continue }

            let key = tag.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(tag)
            if result.count == targetCount { break }
        }
        return result
    }

    /// Etiketlerin toplam uzunluğunu (virgüllerle birlikte) sınırlar.
    ///
    /// Önce etiketler kırpılır, hâlâ sınır aşılıyorsa sondaki etiketler düşürülür.
    static func limitTags(_ tags: [String], maxTotalLength: Int = 500) -> [String] {
        var result = tags

        if joinedTagLength(result) > maxTotalLength {
            result = result.map { truncate($0, to: 30) }
        }
        if joinedTagLength(result) > maxTotalLength {
            result = result.map { truncate($0, to: 20) }
        }
        while joinedTagLength(result) > maxTotalLength && result.count > 1 {
            result.removeLast()
        }
        return result
    }

    /// Virgüllerle birleştirilmiş etiket metninin uzunluğu.
    static func joinedTagLength(_ tags: [String]) -> Int {
        tags.joined(separator: ", ").count
    }

    /// Etiketleri YouTube biçiminde (virgüllü tek satır) birleştirir.
    static func joinTags(_ tags: [String]) -> String {
        tags.joined(separator: ", ")
    }

    /// Açıklamayı istenen paragraf sayısına getirir.
    static func normalizeDescription(_ text: String, minimumParagraphs: Int = 2, maximumParagraphs: Int = 3) -> String {
        var paragraphs = text
            .components(separatedBy: "\n\n")
            .map { collapseSpaces($0.replacingOccurrences(of: "\n", with: " ")) }
            .filter { !$0.isEmpty }

        guard !paragraphs.isEmpty else { return "" }

        if paragraphs.count > maximumParagraphs {
            let head = paragraphs.prefix(maximumParagraphs - 1)
            let tail = paragraphs.dropFirst(maximumParagraphs - 1).joined(separator: " ")
            paragraphs = Array(head) + [collapseSpaces(tail)]
        }

        if paragraphs.count < minimumParagraphs {
            while paragraphs.count < minimumParagraphs,
                  let longestIndex = paragraphs.indices.max(by: { paragraphs[$0].count < paragraphs[$1].count }) {
                let split = splitParagraph(paragraphs[longestIndex])
                if split.count == 2 {
                    paragraphs.remove(at: longestIndex)
                    paragraphs.insert(contentsOf: split, at: longestIndex)
                } else {
                    break
                }
            }
        }

        return paragraphs.map { removeLongDashes($0) }.joined(separator: "\n\n")
    }

    /// Başlıkları temizler ve sınırlar.
    static func normalizeTitles(_ titles: [String], targetCount: Int, maxLength: Int = 70) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for rawTitle in titles {
            var title = removeLongDashes(collapseSpaces(rawTitle))
            title = title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”"))
            guard !title.isEmpty else { continue }
            if title.count > maxLength {
                title = String(title.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
            }
            let key = title.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(title)
            if result.count == targetCount { break }
        }
        return result
    }

    private static func truncate(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)).trimmingCharacters(in: .whitespaces)
    }

    private static func splitParagraph(_ paragraph: String) -> [String] {
        let sentences = paragraph.components(separatedBy: ". ")
        guard sentences.count > 1 else { return [paragraph] }
        let midpoint = sentences.count / 2
        let first = sentences.prefix(midpoint).joined(separator: ". ")
        let second = sentences.dropFirst(midpoint).joined(separator: ". ")
        return [collapseSpaces(first), collapseSpaces(second)]
    }
}
