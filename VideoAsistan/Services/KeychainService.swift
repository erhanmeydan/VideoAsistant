import Foundation
import Security

/// macOS Keychain'e MiniMax API anahtarını okur ve yazar.
///
/// Varsayılan (güvenli) erişim denetimi kullanılır: anahtarı yalnızca bu uygulama
/// okuyabilir. Ad-hoc imzalı bir uygulama yeniden derlendiğinde imza özeti değiştiği
/// için okuma `-25293 (errSecAuthFailed)` hatası verebilir; bu durum kullanıcıya
/// bildirilir.
enum KeychainService {
    static let service = "com.erhanmeydan.videoasistan"
    static let account = "minimax-api-key"

    enum KeychainError: LocalizedError {
        case accessDenied
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Anahtar erişimi reddedildi. Uygulama yeniden derlenmiş olabilir; "
                    + "anahtarı tekrar girin veya MINIMAX_API_KEY ortam değişkenini tanımlayın."
            case .unexpectedStatus(let status):
                return "Keychain hatası (kod \(status))."
            }
        }
    }

    /// Keychain'de kayıtlı anahtarı okur. Kayıt yoksa nil döner.
    static func read() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
                return nil
            }
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        case errSecItemNotFound:
            return nil
        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw KeychainError.accessDenied
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Anahtarı Keychain'e yazar (varsa önceki kaydı günceller).
    static func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try delete()

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: Data(trimmed.utf8)
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            if status == errSecAuthFailed || status == errSecInteractionNotAllowed {
                throw KeychainError.accessDenied
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Keychain kaydını siler.
    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            if status == errSecAuthFailed || status == errSecInteractionNotAllowed {
                throw KeychainError.accessDenied
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
