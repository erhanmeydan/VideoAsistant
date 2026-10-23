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

    var id: Int { step.rawValue }
}
