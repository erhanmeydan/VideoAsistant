import Foundation

/// Bir API çağrısının gerçek token kullanımı.
///
/// Değerler MiniMax yanıtındaki `usage` alanından alınır; hiçbir tahmin yapılmaz.
struct TokenUsage: Equatable, Sendable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0
    /// Varsa düşünme (thinking) token sayısı; çıktı token'larının bir parçasıdır.
    var thinkingTokens: Int = 0

    var totalTokens: Int { inputTokens + outputTokens }
    var hasCacheInfo: Bool { cacheReadTokens > 0 || cacheCreationTokens > 0 }

    static let zero = TokenUsage()

    static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens,
            cacheCreationTokens: lhs.cacheCreationTokens + rhs.cacheCreationTokens,
            thinkingTokens: lhs.thinkingTokens + rhs.thinkingTokens
        )
    }
}
