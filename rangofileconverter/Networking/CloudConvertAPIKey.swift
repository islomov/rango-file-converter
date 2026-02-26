import Foundation
import Security

struct CloudConvertAPIKey {
    private static let service = "com.rango.cloudconvert"
    private static let account = "api-key"

    static func apiKey() -> String? {
        if let key = readFromKeychain(), !key.isEmpty { return key }
        if let key = readFromPlist(), !key.isEmpty { return key }
        return nil
    }

    static func setAPIKey(_ key: String) {
        deleteFromKeychain()
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func deleteAPIKey() {
        deleteFromKeychain()
    }

    // MARK: - Private

    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func readFromPlist() -> String? {
        guard let path = Bundle.main.path(forResource: "CloudConvertConfig", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["APIKey"] as? String else {
            return nil
        }
        return key
    }
}
