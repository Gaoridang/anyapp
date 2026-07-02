//
//  GrokAPIKeyStore.swift
//  anyapp
//

import Foundation
import Security

enum GrokAPIKeyStore {
    private static let service = "com.ijaejun.anyapp.xai-api-key"
    private static let account = "default"
    private static let bundleKey = "XAIApiKey"
    private static let placeholderValues: Set<String> = ["", "your-key-here", "$(XAI_API_KEY)"]

    nonisolated static var hasKey: Bool {
        guard let key = load() else { return false }
        return !key.isEmpty
    }

    static func load() -> String? {
        if let keychainKey = loadFromKeychain(), isValidKey(keychainKey) {
            return keychainKey
        }
        if let bundleKey = loadFromBundle(), isValidKey(bundleKey) {
            return bundleKey
        }
        return nil
    }

    static func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidKey(trimmed) else {
            throw StoreError.invalidKey
        }

        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw StoreError.keychainFailure(addStatus)
            }
        default:
            throw StoreError.keychainFailure(status)
        }
    }

    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.keychainFailure(status)
        }
    }

    private static func loadFromKeychain() -> String? {
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

    private static func loadFromBundle() -> String? {
        Bundle.main.object(forInfoDictionaryKey: bundleKey) as? String
    }

    private static func isValidKey(_ key: String) -> Bool {
        !placeholderValues.contains(key)
    }

    enum StoreError: LocalizedError {
        case invalidKey
        case keychainFailure(OSStatus)

        var errorDescription: String? {
            switch self {
            case .invalidKey:
                "유효한 API 키를 입력해 주세요."
            case .keychainFailure:
                "API 키를 저장할 수 없습니다."
            }
        }
    }
}
