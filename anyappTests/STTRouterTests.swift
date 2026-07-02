//
//  STTRouterTests.swift
//  anyappTests
//

import Foundation
import Testing
@testable import anyapp

private struct MockSTTClient: SpeechTranscriptionClient {
    let result: String

    func transcribe(audioFileURL: URL) async throws -> String {
        result
    }
}

struct STTRouterTests {
    private let sampleURL = URL(fileURLWithPath: "/tmp/sample.m4a")

    @Test func resolvedProviderAutomaticUsesGrokWhenKeyExists() {
        let router = STTRouter(
            modeProvider: { .automatic },
            hasGrokKey: { true },
            onDeviceAvailability: { true }
        )

        #expect(router.resolvedProvider() == .grok)
    }

    @Test func resolvedProviderAutomaticUsesOnDeviceWhenKeyMissing() {
        let router = STTRouter(
            modeProvider: { .automatic },
            hasGrokKey: { false },
            onDeviceAvailability: { true }
        )

        #expect(router.resolvedProvider() == .onDevice)
    }

    @Test func resolvedProviderGrokModeAlwaysUsesGrok() {
        let router = STTRouter(
            modeProvider: { .grok },
            hasGrokKey: { false },
            onDeviceAvailability: { true }
        )

        #expect(router.resolvedProvider() == .grok)
    }

    @Test func resolvedProviderOnDeviceModeAlwaysUsesOnDevice() {
        let router = STTRouter(
            modeProvider: { .onDevice },
            hasGrokKey: { true },
            onDeviceAvailability: { true }
        )

        #expect(router.resolvedProvider() == .onDevice)
    }

    @Test func transcribeAutomaticWithKeyUsesGrokClient() async throws {
        let router = STTRouter(
            modeProvider: { .automatic },
            grokClient: MockSTTClient(result: "grok-text"),
            onDeviceClient: MockSTTClient(result: "device-text"),
            onDeviceAvailability: { true },
            hasGrokKey: { true }
        )

        let text = try await router.transcribe(audioFileURL: sampleURL)
        #expect(text == "grok-text")
    }

    @Test func transcribeAutomaticWithoutKeyUsesOnDeviceClient() async throws {
        let router = STTRouter(
            modeProvider: { .automatic },
            grokClient: MockSTTClient(result: "grok-text"),
            onDeviceClient: MockSTTClient(result: "device-text"),
            onDeviceAvailability: { true },
            hasGrokKey: { false }
        )

        let text = try await router.transcribe(audioFileURL: sampleURL)
        #expect(text == "device-text")
    }

    @Test func transcribeGrokModeWithoutKeyThrows() async {
        let router = STTRouter(
            modeProvider: { .grok },
            grokClient: MockSTTClient(result: "grok-text"),
            onDeviceClient: MockSTTClient(result: "device-text"),
            onDeviceAvailability: { true },
            hasGrokKey: { false }
        )

        await #expect(throws: STTRouter.STTRouterError.grokUnavailable) {
            try await router.transcribe(audioFileURL: sampleURL)
        }
    }

    @Test func transcribeOnDeviceModeWhenUnavailableThrows() async {
        let router = STTRouter(
            modeProvider: { .onDevice },
            grokClient: MockSTTClient(result: "grok-text"),
            onDeviceClient: MockSTTClient(result: "device-text"),
            onDeviceAvailability: { false },
            hasGrokKey: { true }
        )

        await #expect(throws: STTRouter.STTRouterError.onDeviceUnavailable) {
            try await router.transcribe(audioFileURL: sampleURL)
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
