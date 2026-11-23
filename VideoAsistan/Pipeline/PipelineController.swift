import Foundation
import Observation

/// Tüm iş akışını yöneten tek durum sahibi.
///
/// Arayüz yalnızca bu nesneyi okur; ağır işler (ffmpeg, whisper, API) arka planda
/// çalışır ve ilerleme bilgisi buraya aktarılır.
@MainActor
@Observable
final class PipelineController {
    enum Phase {
        case idle
        case processing
        case results
        case failed
    }

    private(set) var phase: Phase = .idle
    private(set) var steps: [ProcessingStepStatus] = ProcessingStep.allCases.map { ProcessingStepStatus(step: $0) }
    private(set) var content: GeneratedContent?
    private(set) var tokenUsage: TokenUsage = .zero
    private(set) var errorMessage: String?
    private(set) var warnings: [String] = []
    private(set) var writtenFiles: [URL] = []
    private(set) var inputURL: URL?
    private(set) var inputKind: MediaKind?
    private(set) var durationSeconds: Int = 0

    var isAPIKeySheetPresented = false
    var isDragTargeted = false

    private var task: Task<Void, Never>?
    private var pendingInputURL: URL?

    // MARK: - Giriş

    /// Bırakılan veya seçilen video/ses dosyası için işlemi başlatır.
    func start(with url: URL) {
        guard let kind = MediaKind.kind(of: url) else {
            errorMessage = "Yalnızca video (MP4, MOV, M4V) ve ses (MP3, WAV, M4A, AAC, FLAC, OGG) dosyaları desteklenir."
            phase = .failed
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = kind == .audio ? "Ses dosyası bulunamadı." : "Video dosyası bulunamadı."
            phase = .failed
            return
        }

        do {
            guard let apiKey = try APIKeyProvider.apiKey(), !apiKey.isEmpty else {
                pendingInputURL = url
                isAPIKeySheetPresented = true
                return
            }
            begin(with: url, kind: kind, apiKey: apiKey)
        } catch {
            pendingInputURL = url
            isAPIKeySheetPresented = true
        }
    }

    /// API anahtarını kaydeder ve bekleyen işlemi başlatır.
    func saveAPIKey(_ key: String) -> String? {
        do {
            try APIKeyProvider.store(key)
            isAPIKeySheetPresented = false
            if let pending = pendingInputURL {
                pendingInputURL = nil
                let kind = MediaKind.kind(of: pending) ?? .video
                begin(with: pending, kind: kind, apiKey: key)
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Anahtar gerektiği hâlde kullanıcı iptal ederse bekleyen dosyayı unut.
    func cancelAPIKeyRequest() {
        isAPIKeySheetPresented = false
        pendingInputURL = nil
    }

    /// Uygulama ilk açılışta anahtar yoksa kullanıcıdan ister.
    func requestAPIKeyIfNeeded() {
        guard !isAPIKeySheetPresented else { return }
        let source = APIKeyProvider.resolveSource()
        if source == .none {
            isAPIKeySheetPresented = true
        }
    }

    // MARK: - Akış

    private func begin(with url: URL, kind: MediaKind, apiKey: String) {
        task?.cancel()
        inputURL = url
        inputKind = kind
        content = nil
        tokenUsage = .zero
        errorMessage = nil
        warnings = []
        writtenFiles = []
        durationSeconds = 0
        steps = ProcessingStep.allCases.map { step in
            var status = ProcessingStepStatus(step: step)
            status.mediaKind = kind
            return status
        }
        phase = .processing

        task = Task { [weak self] in
            await self?.run(source: url, kind: kind, apiKey: apiKey)
        }
    }

    private func run(source url: URL, kind: MediaKind, apiKey: String) async {
        do {
            // 1) Hazırlık
            update(.prepare, state: .active, detail: "Araçlar kontrol ediliyor")
            if let missing = ToolLocator.missingToolsDescription() {
                throw PipelineError.message(missing)
            }
            guard ToolLocator.locateModel() != nil else {
                throw PipelineError.message(
                    "Whisper modeli bulunamadı: \(ToolLocator.expectedModelURL.path)\n\(ToolLocator.modelDownloadCommand)"
                )
            }
            let duration = Int((try await AudioExtractor.duration(of: url)).rounded())
            durationSeconds = duration
            update(.prepare, state: .done, detail: String(format: "%.0f saniyelik %@", Double(duration), kind.label))

            // 2) Ses çıkarma / dönüştürme
            update(.extractAudio, state: .active, detail: "ffmpeg çalışıyor")
            let workDirectory = try AppPaths.makeWorkDirectory()
            defer { try? FileManager.default.removeItem(at: workDirectory) }
            let audio = try await AudioExtractor.extractAudio(from: url, into: workDirectory) { [weak self] progress in
                Task { @MainActor in
                    self?.update(.extractAudio, state: .active, detail: kind == .audio ? "Ses dönüştürülüyor" : "Ses çıkarılıyor", progress: progress)
                }
            }
            update(.extractAudio, state: .done, detail: kind == .audio ? "Ses hazır" : "Ses hazır")

            // 3) Yazıya çevirme
            update(.transcribe, state: .active, detail: "Yerel yapay zekâ modeli çalışıyor")
            let segments = try await Transcriber.transcribe(audio: audio, into: workDirectory) { [weak self] progress in
                Task { @MainActor in
                    self?.update(.transcribe, state: .active, detail: "Yazıya çevriliyor", progress: progress)
                }
            }
            update(.transcribe, state: .done, detail: "\(segments.count) segment")

            // 4) Metinler
            update(.generateText, state: .active, detail: "MiniMax'e gönderiliyor")
            let generator = ContentGenerator(client: MiniMaxClient(apiKey: apiKey))
            let generated = try await generator.generate(
                segments: segments,
                videoDuration: duration,
                sourceName: url.lastPathComponent
            ) { [weak self] detail in
                Task { @MainActor in
                    self?.update(.generateText, state: .active, detail: detail)
                }
            }
            content = generated
            tokenUsage = generated.tokenUsage
            warnings = generated.warnings
            update(.generateText, state: .done, detail: "Metinler hazır")

            // 5) Dosyalar
            update(.saveFiles, state: .active, detail: "Dosyanın klasörüne yazılıyor")
            do {
                writtenFiles = try FileExporter.export(generated, nextTo: url)
                update(.saveFiles, state: .done, detail: "\(writtenFiles.count) dosya kaydedildi")
            } catch {
                update(.saveFiles, state: .done, detail: "Dosyalar kaydedilemedi")
                warnings.append("Dosyalar kaydedilemedi: \(error.localizedDescription)")
            }

            update(.done, state: .done, detail: "")
            phase = .results
        } catch {
            fail(with: error)
        }
    }

    private func fail(with error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        errorMessage = message
        if let active = steps.first(where: { $0.state == .active }) {
            update(active.step, state: .failed, detail: message)
        }
        phase = .failed
    }

    /// Başarısız bir işlemden sonra aynı dosyayı tekrar dener.
    func retry() {
        guard let url = inputURL else { return }
        start(with: url)
    }

    /// Sonuçları temizleyip boş hâle döner.
    func reset() {
        task?.cancel()
        task = nil
        phase = .idle
        inputURL = nil
        inputKind = nil
        content = nil
        tokenUsage = .zero
        errorMessage = nil
        warnings = []
        writtenFiles = []
        durationSeconds = 0
        steps = ProcessingStep.allCases.map { ProcessingStepStatus(step: $0) }
    }

    // MARK: - Yardımcılar

    private func update(_ step: ProcessingStep, state: ProcessingStepStatus.State, detail: String, progress: Double? = nil) {
        guard let index = steps.firstIndex(where: { $0.step == step }) else { return }
        steps[index].state = state
        steps[index].detail = detail
        if let progress {
            steps[index].progress = progress
        } else if state != .active {
            steps[index].progress = nil
        }
    }
}

enum PipelineError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text):
            return text
        }
    }
}
