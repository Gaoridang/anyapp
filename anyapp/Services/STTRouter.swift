//
//  STTRouter.swift
//  anyapp
//

import Foundation

struct STTRouter: SpeechTranscriptionClient {
    private let modeProvider: @Sendable () -> STTMode
    private let grokClient: any SpeechTranscriptionClient
    private let onDeviceClient: any SpeechTranscriptionClient
    private let onDeviceAvailability: @Sendable () -> Bool
    private let hasGrokKey: @Sendable () -> Bool

    init(
        modeProvider: @escaping @Sendable () -> STTMode = { STTModeStore.mode },
        grokClient: any SpeechTranscriptionClient = GrokSTTClient(),
        onDeviceClient: any SpeechTranscriptionClient = AppleSpeechSTTClient(),
        onDeviceAvailability: @escaping @Sendable () -> Bool = { AppleSpeechSTTClient.isOnDeviceAvailable },
        hasGrokKey: @escaping @Sendable () -> Bool = { GrokAPIKeyStore.hasKey }
    ) {
        self.modeProvider = modeProvider
        self.grokClient = grokClient
        self.onDeviceClient = onDeviceClient
        self.onDeviceAvailability = onDeviceAvailability
        self.hasGrokKey = hasGrokKey
    }

    func resolvedProvider(for mode: STTMode? = nil) -> STTProvider {
        switch mode ?? modeProvider() {
        case .grok:
            return .grok
        case .onDevice:
            return .onDevice
        case .automatic:
            return hasGrokKey() ? .grok : .onDevice
        }
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        switch resolvedProvider() {
        case .grok:
            guard hasGrokKey() else {
                throw STTRouterError.grokUnavailable
            }
            return try await grokClient.transcribe(audioFileURL: audioFileURL)
        case .onDevice:
            guard onDeviceAvailability() else {
                throw STTRouterError.onDeviceUnavailable
            }
            return try await onDeviceClient.transcribe(audioFileURL: audioFileURL)
        }
    }

    enum STTRouterError: LocalizedError, Equatable {
        case grokUnavailable
        case onDeviceUnavailable

        var errorDescription: String? {
            switch self {
            case .grokUnavailable:
                "Grok API 키를 설정해 주세요."
            case .onDeviceUnavailable:
                "기기 음성 인식을 사용할 수 없습니다. 설정 > 일반 > 키보드 > 받아쓰기에서 한국어를 설치해 주세요."
            }
        }
    }
}
