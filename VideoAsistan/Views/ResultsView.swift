import SwiftUI

/// Sonuçlar: üstte video bilgisi ve token kullanımı, altında sekmeler.
struct ResultsView: View {
    let content: GeneratedContent
    let videoName: String
    let durationSeconds: Int
    let tokenUsage: TokenUsage
    let writtenFiles: [URL]
    let warnings: [String]
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            TabView {
                ResultTabView(
                    title: "Altyazı",
                    symbol: "captions.bubble",
                    content: content.srt,
                    monospaced: true,
                    subtitle: "\(content.subtitleSegments.count) segment"
                )
                .tabItem { Label("Altyazı", systemImage: "captions.bubble") }

                ResultTabView(
                    title: "Bölümler",
                    symbol: "list.number",
                    content: content.chaptersText,
                    monospaced: false,
                    subtitle: "\(content.chapters.count) bölüm"
                )
                .tabItem { Label("Bölümler", systemImage: "list.number") }

                ResultTabView(
                    title: "Açıklama",
                    symbol: "text.alignleft",
                    content: content.description,
                    monospaced: false,
                    subtitle: paragraphCount
                )
                .tabItem { Label("Açıklama", systemImage: "text.alignleft") }

                ResultTabView(
                    title: "Başlıklar",
                    symbol: "textformat",
                    content: content.titlesText,
                    monospaced: false,
                    subtitle: "\(content.titles.count) başlık"
                )
                .tabItem { Label("Başlıklar", systemImage: "textformat") }

                ResultTabView(
                    title: "Etiketler",
                    symbol: "tag",
                    content: content.tagsForCopy,
                    monospaced: false,
                    subtitle: "\(content.tags.count) etiket · \(content.tagsForCopy.count)/500 karakter"
                )
                .tabItem { Label("Etiketler", systemImage: "tag") }
            }
            .padding(.top, 8)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(videoName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(durationText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onReset()
                } label: {
                    Label("Yeni video", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }

            TokenUsageView(usage: tokenUsage)

            if !writtenFiles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Kaydedilen dosyalar", systemImage: "folder.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    ForEach(writtenFiles, id: \.self) { url in
                        Text(url.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
            }

            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var paragraphCount: String {
        let count = content.description.components(separatedBy: "\n\n").filter { !$0.isEmpty }.count
        return "\(count) paragraf"
    }

    private var durationText: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%.0f dk %.0f sn", Double(minutes), Double(seconds))
    }
}
