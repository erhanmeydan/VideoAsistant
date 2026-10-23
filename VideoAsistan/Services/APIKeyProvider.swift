import Foundation

/// API anahtarının nereden geldiğini belirtir.
enum APIKeySource: Equatable {
    /// `MINIMAX_API_KEY` ortam değişkeni.
    case environment
    /// macOS Keychain.
    case keychain
    /// Hiçbir yerde bulunamadı.
    case none
}

/// MiniMax API anahtarını çözer.
///
/// Öncelik sırası:
/// 1. `MINIMAX_API_KEY` ortam değişkeni (geliştirme/test kolaylığı),
/// 2. macOS Keychain,
/// 3. Kullanıcıdan isteme (arayüz).
enum APIKeyProvider {
    static let environmentVariableName = "MINIMAX_API_KEY"

    /// Anahtarın mevcut olduğu kaynağı belirler.
    static func resolveSource() -> APIKeySource {
        if let environmentKey = ProcessInfo.processInfo.environment[environmentVariableName],
           !environmentKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .environment
        }
        if let stored = try? KeychainService.read(), !stored.isEmpty {
            return .keychain
        }
        return .none
    }

    /// Kullanılabilir API anahtarını döndürür (yoksa nil).
    static func apiKey() throws -> String? {
        if let environmentKey = ProcessInfo.processInfo.environment[environmentVariableName],
           !environmentKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environmentKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return try KeychainService.read()
    }

    /// Anahtarı Keychain'e kaydeder.
    static func store(_ key: String) throws {
        try KeychainService.save(key)
    }
}
