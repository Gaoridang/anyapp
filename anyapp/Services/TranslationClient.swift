//
//  TranslationClient.swift
//  anyapp
//

import Foundation

protocol TranslationClient: Sendable {
    func translateKoreanToEnglish(_ text: String) async throws -> String
}

struct TranslationRouter: TranslationClient {
    private let grokClient: any TranslationClient
    private let appleClient: any TranslationClient
    private let hasGrokKey: @Sendable () -> Bool
    private let isAppleTranslationAvailable: @Sendable () -> Bool

    init(
        grokClient: any TranslationClient = GrokTranslationClient(),
        appleClient: any TranslationClient = AppleTranslationClient(),
        hasGrokKey: @escaping @Sendable () -> Bool = { GrokAPIKeyStore.hasKey },
        isAppleTranslationAvailable: @escaping @Sendable () -> Bool = { AppleTranslationClient.isAvailable }
    ) {
        self.grokClient = grokClient
        self.appleClient = appleClient
        self.hasGrokKey = hasGrokKey
        self.isAppleTranslationAvailable = isAppleTranslationAvailable
    }

    func translateKoreanToEnglish(_ text: String) async throws -> String {
        if hasGrokKey() {
            do {
                return try await grokClient.translateKoreanToEnglish(text)
            } catch {
                if isAppleTranslationAvailable() {
                    return try await appleClient.translateKoreanToEnglish(text)
                }
                throw error
            }
        }

        guard isAppleTranslationAvailable() else {
            throw TranslationError.unavailable
        }
        return try await appleClient.translateKoreanToEnglish(text)
    }

    enum TranslationError: LocalizedError, Equatable {
        case unavailable

        var errorDescription: String? {
            "번역을 생성할 수 없습니다. 네트워크 또는 API 설정을 확인해 주세요."
        }
    }
}