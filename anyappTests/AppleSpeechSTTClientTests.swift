//
//  AppleSpeechSTTClientTests.swift
//  anyappTests
//

import Foundation
import Speech
import Testing
@testable import anyapp

private struct MockSpeechAuthorizationProvider: SpeechAuthorizationProviding {
    let status: SFSpeechRecognizerAuthorizationStatus
    let requestedStatus: SFSpeechRecognizerAuthorizationStatus

    func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        status
    }

    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        requestedStatus
    }
}

private struct MockOnDeviceSpeechTranscriber: OnDeviceSpeechTranscribing {
    let available: Bool
    let result: Result<String, Error>

    var isOnDeviceAvailable: Bool { available }

    func transcribe(audioFileURL: URL) async throws -> String {
        try result.get()
    }
}

struct AppleSpeechSTTClientTests {
    private let sampleURL = URL(fileURLWithPath: "/tmp/sample.m4a")

    @Test func transcribeUsesOnDeviceTranscriberWhenAuthorized() async throws {
        let client = AppleSpeechSTTClient(
            authorizationProvider: MockSpeechAuthorizationProvider(
                status: .authorized,
                requestedStatus: .authorized
            ),
            transcriber: MockOnDeviceSpeechTranscriber(
                available: true,
                result: .success("기기 변환 결과")
            )
        )

        let text = try await client.transcribe(audioFileURL: sampleURL)
        #expect(text == "기기 변환 결과")
    }

    @Test func transcribeRequestsAuthorizationWhenNotDetermined() async throws {
        let client = AppleSpeechSTTClient(
            authorizationProvider: MockSpeechAuthorizationProvider(
                status: .notDetermined,
                requestedStatus: .authorized
            ),
            transcriber: MockOnDeviceSpeechTranscriber(
                available: true,
                result: .success("승인 후 변환")
            )
        )

        let text = try await client.transcribe(audioFileURL: sampleURL)
        #expect(text == "승인 후 변환")
    }

    @Test func transcribeThrowsWhenAuthorizationDenied() async {
        let client = AppleSpeechSTTClient(
            authorizationProvider: MockSpeechAuthorizationProvider(
                status: .denied,
                requestedStatus: .denied
            ),
            transcriber: MockOnDeviceSpeechTranscriber(
                available: true,
                result: .success("unused")
            )
        )

        await #expect(throws: AppleSpeechSTTClient.STTError.authorizationDenied) {
            try await client.transcribe(audioFileURL: sampleURL)
        }
    }

    @Test func transcribeThrowsWhenOnDeviceUnavailable() async {
        let client = AppleSpeechSTTClient(
            authorizationProvider: MockSpeechAuthorizationProvider(
                status: .authorized,
                requestedStatus: .authorized
            ),
            transcriber: MockOnDeviceSpeechTranscriber(
                available: false,
                result: .success("unused")
            )
        )

        await #expect(throws: AppleSpeechSTTClient.STTError.onDeviceNotAvailable) {
            try await client.transcribe(audioFileURL: sampleURL)
        }
    }
}
