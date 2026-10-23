import Foundation

/// Transkriptin tek bir zaman damgalı parçası.
struct TranscriptSegment: Identifiable, Hashable {
    /// Sıra numarası (Whisper çıktısındaki segment sırası).
    let id: Int
    /// Başlangıç zamanı (milisaniye).
    let startMS: Int
    /// Bitiş zamanı (milisaniye).
    let endMS: Int
    /// Segment metni.
    var text: String

    var durationMS: Int { max(0, endMS - startMS) }
    var startSeconds: Int { startMS / 1000 }
}
