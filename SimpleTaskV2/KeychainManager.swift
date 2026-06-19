import Foundation
import Security

struct KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.simpletask.geminiApiKey"

    func saveApiKey(_ key: String) {
        if key.isEmpty {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: "geminiApiKey"
            ]
            SecItemDelete(query as CFDictionary)
            return
        }

        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "geminiApiKey"
        ]

        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var newQuery = query
            newQuery[kSecValueData as String] = data
            SecItemAdd(newQuery as CFDictionary, nil)
        }
    }

    func getApiKey() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "geminiApiKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data, let key = String(data: data, encoding: .utf8) {
            return key
        }

        // Migration from UserDefaults
        if let oldKey = UserDefaults.standard.string(forKey: "geminiApiKey"), !oldKey.isEmpty {
            saveApiKey(oldKey)
            UserDefaults.standard.removeObject(forKey: "geminiApiKey")
            return oldKey
        }

        return ""
    }
}
