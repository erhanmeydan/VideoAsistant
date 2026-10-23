import SwiftUI

/// API yanıtındaki gerçek token kullanımını gösteren panel.
struct TokenUsageView: View {
    let usage: TokenUsage
    /// Çağrı sayısını gösteren isteğe bağlı bilgi.
    var detail: String?

    var body: some View {
        HStack(spacing: 18) {
            metric(title: "Girdi", value: usage.inputTokens, symbol: "arrow.down")
            Divider().frame(height: 26)
            metric(title: "Çıktı", value: usage.outputTokens, symbol: "arrow.up")
            Divider().frame(height: 26)
            metric(title: "Toplam", value: usage.totalTokens, symbol: "sum")

            if usage.thinkingTokens > 0 {
                Divider().frame(height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thinking")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(usage.thinkingTokens)")
                        .font(.callout.monospacedDigit())
                }
            }

            Spacer(minLength: 0)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private func metric(title: String, value: Int, symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .font(.callout.weight(.medium).monospacedDigit())
            }
        }
    }
}
