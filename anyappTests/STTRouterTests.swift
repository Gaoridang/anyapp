//
//  STTRouterTests.swift
//  anyappTests
//

import Foundation
import Testing
@testable import anyapp

private struct MockSTTClient: SpeechTranscriptionClient {
    let result: String

    func transcribe(audioFileURL: URL, locale: Locale) async throws -> String {
        _ = locale
        return result
    }
}

struct STTRouterTests {
    private let sampleURL = URL(fileURLWithPath: "/tmp/sample.m4a")

    @Test func resolvedProviderAutomaticUsesGrokWhenKeyExists() {
        let router = STTRouter(
            modeProvider: { .automatic },
            onDeviceAvailability: { _ in true },
            hasGrokKey: { true }
        )

        #expect(router.resolvedProvider() == .grok)
    }

    @Test func resolvedProviderAutomaticUsesOnDeviceWhenKeyMissing() {
        let router = STTRouter(
            modeProvider: { .automatic },
            onDeviceAvailability: { _ in true },
            hasGrokKey: { false }
        )

        #expect(router.resolvedProvider() == .onDevice)
    }

    @Test func resolvedProviderGrokModeAlwaysUsesGrok() {
        let router = STTRouter(
            modeProvider: { .grok },
            onDeviceAvailability: { _ in true },
            hasGrokKey: { false }
        )

        #expect(router.resolvedProvider() == .grok)
    }

    @Test func resolvedProviderOnDeviceModeAlwaysUsesOnDevice() {
        let router = STTRouter(
            modeProvider: { .onDevice },
            onDeviceAvailability: { _ in true },
            hasGrokKey: { true }
        )

        #expect(router.resolvedProvider() == .onDevice)
    }

    @Test func transcribeAutomaticWithKeyUsesGrokClient() async throws {
        let router = STTRouter(
            modeProvider: { .automatic },
            grokClient: MockSTTClient(result: "grok-text"),
            onDeviceClient: MockSTTClient(result: "device-text"),
            onDeviceAvailability: { _ in true },
            hasGrokKey: { true }
        )

        let text = try await router.transcribe(audioFileURL: sampleURL, locale: PracticeLocale.english)
        #expect(text == "grok-text")
    }

    @Test func transcribeAutomaticWithoutKeyUsesOnDeviceClient() async throws {
        let router = STTRouter(
            modeProvider: { .automatic },
            grokClient: MockSTTClient(result: "grok-text"),
            onDeviceClient: MockSTTClient(result: "device-text"),
            onDeviceAvailability: { _ in true },
            hasGrokKey: { false }
        )

        let text = try await router.transcribe(audioFileURL: sampleURL, locale: PracticeLocale.korean)
        #expect(text == "device-text")
    }

    @Test func transcribeGrokModeWithoutKeyThrows() async {
        let router = STTRouter(
            modeProvider: { .grok },
            grokClient: MockSTTClient(result: "grok-text"),
            onDeviceClient: MockSTTClient(result: "device-text"),
            onDeviceAvailability: { _ in true },
            hasGrokKey: { false }
        )

        await #expect(throws: STTRouter.STTRouterError.grokUnavailable) {
            try await router.transcribe(audioFileURL: sampleURL, locale: PracticeLocale.korean)
        }
    }

    @Test func transcribeOnDeviceModeWhenUnavailableThrows() async {
        let router = STTRouter(
            modeProvider: { .onDevice },
            grokClient: MockSTTClient(result: "grok-text"),
            onDeviceClient: MockSTTClient(result: "device-text"),
            onDeviceAvailability: { _ in false },
            hasGrokKey: { true }
        )

        await #expect(throws: STTRouter.STTRouterError.onDeviceUnavailable(locale: PracticeLocale.english)) {
            try await router.transcribe(audioFileURL: sampleURL, locale: PracticeLocale.english)
        }
    }

    @Test func sttModeStoreDefaultsToAutomatic() {
        let key = "sttMode"
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: key)
        defaults.removeObject(forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        #expect(STTModeStore.mode == .automatic)
    }
}
