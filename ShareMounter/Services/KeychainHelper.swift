import Foundation
import Security

enum Keychain {
    @discardableResult
    static func set(_ value: String, service: String, account: String) -> OSStatus {
        let data = Data(value.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(base as CFDictionary)
        var addQuery = base
        addQuery[kSecValueData as String] = data
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            if let msg = SecCopyErrorMessageString(status, nil) as String? {
                print("🔴 Keychain set failed (\(status)): \(msg) – service=\(service) account=\(account)")
            }
        } else {
            print("🟢 Keychain set OK – service=\(service) account=\(account)")
        }
        return status
    }

    static func get(service: String, account: String) -> (String?, OSStatus) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                if let msg = SecCopyErrorMessageString(status, nil) as String? {
                    print("🔴 Keychain get failed (\(status)): \(msg) – service=\(service) account=\(account)")
                }
            }
            return (nil, status)
        }
        return (s, errSecSuccess)
    }

    @discardableResult
    static func delete(service: String, account: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary)
    }
}
