import SwiftUI

/// Uygulamanın ana görünümü. VideoAsistan üç hâlde geçer:
/// boş (sürükle-bırak), işlem sürüyor ve sonuçlar hazır.
struct ContentView: View {
    @State private var controller = PipelineController()

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            switch controller.phase {
            case .idle:
                DropZoneView(
                    onFileSelected: { controller.start(with: $0) },
                    isTargeted: controller.isDragTargeted
                )
            case .processing:
                ProcessingView(steps: controller.steps, videoName: controller.videoURL?.lastPathComponent ?? "")
            case .results:
                if let content = controller.content {
                    ResultsView(
                        content: content,
                        videoName: controller.videoURL?.lastPathComponent ?? "",
                        durationSeconds: controller.videoDurationSeconds,
                        tokenUsage: controller.tokenUsage,
                        writtenFiles: controller.writtenFiles,
                        warnings: controller.warnings,
                        onReset: { controller.reset() }
                    )
                }
            case .failed:
                failureView
            }
        }
        .frame(minWidth: 880, minHeight: 600)
        .sheet(isPresented: $controller.isAPIKeySheetPresented) {
            APIKeySheet { key in
                controller.saveAPIKey(key)
            }
        }
        .onAppear {
            controller.requestAPIKeyIfNeeded()

            // `--open <video>` ile açıldıysa işlem hemen başlar.
            if let pending = LaunchOptions.videoToOpen {
                LaunchOptions.videoToOpen = nil
                controller.start(with: pending)
            }
        }
    }

    private var failureView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("İşlem tamamlanamadı")
                .font(.title3.weight(.semibold))

            Text(controller.errorMessage ?? "Bilinmeyen hata")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .frame(maxWidth: 520)

            HStack(spacing: 12) {
                Button("Tekrar dene") { controller.retry() }
                    .buttonStyle(.borderedProminent)
                Button("Yeni video") { controller.reset() }
                    .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .padding(40)
    }
}
