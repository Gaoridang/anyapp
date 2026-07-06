//
//  ShadowingSTTRouter.swift
//  anyapp
//

import Foundation

enum ShadowingSpeechLanguage: String, Sendable, CaseIterable {
    case korean
    case english

    var grokLanguageCode: String {
        switch self {
        case .korean:
            "ko"
        case .english:
            "en"
        }
    }

    var appleLocaleIdentifier: String {
        switch self {
        case .korean:
            "ko-KR"
        case .english:
            "en-US"
        }
    }

    var displayName: String {
        switch self {
        case .korean:
            "한국어"
        case .english:
            "English"
        }
    }
}

struct ShadowingSTTRouter: Sendable {
    private let hasGrokKey: @Sendable () -> Bool
    private let grokClientFactory: @Sendable (String) -> any SpeechTranscriptionClient
    private let onDeviceClientFactory: @Sendable (String) -> any SpeechTranscriptionClient

    init(
        hasGrokKey: @escaping @Sendable () -> Bool = { GrokAPIKeyStore.hasKey },
        grokClientFactory: @escaping @Sendable (String) -> any SpeechTranscriptionClient = { language in
            GrokSTTClient(language: language)
        },
        onDeviceClientFactory: @escaping @Sendable (String) -> any SpeechTranscriptionClient = { _ in
            AppleSpeechSTTClient()
        }
    ) {
        self.hasGrokKey = hasGrokKey
        self.grokClientFactory = grokClientFactory
        self.onDeviceClientFactory = onDeviceClientFactory
    }

    func transcribe(audioFileURL: URL, language: ShadowingSpeechLanguage) async throws -> String {
        if hasGrokKey() {
            return try await grokClientFactory(language.grokLanguageCode)
                .transcribe(audioFileURL: audioFileURL)
        }

        let locale = Locale(identifier: language.appleLocaleIdentifier)
        let client = onDeviceClientFactory(language.appleLocaleIdentifier)
        return try await client.transcribe(audioFileURL: audioFileURL, locale: locale)
    }
}
