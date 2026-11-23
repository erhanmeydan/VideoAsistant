import Foundation

/// Uygulamanın kabul ettiği giriş türü.
enum MediaKind: Equatable {
    /// Video dosyası (ses akışı içerir).
    case video
    /// Yalnızca ses dosyası.
    case audio

    /// Desteklenen video uzantıları.
    static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]
    /// Desteklenen ses uzantıları.
    static let audioExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac", "flac", "ogg", "oga", "opus", "aiff", "aif", "wma", "caf"
    ]

    /// Dosyanın türünü uzantısından belirler; desteklenmiyorsa nil.
    static func kind(of url: URL) -> MediaKind? {
        let fileExtension = url.pathExtension.lowercased()
        if videoExtensions.contains(fileExtension) { return .video }
        if audioExtensions.contains(fileExtension) { return .audio }
        return nil
    }

    /// Kullanıcıya gösterilen biçim listesi.
    static let supportedFormatsSummary = "MP4, MOV, M4V · MP3, WAV, M4A, AAC, FLAC, OGG, OPUS, AIFF"

    /// Adım başlıklarında kullanılan kısa etiket ("video" / "ses").
    var label: String {
        switch self {
        case .video: return "video"
        case .audio: return "ses"
        }
    }
}
