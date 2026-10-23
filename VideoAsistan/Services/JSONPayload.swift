import Foundation

/// Model yanıtından JSON gövdesini çıkarır.
///
/// Modeller bazen ```json ... ``` blokları ya da öncesi/sonrası açıklama metni
/// ekleyebiliyor. Bu yardımcı, ilk JSON nesne/dizi başlangıcından eşleşen sona
/// kadar olan bölümü güvenilir biçimde ayıklar.
enum JSONPayload {
    /// Metinden JSON nesnesi/dizisi çıkarır. Bulunamazsa nil döner.
    static func extract(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Kod bloklarını temizle.
        var cleaned = trimmed
        if let start = cleaned.range(of: "```"),
           let end = cleaned.range(of: "```", options: .backwards, range: start.upperBound..<cleaned.endIndex) {
            var block = String(cleaned[start.upperBound..<end.lowerBound])
            if let firstNewline = block.firstIndex(of: "\n") {
                let candidate = String(block[firstNewline...]).trimmingCharacters(in: .whitespaces)
                if candidate.hasPrefix("{") || candidate.hasPrefix("[") {
                    block = candidate
                }
            }
            cleaned = block.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let direct = balancedSlice(in: cleaned) {
            return direct
        }

        // Metin içinde gömülü JSON ara.
        for pair in [("{", "}"), ("[", "]")] {
            guard let openCharacter = pair.0.first,
                  let openIndex = cleaned.firstIndex(of: openCharacter) else { continue }
            let tail = String(cleaned[openIndex...])
            if let slice = balancedSlice(in: tail) {
                return slice
            }
        }
        return nil
    }

    /// Verilen metinde ilk JSON nesne/dizisinin dengeli dilimini döndürür.
    private static func balancedSlice(in text: String) -> String? {
        let characters = Array(text)
        guard let first = characters.first, first == "{" || first == "[" else { return nil }
        let closing: Character = first == "{" ? "}" : "]"

        var depth = 0
        var inString = false
        var escaped = false

        for (index, character) in characters.enumerated() {
            if escaped {
                escaped = false
                continue
            }
            if character == "\\", inString {
                escaped = true
                continue
            }
            if character == "\"" {
                inString.toggle()
                continue
            }
            if inString { continue }

            if character == first {
                depth += 1
            } else if character == closing {
                depth -= 1
                if depth == 0 {
                    return String(characters[0...index])
                }
            }
        }
        return nil
    }
}
