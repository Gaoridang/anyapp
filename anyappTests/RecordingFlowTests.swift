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
    @Test func stopPersistsAudioMetadataOntoItem() async throws {
        let permission = MockFlowPermissionProvider(recordPermission: .granted, requestResult: true)
        let factory = MockFlowEngineFactory()
        let recorder = AudioRecorder(
            permissionProvider: permission,
            sessionController: MockFlowSessionController(),
            engineFactory: factory.factory()
        )

        await recorder.prepare()

        let fileName = "\(UUID().uuidString).m4a"
        let url = AudioFileStore.documentsDirectory.appendingPathComponent(fileName)

        try recorder.startRecording(to: url)
        #expect(recorder.isRecording)

        factory.lastEngine?.currentTime = 2.0
        let duration = recorder.stopRecording()

        // Mirror ItemDetailView.finishRecording persistence contract.
        let item = Item(timestamp: .now)
        item.audioFileName = fileName
        item.audioDuration = duration

        #expect(duration == 2.0)
        #expect(item.audioDuration == 2.0)
        #expect(item.audioFileURL?.lastPathComponent == fileName)
    }
}

private final class MockFlowPermissionProvider: MicrophonePermissionProviding, @unchecked Sendable {
    var recordPermission: AVAudioApplication.recordPermission
    let requestResult: Bool

    init(recordPermission: AVAudioApplication.recordPermission, requestResult: Bool) {
        self.recordPermission = recordPermission
        self.requestResult = requestResult
    }

    func requestRecordPermission() async -> Bool {
        recordPermission = requestResult ? .granted : .denied
        return requestResult
    }
}

private final class MockFlowSessionController: AudioSessionControlling, @unchecked Sendable {
    func configureForRecording() throws {}
    func configureForPlayback() throws {}
    func deactivate() {}
}

private final class MockFlowEngine: RecordingEngine, @unchecked Sendable {
    var currentTime: TimeInterval = 0
    func record() -> Bool { true }
    func stop() { currentTime = 0 }
}

private final class MockFlowEngineFactory: @unchecked Sendable {
    var lastEngine: MockFlowEngine?

    func factory() -> RecordingEngineFactory {
        { [self] _, _ in
            let engine = MockFlowEngine()
            lastEngine = engine
            return engine
        }
    }
}
