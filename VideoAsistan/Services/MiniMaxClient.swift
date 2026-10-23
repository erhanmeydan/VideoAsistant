import Foundation

/// MiniMax'in Anthropic uyumlu uç noktasıyla iletişim kurar.
///
/// Uç nokta: `POST https://api.minimax.io/anthropic/v1/messages`
/// Kimlik doğrulama: `X-Api-Key` başlığı (sunucu bu başlığı zorunlu tutar).
struct MiniMaxClient {
    enum Effort: String {
        case low, medium, high, xhigh, max
    }

    struct Response {
        let text: String
        let usage: TokenUsage
        let stopReason: String?
    }

    enum ClientError: LocalizedError {
        case missingAPIKey
        case unauthorized(String)
        case rateLimited
        case badRequest(String)
        case serverError(status: Int, message: String?)
        case network(String)
        case truncated
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "API anahtarı bulunamadı."
            case .unauthorized(let detail):
                return "API anahtarı geçersiz. Lütfen anahtarı yenileyin."
                    + (detail.isEmpty ? "" : " (\(detail))")
            case .rateLimited:
                return "Hız sınırına takıldı, lütfen biraz sonra tekrar deneyin."
            case .badRequest(let detail):
                return "İstek reddedildi: \(detail)"
            case .serverError(let status, let message):
                return "Sunucu hatası (\(status)).\(message.map { " \($0)" } ?? "")"
            case .network(let detail):
                return "Ağ hatası: \(detail)"
            case .truncated:
                return "Model çıktısı kesildi, lütfen tekrar deneyin."
            case .emptyResponse:
                return "Model boş yanıt döndürdü."
            }
        }
    }

    static let baseURL = URL(string: "https://api.minimax.io/anthropic/v1/messages")!
    static let modelName = "MiniMax-M3.1-Flash"

    private let apiKey: String
    private let session: URLSession
    private let maximumAttempts = 3

    init(apiKey: String, session: URLSession? = nil) {
        self.apiKey = apiKey
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 600
            configuration.timeoutIntervalForResource = 900
            configuration.waitsForConnectivity = true
            self.session = URLSession(configuration: configuration)
        }
    }

    /// Sistem ve kullanıcı istemiyle tek bir mesaj gönderir.
    ///
    /// - Important: `MiniMax-M3.1-Flash` için thinking her zaman açıktır; bu yüzden
    ///   `thinking` alanı gönderilmez ve `effort` asla `none` yapılmaz.
    func send(system: String, user: String, maxTokens: Int, effort: Effort) async throws -> Response {
        let body: [String: Any] = [
            "model": Self.modelName,
            "max_tokens": maxTokens,
            "output_config": ["effort": effort.rawValue],
            "system": system,
            "messages": [["role": "user", "content": user]]
        ]

        var request = URLRequest(url: Self.baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("2023-06-01", forHTTPHeaderField: "Anthropic-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var lastError: Error?

        for attempt in 0..<maximumAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ClientError.network("Geçersiz yanıt")
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return try decode(data)
                case 401, 403:
                    throw ClientError.unauthorized(serverMessage(data))
                case 429:
                    lastError = ClientError.rateLimited
                case 400:
                    throw ClientError.badRequest(serverMessage(data))
                default:
                    lastError = ClientError.serverError(status: httpResponse.statusCode, message: serverMessage(data))
                }
            } catch let error as ClientError {
                // Kimlik doğrulama / geçersiz istek hataları yeniden denenmez.
                switch error {
                case .unauthorized, .badRequest, .missingAPIKey, .emptyResponse:
                    throw error
                default:
                    lastError = error
                }
            } catch {
                lastError = ClientError.network(error.localizedDescription)
            }

            if attempt < maximumAttempts - 1 {
                let delay = UInt64(pow(2.0, Double(attempt)) * 2.0)
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            }
        }

        throw lastError ?? ClientError.network("Bilinmeyen hata")
    }

    // MARK: - Yanıt çözümleme

    private struct APIResponse: Decodable {
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
            let thinking: String?
        }

        struct OutputDetails: Decodable {
            let thinking_tokens: Int?
        }

        struct Usage: Decodable {
            let input_tokens: Int
            let output_tokens: Int
            let cache_creation_input_tokens: Int?
            let cache_read_input_tokens: Int?
            let output_tokens_details: OutputDetails?
        }

        let content: [ContentBlock]
        let usage: Usage
        let stop_reason: String?
    }

    private struct ErrorResponse: Decodable {
        struct ErrorBody: Decodable {
            let type: String?
            let message: String?
        }
        let error: ErrorBody?
    }

    private func decode(_ data: Data) throws -> Response {
        guard let payload = try? JSONDecoder().decode(APIResponse.self, from: data) else {
            throw ClientError.network("Yanıt çözümlenemedi")
        }

        let text = payload.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClientError.emptyResponse
        }

        let usage = TokenUsage(
            inputTokens: payload.usage.input_tokens,
            outputTokens: payload.usage.output_tokens,
            cacheReadTokens: payload.usage.cache_read_input_tokens ?? 0,
            cacheCreationTokens: payload.usage.cache_creation_input_tokens ?? 0,
            thinkingTokens: payload.usage.output_tokens_details?.thinking_tokens ?? 0
        )

        if payload.stop_reason == "max_tokens" {
            throw ClientError.truncated
        }

        return Response(text: text, usage: usage, stopReason: payload.stop_reason)
    }

    private func serverMessage(_ data: Data) -> String {
        guard let payload = try? JSONDecoder().decode(ErrorResponse.self, from: data),
              let message = payload.error?.message else {
            return ""
        }
        return message
    }
}
