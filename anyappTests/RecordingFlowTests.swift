//
//  RecordingFlowTests.swift
//  anyappTests
//

import AVFoundation
import Foundation
import Testing
@testable import anyapp

@MainActor
struct RecordingFlowTests {
    @Test func successfulRecordingPersistsItemAudioMetadata() async throws {
        let permission = MockFlowPermissionProvider(recordPermission: .granted, requestResult: true)
        let captureMaker = MockFlowCaptureMaker()
        let recorder = AudioRecorder(
            permissionProvider: permission,
            sessionConfigurator: MockFlowSessionConfigurator(),
            captureMaker: captureMaker
        )

        await recorder.prepare()

        let fileName = "\(UUID().uuidString).m4a"
        let url = AudioFileStore.documentsDirectory.appendingPathComponent(fileName)

        try recorder.startRecording(to: url)
        #expect(recorder.isRecording)

        captureMaker.lastCapture?.currentTime = 2.0
        let duration = recorder.stopRecording()

        let item = Item(timestamp: .now)
        item.audioFileName = fileName
        item.audioDuration = duration

        #expect(duration != nil)
        #expect(item.audioFileName == fileName)
        #expect(item.audioDuration != nil)
        #expect(item.audioDuration! > 0)
        #expect(item.audioFileURL?.lastPathComponent == fileName)
    }
}

private final class MockFlowPermissionProvider: MicrophonePermissionProviding, @unchecked Sendable {
    var recordPermission: AVAudioApplication.recordPermission
    var requestResult: Bool

    init(
        recordPermission: AVAudioApplication.recordPermission,
        requestResult: Bool
    ) {
        self.recordPermission = recordPermission
        self.requestResult = requestResult
    }

    func requestRecordPermission() async -> Bool {
        recordPermission = requestResult ? .granted : .denied
        return requestResult
    }
}

private final class MockFlowSessionConfigurator: AudioSessionConfiguring, @unchecked Sendable {
    func deactivateSession() throws {}
    func configureForRecording() throws {}
}

private final class MockFlowCapture: RecordingCapturing, @unchecked Sendable {
    var currentTime: TimeInterval = 0
    var isMeteringEnabled = false

    func prepareToRecord() -> Bool { true }
    func record() -> Bool { true }
    func stop() {}
}

private final class MockFlowCaptureMaker: RecordingCaptureMaking, @unchecked Sendable {
    var lastCapture: MockFlowCapture?

    func makeRecorder(url: URL, settings: [String: Any]) throws -> any RecordingCapturing {
        let capture = MockFlowCapture()
        lastCapture = capture
        return capture
    }
}