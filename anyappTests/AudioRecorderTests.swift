//
//  AudioRecorderTests.swift
//  anyappTests
//

import AVFoundation
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

    func deactivateSession() throws {
        deactivateCallCount += 1
    }

    func configureForRecording() throws {
        configureCallCount += 1
        if let configureError {
            throw configureError
        }
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