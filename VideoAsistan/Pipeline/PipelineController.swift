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
    private(set) var videoURL: URL?
    private(set) var videoDurationSeconds: Int = 0

    var isAPIKeySheetPresented = false
    var isDragTargeted = false

    private var task: Task<Void, Never>?
    private var pendingVideoURL: URL?

    // MARK: - Giriş

    /// Bırakılan veya seçilen video için işlemi başlatır.
    func start(with url: URL) {
        let fileExtension = url.pathExtension.lowercased()
        guard fileExtension == "mp4" || fileExtension == "mov" else {
            errorMessage = "Yalnızca .mp4 ve .mov dosyaları desteklenir."
            phase = .failed
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Video dosyası bulunamadı."
            phase = .failed
            return
        }

        do {
            guard let apiKey = try APIKeyProvider.apiKey(), !apiKey.isEmpty else {
                pendingVideoURL = url
                isAPIKeySheetPresented = true
                return
            }
            begin(with: url, apiKey: apiKey)
        } catch {
            pendingVideoURL = url
            isAPIKeySheetPresented = true
        }
    }

    /// API anahtarını kaydeder ve bekleyen işlemi başlatır.
    func saveAPIKey(_ key: String) -> String? {
        do {
            try APIKeyProvider.store(key)
            isAPIKeySheetPresented = false
            if let pending = pendingVideoURL {
                pendingVideoURL = nil
                begin(with: pending, apiKey: key)
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Anahtar gerektiği hâlde kullanıcı iptal ederse bekleyen videoyu unut.
    func cancelAPIKeyRequest() {
        isAPIKeySheetPresented = false
        pendingVideoURL = nil
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

    private func begin(with url: URL, apiKey: String) {
        task?.cancel()
        videoURL = url
        content = nil
        tokenUsage = .zero
        errorMessage = nil
        warnings = []
        writtenFiles = []
        videoDurationSeconds = 0
        steps = ProcessingStep.allCases.map { ProcessingStepStatus(step: $0) }
        phase = .processing

        task = Task { [weak self] in
            await self?.run(video: url, apiKey: apiKey)
        }
    }

    private func run(video url: URL, apiKey: String) async {
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
            let duration = Int((try await AudioExtractor.videoDuration(at: url)).rounded())
            videoDurationSeconds = duration
            update(.prepare, state: .done, detail: String(format: "%.0f saniyelik video", Double(duration)))

            // 2) Ses çıkarma
            update(.extractAudio, state: .active, detail: "ffmpeg çalışıyor")
            let workDirectory = try AppPaths.makeWorkDirectory()
            defer { try? FileManager.default.removeItem(at: workDirectory) }
            let audio = try await AudioExtractor.extractAudio(from: url, into: workDirectory) { [weak self] progress in
                Task { @MainActor in
                    self?.update(.extractAudio, state: .active, detail: "Ses çıkarılıyor", progress: progress)
                }
            }
            update(.extractAudio, state: .done, detail: "Ses hazır")

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
                videoName: url.lastPathComponent
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
            update(.saveFiles, state: .active, detail: "Videonun klasörüne yazılıyor")
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

    /// Başarısız bir işlemden sonra aynı videoyu tekrar dener.
    func retry() {
        guard let url = videoURL else { return }
        start(with: url)
    }

    /// Sonuçları temizleyip boş hâle döner.
    func reset() {
        task?.cancel()
        task = nil
        phase = .idle
        videoURL = nil
        content = nil
        tokenUsage = .zero
        errorMessage = nil
        warnings = []
        writtenFiles = []
        videoDurationSeconds = 0
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
