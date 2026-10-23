import Foundation

/// SRT dosyalarını ayrıştırır ve yeniden üretir.
///
/// Zaman damgaları korunması gereken en kritik veri olduğu için, SRT üretimi
/// daima mevcut segmentlerin zamanlarını kullanır; metinler değiştirilse bile
/// zamanlama yerinde kalır.
enum SRTParser {
    /// SRT içeriğini segmentlere ayrıştırır.
    static func parse(_ content: String) -> [TranscriptSegment] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let blocks = normalized.components(separatedBy: "\n\n")
        var segments: [TranscriptSegment] = []

        for block in blocks {
            let lines = block
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard !lines.isEmpty else { continue }

            guard let timeLineIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let timeLine = lines[timeLineIndex]
            let parts = timeLine.components(separatedBy: "-->")
            guard parts.count == 2,
                  let start = parseTimestamp(parts[0]),
                  let end = parseTimestamp(parts[1]) else { continue }

            let text = lines.dropFirst(timeLineIndex + 1).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            segments.append(TranscriptSegment(id: segments.count, startMS: start, endMS: end, text: text))
        }

        return segments
    }

    /// Segmentlerden standart SRT metni üretir.
    static func build(_ segments: [TranscriptSegment]) -> String {
        var blocks: [String] = []
        for (index, segment) in segments.enumerated() {
            let text = TextSanitizer.wrapForSRT(segment.text)
            guard !text.isEmpty else { continue }
            blocks.append(
                "\(index + 1)\n"
                    + "\(formatTimestamp(segment.startMS)) --> \(formatTimestamp(segment.endMS))\n"
                    + text
            )
        }
        return blocks.joined(separator: "\n\n") + (blocks.isEmpty ? "" : "\n")
    }

    /// `HH:MM:SS,mmm` biçiminde zaman damgası.
    static func formatTimestamp(_ milliseconds: Int) -> String {
        let totalSeconds = max(0, milliseconds) / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let millis = max(0, milliseconds) % 1000
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, millis)
    }

    /// `HH:MM:SS,mmm` (veya `HH:MM:SS.mmm`) biçimini milisaniyeye çevirir.
    static func parseTimestamp(_ raw: String) -> Int? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let parts = cleaned.split(separator: ":")
        guard parts.count == 3 else { return nil }

        guard let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else { return nil }

        let secondsPart = parts[2]
        let secondValues = secondsPart.split(separator: ".")
        guard let seconds = Int(secondValues[0]) else { return nil }
        let millis = secondValues.count > 1 ? (Int(secondValues[1].prefix(3).padding(toLength: 3, withPad: "0", startingAt: 0)) ?? 0) : 0

        return hours * 3_600_000 + minutes * 60_000 + seconds * 1000 + millis
    }
}
