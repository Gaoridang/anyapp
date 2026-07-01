//
//  AudioRecorderTests.swift
//  anyappTests
//

import AVFoundation
import Foundation
import Testing
@testable import anyapp

private final class MockPermissionProvider: MicrophonePermissionProviding, @unchecked Sendable {
    var recordPermission: AVAudioApplication.recordPermission
    var requestResult: Bool

    init(
        recordPermission: AVAudioApplication.recordPermission = .undetermined,
        requestResult: Bool = false
    ) {
        self.recordPermission = recordPermission
        self.requestResult = requestResult
    }

    func requestRecordPermission() async -> Bool {
        recordPermission = requestResult ? .granted : .denied
        return requestResult
    }
}

private final class MockSessionConfigurator: AudioSessionConfiguring, @unchecked Sendable {
    var deactivateCallCount = 0
    var configureCallCount = 0
    var configureError: Error?

    func deactivateSession() {
        deactivateCallCount += 1
    }

    func configureForRecording() throws {
        configureCallCount += 1
        if let configureError {
            throw configureError
        }
    }

    func configureForPlayback() throws {}
}

private final class MockRecordingCapture: RecordingCapturing, @unchecked Sendable {
    var currentTime: TimeInterval = 0
    var isMeteringEnabled = false
    var recordResult = true
    private(set) var didPrepare = false
    private(set) var didRecord = false
    private(set) var didStop = false

    func prepareToRecord() -> Bool {
        didPrepare = true
        return true
    }

    func record() -> Bool {
        didRecord = recordResult
        return recordResult
    }

    func stop() {
        didStop = true
    }
}

private final class MockRecordingCaptureMaker: RecordingCaptureMaking, @unchecked Sendable {
    var lastCapture: MockRecordingCapture?
    var makeError: Error?

    func makeRecorder(url: URL, settings: [String: Any]) throws -> any RecordingCapturing {
        if let makeError {
            throw makeError
        }
        let capture = MockRecordingCapture()
        lastCapture = capture
        return capture
    }
}

@MainActor
struct AudioRecorderTests {
    @Test func prepareDeniedSetsPermissionDeniedAndDisablesRecording() async {
        let permission = MockPermissionProvider(requestResult: false)
        let recorder = AudioRecorder(permissionProvider: permission)

        await recorder.prepare()

        #expect(recorder.isPrepared)
        #expect(recorder.state == .permissionDenied)
        #expect(!recorder.canRecord)
        #expect(!recorder.isRecording)
    }

    @Test func prepareGrantedEnablesRecording() async {
        let permission = MockPermissionProvider(requestResult: true)
        let recorder = AudioRecorder(permissionProvider: permission)

        await recorder.prepare()

        #expect(recorder.isPrepared)
        #expect(recorder.state == .idle)
        #expect(recorder.canRecord)
        #expect(!recorder.isRecording)
    }

    @Test func startRecordingBeforePrepareThrowsNotPrepared() async {
        let permission = MockPermissionProvider(recordPermission: .granted, requestResult: true)
        let recorder = AudioRecorder(permissionProvider: permission)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")

        do {
            try recorder.startRecording(to: url)
            Issue.record("Expected notPrepared error")
        } catch let error as AudioRecorder.RecordingError {
            #expect(error == .notPrepared)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(!recorder.isRecording)
        #expect(!recorder.canRecord)
    }

    @Test func startRecordingWithoutPermissionSetsDeniedState() async {
        let permission = MockPermissionProvider(recordPermission: .denied, requestResult: false)
        let session = MockSessionConfigurator()
        let recorder = AudioRecorder(
            permissionProvider: permission,
            sessionConfigurator: session
        )

        await recorder.prepare()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")

        do {
            try recorder.startRecording(to: url)
            Issue.record("Expected permissionDenied error")
        } catch let error as AudioRecorder.RecordingError {
            #expect(error == .permissionDenied)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(recorder.state == .permissionDenied)
        #expect(!recorder.canRecord)
        #expect(!recorder.isRecording)
        #expect(session.configureCallCount == 0)
    }

    @Test func startRecordingSuccessEntersRecordingState() async throws {
        let permission = MockPermissionProvider(recordPermission: .granted, requestResult: true)
        let session = MockSessionConfigurator()
        let captureMaker = MockRecordingCaptureMaker()
        let recorder = AudioRecorder(
            permissionProvider: permission,
            sessionConfigurator: session,
            captureMaker: captureMaker
        )

        await recorder.prepare()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")

        try recorder.startRecording(to: url)

        #expect(recorder.state == .recording)
        #expect(recorder.isRecording)
        #expect(captureMaker.lastCapture?.didRecord == true)
        #expect(session.configureCallCount == 1)
    }

    @Test func elapsedTimerUpdatesWhileRecording() async throws {
        let permission = MockPermissionProvider(recordPermission: .granted, requestResult: true)
        let captureMaker = MockRecordingCaptureMaker()
        let recorder = AudioRecorder(
            permissionProvider: permission,
            captureMaker: captureMaker
        )

        await recorder.prepare()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        try recorder.startRecording(to: url)

        let initialElapsed = recorder.elapsedTime
        captureMaker.lastCapture?.currentTime = 1.5
        try await Task.sleep(for: .milliseconds(200))

        #expect(recorder.elapsedTime > initialElapsed)
        #expect(recorder.elapsedTime >= 1.0)
    }

    @Test func stopRecordingReturnsDurationAndResetsState() async throws {
        let permission = MockPermissionProvider(recordPermission: .granted, requestResult: true)
        let session = MockSessionConfigurator()
        let captureMaker = MockRecordingCaptureMaker()
        let recorder = AudioRecorder(
            permissionProvider: permission,
            sessionConfigurator: session,
            captureMaker: captureMaker
        )

        await recorder.prepare()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        try recorder.startRecording(to: url)

        captureMaker.lastCapture?.currentTime = 2.5
        let duration = recorder.stopRecording()

        #expect(duration == 2.5)
        #expect(recorder.state == .idle)
        #expect(!recorder.isRecording)
        #expect(captureMaker.lastCapture?.didStop == true)
        #expect(session.deactivateCallCount >= 1)
    }

    @Test func stopRecordingWhenIdleReturnsNil() async {
        let permission = MockPermissionProvider(requestResult: true)
        let recorder = AudioRecorder(permissionProvider: permission)

        await recorder.prepare()

        #expect(recorder.stopRecording() == nil)
        #expect(recorder.state == .idle)
    }

    @Test func sessionConfigureFailureSurfacesErrorState() async {
        let permission = MockPermissionProvider(recordPermission: .granted, requestResult: true)
        let session = MockSessionConfigurator()
        session.configureError = NSError(domain: "test", code: 1)
        let recorder = AudioRecorder(
            permissionProvider: permission,
            sessionConfigurator: session
        )

        await recorder.prepare()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")

        do {
            try recorder.startRecording(to: url)
            Issue.record("Expected configure error")
        } catch {
            #expect(session.deactivateCallCount == 1)
            #expect(session.configureCallCount == 1)
        }

        #expect(!recorder.isRecording)
        #expect(recorder.state == .error("오디오 세션을 설정할 수 없습니다."))
        #expect(recorder.lastErrorMessage == "오디오 세션을 설정할 수 없습니다.")
    }

    @Test func errorStateClearsOnRetryAfterSessionFailure() async {
        let permission = MockPermissionProvider(recordPermission: .granted, requestResult: true)
        let session = MockSessionConfigurator()
        session.configureError = NSError(domain: "test", code: 1)
        let recorder = AudioRecorder(
            permissionProvider: permission,
            sessionConfigurator: session
        )

        await recorder.prepare()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")

        _ = try? recorder.startRecording(to: url)
        #expect(recorder.state == .error("오디오 세션을 설정할 수 없습니다."))
        #expect(recorder.canRecord)

        recorder.clearErrorState()
        #expect(recorder.state == .idle)
        #expect(recorder.canRecord)
    }
}