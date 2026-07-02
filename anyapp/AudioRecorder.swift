//
//  AudioRecorder.swift
//  anyapp
//

import AVFoundation
import Observation

/// Abstracts microphone permission so tests can run without a real device.
protocol MicrophonePermissionProviding: Sendable {
    var recordPermission: AVAudioApplication.recordPermission { get }
    func requestRecordPermission() async -> Bool
}

/// Abstracts audio session lifecycle so tests avoid touching `AVAudioSession`.
protocol AudioSessionControlling: Sendable {
    func configureForRecording() throws
    func configureForPlayback() throws
    func deactivate()
}

/// Minimal recording engine seam wrapping `AVAudioRecorder`.
protocol RecordingEngine: AnyObject {
    var currentTime: TimeInterval { get }
    func record() -> Bool
    func stop()
}

/// Builds a `RecordingEngine` for a destination URL. Injectable for tests.
typealias RecordingEngineFactory = @Sendable (_ url: URL, _ settings: [String: Any]) throws -> RecordingEngine

// MARK: - System implementations

struct SystemMicrophonePermissionProvider: MicrophonePermissionProviding {
    var recordPermission: AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

struct SystemAudioSessionController: AudioSessionControlling {
    func configureForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true)
    }

    func configureForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }
}

final class AVAudioRecorderEngine: RecordingEngine {
    private let recorder: AVAudioRecorder

    init(url: URL, settings: [String: Any]) throws {
        recorder = try AVAudioRecorder(url: url, settings: settings)
        _ = recorder.prepareToRecord()
    }

    var currentTime: TimeInterval { recorder.currentTime }
    func record() -> Bool { recorder.record() }
    func stop() { recorder.stop() }
}

// MARK: - AudioRecorder

/// Owns the microphone recording lifecycle.
///
/// Design principle: `stopRecording()` performs *only* synchronous audio-resource
/// teardown and never triggers speech recognition, network calls, or any other
/// async pipeline. Consumers persist the finished file separately.
@Observable
@MainActor
final class AudioRecorder {
    enum State: Equatable {
        case idle
        case recording
        case permissionDenied
        case error(String)
    }

    enum RecordingError: LocalizedError, Equatable {
        case notPrepared
        case permissionDenied
        case failedToStart

        var errorDescription: String? {
            switch self {
            case .notPrepared:
                "녹음을 준비하는 중입니다. 잠시 후 다시 시도해 주세요."
            case .permissionDenied:
                "마이크 권한이 필요합니다. 설정에서 허용해 주세요."
            case .failedToStart:
                "녹음을 시작할 수 없습니다."
            }
        }
    }

    static let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]

    private(set) var state: State = .idle
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var isPrepared = false

    private let permissionProvider: any MicrophonePermissionProviding
    private let sessionController: any AudioSessionControlling
    private let engineFactory: RecordingEngineFactory

    private var engine: (any RecordingEngine)?
    private var tickTask: Task<Void, Never>?
    private var startedAt: Date?

    init(
        permissionProvider: any MicrophonePermissionProviding = SystemMicrophonePermissionProvider(),
        sessionController: any AudioSessionControlling = SystemAudioSessionController(),
        engineFactory: @escaping RecordingEngineFactory = { url, settings in
            try AVAudioRecorderEngine(url: url, settings: settings)
        }
    ) {
        self.permissionProvider = permissionProvider
        self.sessionController = sessionController
        self.engineFactory = engineFactory
    }

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var canRecord: Bool {
        isPrepared && permissionProvider.recordPermission == .granted
    }

    var lastErrorMessage: String? {
        if case .error(let message) = state { return message }
        return nil
    }

    func prepare() async {
        let granted = await permissionProvider.requestRecordPermission()
        isPrepared = true
        state = granted ? .idle : .permissionDenied
    }

    func refreshPermissionState() {
        guard isPrepared, !isRecording else { return }
        switch permissionProvider.recordPermission {
        case .granted:
            if case .permissionDenied = state { state = .idle }
        case .denied:
            state = .permissionDenied
        case .undetermined:
            break
        @unknown default:
            break
        }
    }

    func clearErrorState() {
        if case .error = state { state = .idle }
    }

    // MARK: Recording

    func startRecording(to url: URL) throws {
        guard isPrepared else { throw RecordingError.notPrepared }
        guard permissionProvider.recordPermission == .granted else {
            state = .permissionDenied
            throw RecordingError.permissionDenied
        }

        clearErrorState()

        do {
            try sessionController.configureForRecording()
        } catch {
            sessionController.deactivate()
            state = .error("오디오 세션을 설정할 수 없습니다.")
            throw error
        }

        let newEngine: any RecordingEngine
        do {
            newEngine = try engineFactory(url, Self.recordingSettings)
        } catch {
            sessionController.deactivate()
            state = .error("녹음 장치를 초기화할 수 없습니다.")
            throw error
        }

        guard newEngine.record() else {
            sessionController.deactivate()
            state = .error(RecordingError.failedToStart.errorDescription ?? "녹음을 시작할 수 없습니다.")
            throw RecordingError.failedToStart
        }

        engine = newEngine
        elapsedTime = 0
        startedAt = Date()
        state = .recording
        startTicking()
    }

    /// Synchronously tears down the active recording and returns its duration.
    /// Never triggers any async/speech work — that is the caller's responsibility.
    @discardableResult
    func stopRecording() -> TimeInterval? {
        guard isRecording else { return nil }

        stopTicking()

        // AVAudioRecorder.currentTime resets to 0 after stop(), so read it first.
        let wallClock = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        let duration = max(engine?.currentTime ?? 0, elapsedTime, wallClock)

        engine?.stop()
        engine = nil
        startedAt = nil

        sessionController.deactivate()
        state = .idle

        return duration > 0 ? duration : nil
    }

    // MARK: Playback session

    func activatePlaybackSession() throws {
        try sessionController.configureForPlayback()
    }

    func deactivatePlaybackSession() {
        sessionController.deactivate()
    }

    // MARK: Timer

    private func startTicking() {
        stopTicking()
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, self.isRecording else { break }
                self.elapsedTime = self.engine?.currentTime ?? self.elapsedTime
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }
}
