//
//  AudioRecorderTests.swift
//  anyappTests
//

import AVFoundation
import Foundation
import Testing
@testable import anyapp

// MARK: - Mocks

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

private final class MockSessionController: AudioSessionControlling, @unchecked Sendable {
    var configureRecordingCount = 0
    var configurePlaybackCount = 0
    var deactivateCount = 0
    var configureError: Error?

    func configureForRecording() throws {
        configureRecordingCount += 1
        if let configureError { throw configureError }
    }

    func configureForPlayback() throws {
        configurePlaybackCount += 1
    }

    func deactivate() {
        deactivateCount += 1
    }
}

private final class MockEngine: RecordingEngine, @unchecked Sendable {
    var currentTime: TimeInterval = 0
    var recordResult = true
    private(set) var didRecord = false
    private(set) var didStop = false

    func record() -> Bool {
        didRecord = recordResult
        return recordResult
    }

    func stop() {
        didStop = true
        currentTime = 0
    }
}

private final class MockEngineFactory: @unchecked Sendable {
    var lastEngine: MockEngine?
    var makeError: Error?
    var recordResult = true

    func factory() -> RecordingEngineFactory {
        { [self] _, _ in
            if let makeError { throw makeError }
            let engine = MockEngine()
            engine.recordResult = recordResult
            lastEngine = engine
            return engine
        }
    }
}

// MARK: - Tests

@MainActor
struct AudioRecorderTests {
    private func makeRecorder(
        permission: MockPermissionProvider,
        session: MockSessionController = MockSessionController(),
        factory: MockEngineFactory = MockEngineFactory()
    ) -> AudioRecorder {
        AudioRecorder(
            permissionProvider: permission,
            sessionController: session,
            engineFactory: factory.factory()
        )
    }

    private var tempURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
    }

    @Test func prepareDeniedSetsPermissionDenied() async {
        let recorder = makeRecorder(permission: MockPermissionProvider(requestResult: false))
        await recorder.prepare()

        #expect(recorder.isPrepared)
        #expect(recorder.state == .permissionDenied)
        #expect(!recorder.canRecord)
        #expect(!recorder.isRecording)
    }

    @Test func prepareGrantedEnablesRecording() async {
        let recorder = makeRecorder(permission: MockPermissionProvider(requestResult: true))
        await recorder.prepare()

        #expect(recorder.isPrepared)
        #expect(recorder.state == .idle)
        #expect(recorder.canRecord)
    }

    @Test func startBeforePrepareThrowsNotPrepared() async {
        let recorder = makeRecorder(permission: MockPermissionProvider(recordPermission: .granted))

        #expect(throws: AudioRecorder.RecordingError.notPrepared) {
            try recorder.startRecording(to: tempURL)
        }
        #expect(!recorder.isRecording)
    }

    @Test func startWithoutPermissionThrowsAndSkipsSession() async {
        let session = MockSessionController()
        let recorder = makeRecorder(
            permission: MockPermissionProvider(recordPermission: .denied, requestResult: false),
            session: session
        )
        await recorder.prepare()

        #expect(throws: AudioRecorder.RecordingError.permissionDenied) {
            try recorder.startRecording(to: tempURL)
        }
        #expect(recorder.state == .permissionDenied)
        #expect(session.configureRecordingCount == 0)
    }

    @Test func startSuccessEntersRecordingState() async throws {
        let session = MockSessionController()
        let factory = MockEngineFactory()
        let recorder = makeRecorder(
            permission: MockPermissionProvider(recordPermission: .granted, requestResult: true),
            session: session,
            factory: factory
        )
        await recorder.prepare()

        try recorder.startRecording(to: tempURL)

        #expect(recorder.state == .recording)
        #expect(recorder.isRecording)
        #expect(factory.lastEngine?.didRecord == true)
        #expect(session.configureRecordingCount == 1)
    }

    @Test func elapsedTimerAdvancesWhileRecording() async throws {
        let factory = MockEngineFactory()
        let recorder = makeRecorder(
            permission: MockPermissionProvider(recordPermission: .granted, requestResult: true),
            factory: factory
        )
        await recorder.prepare()
        try recorder.startRecording(to: tempURL)

        factory.lastEngine?.currentTime = 1.5
        try await Task.sleep(for: .milliseconds(250))

        #expect(recorder.elapsedTime >= 1.0)
    }

    @Test func stopReturnsDurationAndResetsToIdle() async throws {
        let session = MockSessionController()
        let factory = MockEngineFactory()
        let recorder = makeRecorder(
            permission: MockPermissionProvider(recordPermission: .granted, requestResult: true),
            session: session,
            factory: factory
        )
        await recorder.prepare()
        try recorder.startRecording(to: tempURL)

        factory.lastEngine?.currentTime = 2.5
        let duration = recorder.stopRecording()

        #expect(duration == 2.5)
        #expect(recorder.state == .idle)
        #expect(!recorder.isRecording)
        #expect(factory.lastEngine?.didStop == true)
        #expect(session.deactivateCount >= 1)
    }

    @Test func stopFallsBackToElapsedWhenCaptureTimeIsZero() async throws {
        let factory = MockEngineFactory()
        let recorder = makeRecorder(
            permission: MockPermissionProvider(recordPermission: .granted, requestResult: true),
            factory: factory
        )
        await recorder.prepare()
        try recorder.startRecording(to: tempURL)

        factory.lastEngine?.currentTime = 1.8
        try await Task.sleep(for: .milliseconds(250))
        factory.lastEngine?.currentTime = 0

        let duration = recorder.stopRecording()
        #expect(duration == 1.8)
    }

    @Test func stopWhenIdleReturnsNil() async {
        let recorder = makeRecorder(permission: MockPermissionProvider(requestResult: true))
        await recorder.prepare()

        #expect(recorder.stopRecording() == nil)
        #expect(recorder.state == .idle)
    }

    @Test func stopDoesNotTriggerPlaybackSession() async throws {
        // Guards the core crash-safety invariant: stopping only tears down and never
        // starts any additional audio/session activity beyond deactivation.
        let session = MockSessionController()
        let recorder = makeRecorder(
            permission: MockPermissionProvider(recordPermission: .granted, requestResult: true),
            session: session
        )
        await recorder.prepare()
        try recorder.startRecording(to: tempURL)
        _ = recorder.stopRecording()

        #expect(session.configurePlaybackCount == 0)
    }

    @Test func sessionConfigureFailureSurfacesErrorState() async {
        let session = MockSessionController()
        session.configureError = NSError(domain: "test", code: 1)
        let recorder = makeRecorder(
            permission: MockPermissionProvider(recordPermission: .granted, requestResult: true),
            session: session
        )
        await recorder.prepare()

        #expect(throws: (any Error).self) {
            try recorder.startRecording(to: tempURL)
        }
        #expect(recorder.state == .error("오디오 세션을 설정할 수 없습니다."))
        #expect(session.deactivateCount == 1)
    }

    @Test func errorStateClearsOnRetry() async {
        let session = MockSessionController()
        session.configureError = NSError(domain: "test", code: 1)
        let recorder = makeRecorder(
            permission: MockPermissionProvider(recordPermission: .granted, requestResult: true),
            session: session
        )
        await recorder.prepare()

        _ = try? recorder.startRecording(to: tempURL)
        #expect(recorder.state == .error("오디오 세션을 설정할 수 없습니다."))

        recorder.clearErrorState()
        #expect(recorder.state == .idle)
        #expect(recorder.canRecord)
    }

    @Test func engineCreationFailureSurfacesErrorAndDeactivates() async {
        let session = MockSessionController()
        let factory = MockEngineFactory()
        factory.makeError = NSError(domain: "test", code: 2)
        let recorder = makeRecorder(
            permission: MockPermissionProvider(recordPermission: .granted, requestResult: true),
            session: session,
            factory: factory
        )
        await recorder.prepare()

        #expect(throws: (any Error).self) {
            try recorder.startRecording(to: tempURL)
        }
        #expect(recorder.state == .error("녹음 장치를 초기화할 수 없습니다."))
        #expect(session.deactivateCount == 1)
        #expect(!recorder.isRecording)
    }
}
