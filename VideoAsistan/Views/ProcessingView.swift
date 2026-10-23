import SwiftUI

/// İşlem sırasında görünen adım listesi.
struct ProcessingView: View {
    let steps: [ProcessingStepStatus]
    let videoName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("İşleniyor")
                    .font(.title3.weight(.semibold))
                Text(videoName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    row(step)
                    if index < steps.count - 1 {
                        Divider().padding(.leading, 30)
                    }
                }
            }
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: 560, alignment: .leading)
    }

    @ViewBuilder
    private func row(_ step: ProcessingStepStatus) -> some View {
        HStack(alignment: .top, spacing: 12) {
            icon(for: step)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(step.step.title)
                        .font(.callout.weight(step.state == .active ? .semibold : .regular))
                        .foregroundStyle(step.state == .pending ? .secondary : .primary)
                    if let progress = step.progress, step.state == .active {
                        Text("\(Int(progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                if !step.detail.isEmpty {
                    Text(step.detail)
                        .font(.caption)
                        .foregroundStyle(step.state == .failed ? .red : .secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                if step.state == .active {
                    if let progress = step.progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 320)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 320)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func icon(for step: ProcessingStepStatus) -> some View {
        switch step.state {
        case .pending:
            Image(systemName: step.step.symbol)
                .foregroundStyle(.tertiary)
        case .active:
            ProgressView()
                .controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)
        }
    }
}
