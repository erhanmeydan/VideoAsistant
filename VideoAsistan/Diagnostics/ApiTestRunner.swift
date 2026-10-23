import Foundation

/// `--apitest` komutunun gövdesi: MiniMax bağlantısını doğrular.
enum ApiTestRunner {
    static func run(prompt: String) async -> Int32 {
        guard let key = try? APIKeyProvider.apiKey(), !key.isEmpty else {
            print("HATA: API anahtarı bulunamadı. MINIMAX_API_KEY tanımlayın veya uygulamadan girin.")
            return 1
        }

        print("== MiniMax API testi ==")
        print("Model: \(MiniMaxClient.modelName)")

        let client = MiniMaxClient(apiKey: key)
        do {
            let response = try await client.send(
                system: "Sen yardımcı bir asistansın. Kısa ve net cevap ver.",
                user: prompt,
                maxTokens: 256,
                effort: .low
            )
            print("Yanıt: \(response.text)")
            print("Token — girdi: \(response.usage.inputTokens), çıktı: \(response.usage.outputTokens)")
            print("== Sonuç: BAŞARILI ==")
            return 0
        } catch {
            print("HATA: \(error.localizedDescription)")
            print("== Sonuç: BAŞARISIZ ==")
            return 1
        }
    }
}
