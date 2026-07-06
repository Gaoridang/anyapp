//
//  ShadowingSTTRouterTests.swift
//  anyappTests
//

import Foundation
import Testing
@testable import anyapp

private struct MockSTTClient: SpeechTranscriptionClient {
    let languageTag: String
    let result: String

    func transcribe(audioFileURL: URL, locale: Locale) async throws -> String {
        _ = audioFileURL
        _ = locale
        return "\(languageTag):\(result)"
    }
}

struct ShadowingSTTRouterTests {
    @Test func usesGrokWhenKeyExists() async throws {
        let router = ShadowingSTTRouter(
            hasGrokKey: { true },
            grokClientFactory: { language in
                MockSTTClient(languageTag: "grok-\(language)", result: "text")
            },
            onDeviceClientFactory: { locale in
                MockSTTClient(languageTag: "device-\(locale)", result: "text")
            }
        )

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sample.m4a")
        let korean = try await router.transcribe(audioFileURL: url, language: .korean)
        let english = try await router.transcribe(audioFileURL: url, language: .english)

        #expect(korean == "grok-ko:text")
        #expect(english == "grok-en:text")
    }

    @Test func fallsBackToOnDeviceWhenNoKey() async throws {
        let router = ShadowingSTTRouter(
            hasGrokKey: { false },
            grokClientFactory: { language in
                MockSTTClient(languageTag: "grok-\(language)", result: "text")
            },
            onDeviceClientFactory: { locale in
                MockSTTClient(languageTag: "device-\(locale)", result: "text")
            }
        )

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sample.m4a")
        let korean = try await router.transcribe(audioFileURL: url, language: .korean)
        let english = try await router.transcribe(audioFileURL: url, language: .english)

        #expect(korean == "device-ko-KR:text")
        #expect(english == "device-en-US:text")
    }
}
