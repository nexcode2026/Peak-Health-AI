import Foundation
import Security

// MARK: - Secure Keychain Storage

final class KeychainService: Sendable {
    private let service = PeakConstants.bundleIdentifier

    enum Key: String {
        case grokAPIKey = "grok_api_key"
        case appleUserID = "apple_user_id"
        case appleIdentityToken = "apple_identity_token"
    }

    func save(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else {
            throw PeakError.invalidInput("Invalid data encoding")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PeakError.unknown("Keychain save failed: \(status)")
        }
    }

    func read(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(for key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    func deleteAll() {
        for key in [Key.grokAPIKey, Key.appleUserID, Key.appleIdentityToken] {
            delete(for: key)
        }
    }
}