import Foundation

/// Uygulamanın işlem adımları.
enum ProcessingStep: Int, CaseIterable, Identifiable {
    case prepare
    case extractAudio
    case transcribe
    case generateText
    case saveFiles
    case done

    var id: Int { rawValue }

    /// Arayüzde gösterilen ad.
    var title: String {
        switch self {
        case .prepare: return "Video hazırlanıyor"
        case .extractAudio: return "Ses çıkarılıyor"
        case .transcribe: return "Yazıya çevriliyor"
        case .generateText: return "Metinler hazırlanıyor"
        case .saveFiles: return "Dosyalar kaydediliyor"
        case .done: return "Tamamlandı"
        }
    }

    /// Giriş türüne göre ad (ses dosyasında "çıkarma" yerine "dönüştürme" denir).
    func title(for kind: MediaKind?) -> String {
        switch (self, kind) {
        case (.prepare, .audio): return "Ses kaydı hazırlanıyor"
        case (.extractAudio, .audio): return "Ses dönüştürülüyor"
        default: return title
        }
    }

    /// Adıma ait SF Symbol.
    var symbol: String {
        switch self {
        case .prepare: return "doc.badge.gearshape"
        case .extractAudio: return "waveform"
        case .transcribe: return "captions.bubble"
        case .generateText: return "text.bubble"
        case .saveFiles: return "folder"
        case .done: return "checkmark.circle.fill"
        }
    }
}

/// Bir adımın anlık durumu.
struct ProcessingStepStatus: Identifiable {
    enum State {
        case pending
        case active
        case done
        case failed
    }

    let step: ProcessingStep
    var state: State = .pending
    var detail: String = ""
    /// 0...1 arası ilerleme; nil ise belirsiz (spinner).
    var progress: Double?
    /// İşlenen girişin türü; ad başlıklarını buna göre değiştirir.
    var mediaKind: MediaKind?

    var id: Int { step.rawValue }

    /// Ekranda gösterilecek ad.
    var displayTitle: String { step.title(for: mediaKind) }
}
