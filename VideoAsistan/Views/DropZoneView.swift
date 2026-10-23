import SwiftUI
import UniformTypeIdentifiers

/// Pencere ortasındaki büyük "videoyu buraya sürükle" alanı.
struct DropZoneView: View {
    let onFileSelected: (URL) -> Void
    let isTargeted: Bool

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.accentColor.opacity(isTargeted ? 0.14 : 0.06))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                    )
                    .foregroundStyle(Color.accentColor.opacity(isTargeted ? 0.9 : 0.45))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                VStack(spacing: 16) {
                    Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "arrow.down.doc")
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.pulse, options: .repeating, isActive: isTargeted)

                    Text("Videoyu buraya sürükle")
                        .font(.title2.weight(.semibold))

                    Text("veya dosyayı seçin")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Button {
                        chooseFile()
                    } label: {
                        Label("Dosya seç", systemImage: "folder")
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Desteklenen biçimler: MP4, MOV")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(40)
            }
        }
        .padding(28)
        .onHover { isHovering = $0 }
        .onDrop(of: [UTType.fileURL], isTargeted: .constant(isTargeted)) { providers in
            handleDrop(providers)
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Sürükle-bırak yerine bir video dosyası seçin"
        if panel.runModal() == .OK, let url = panel.url {
            onFileSelected(url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in onFileSelected(url) }
        }
        return true
    }
}
