//
//  AppleTranslationClient.swift
//  anyapp
//

import Foundation
import Translation

struct AppleTranslationClient: TranslationClient {
    nonisolated static var isAvailable: Bool {
        if #available(iOS 18.0, *) {
            return true
        }
        return false
    }

    func translateKoreanToEnglish(_ text: String) async throws -> String {
        if #available(iOS 18.0, *) {
            return try await SystemAppleTranslationClient().translateKoreanToEnglish(text)
        }
        throw TranslationRouter.TranslationError.unavailable
    }
}

@available(iOS 18.0, *)
private struct SystemAppleTranslationClient: TranslationClient {
    func translateKoreanToEnglish(_ text: String) async throws -> String {
        let source = Locale.Language(identifier: "ko-KR")
        let target = Locale.Language(identifier: "en-US")
        let session = TranslationSession(installedSource: source, target: target)
        try await session.prepareTranslation()
        let response = try await session.translate(text)
        let translated = response.targetText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !translated.isEmpty else {
            throw TranslationRouter.TranslationError.unavailable
        }
        return translated
    }
}