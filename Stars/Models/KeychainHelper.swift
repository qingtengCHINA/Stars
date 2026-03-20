//
//  KeychainHelper.swift
//  Stars
//

import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper()

    private let service = Bundle.main.bundleIdentifier ?? "QingTengSTUDIO.Stars"

    private init() {}

    // MARK: - Public API

    func save(_ value: String, for account: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Remove existing entry first to avoid duplicates
        delete(for: account)

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account,
            kSecValueData as String:    data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    func read(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func delete(for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
