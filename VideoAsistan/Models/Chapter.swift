import Foundation

/// YouTube bölüm başlığı.
struct Chapter: Identifiable, Hashable {
    var id: String { "\(startSeconds)-\(title)" }
    /// Bölümün başladığı saniye.
    var startSeconds: Int
    /// Bölüm başlığı.
    var title: String

    /// YouTube biçiminde zaman damgası: `MM:SS` (saat varsa `H:MM:SS`).
    var timestamp: String {
        let hours = startSeconds / 3600
        let minutes = (startSeconds % 3600) / 60
        let seconds = startSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
