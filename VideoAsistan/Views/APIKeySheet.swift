import SwiftUI

/// İlk açılışta MiniMax API anahtarını isteyen panel.
///
/// Anahtar hiçbir yere yazılmaz; yalnızca kullanıcı onayıyla Keychain'e kaydedilir.
struct APIKeySheet: View {
    /// Anahtarı kaydeder; başarılıysa nil, aksi halde Türkçe hata mesajı döndürür.
    let onSave: (String) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var errorMessage: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Label("MiniMax API Anahtarı", systemImage: "key.fill")
                    .font(.title3.weight(.semibold))
                Text("Anahtar yalnızca macOS Keychain'de saklanır ve koda gömülmez. "
                     + "platform.minimax.io adresinden alabilirsiniz.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SecureField("API anahtarı", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .focused($isFieldFocused)
                .onSubmit(save)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Vazgeç") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Kaydet", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { isFieldFocused = true }
    }

    private func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let error = onSave(trimmed) {
            errorMessage = error
        } else {
            dismiss()
        }
    }
}
