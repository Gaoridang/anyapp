//
//  AudioRecorder.swift
//  anyapp
//

import AVFoundation
import Observation

protocol MicrophonePermissionProviding: Sendable {
    var recordPermission: AVAudioApplication.recordPermission { get }
    func requestRecordPermission() async -> Bool
}

protocol AudioSessionConfiguring: Sendable {
    func deactivateSession() throws
    func configureForRecording() throws
}

protocol RecordingCapturing: AnyObject {
    var currentTime: TimeInterval { get }
    var isMeteringEnabled: Bool { get set }
    func prepareToRecord() -> Bool
    func record() -> Bool
    func stop()
}

protocol RecordingCaptureMaking: Sendable {
    func makeRecorder(url: URL, settings: [String: Any]) throws -> any RecordingCapturing
}

struct SystemMicrophonePermissionProvider: MicrophonePermissionProviding {
    var recordPermission: AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}

struct SystemAudioSessionConfigurator: AudioSessionConfiguring {
    func deactivateSession() throws {
        try AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    func configureForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker]
        )
        try session.setActive(true)
    }
}

final class AVAudioRecorderCapture: RecordingCapturing {
    private let recorder: AVAudioRecorder

    init(recorder: AVAudioRecorder) {
        self.recorder = recorder
    }

    var currentTime: TimeInterval { recorder.currentTime }
    var isMeteringEnabled: Bool {
        get { recorder.isMeteringEnabled }
        set { recorder.isMeteringEnabled = newValue }
    }

    func prepareToRecord() -> Bool { recorder.prepareToRecord() }
    func record() -> Bool { recorder.record() }
    func stop() { recorder.stop() }
}

struct SystemRecordingCaptureMaker: RecordingCaptureMaking {
    func makeRecorder(url: URL, settings: [String: Any]) throws -> any RecordingCapturing {
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        return AVAudioRecorderCapture(recorder: recorder)
    }
}

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
        case permissionDenied
        case notPrepared
        case failedToStart

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "마이크 권한이 필요합니다. 설정에서 허용해 주세요."
            case .notPrepared:
                "녹음을 준비하는 중입니다. 잠시 후 다시 시도해 주세요."
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
    private let sessionConfigurator: any AudioSessionConfiguring
    private let captureMaker: any RecordingCaptureMaking
    private var recorder: (any RecordingCapturing)?
    private var tickTask: Task<Void, Never>?

    init(
        permissionProvider: any MicrophonePermissionProviding = SystemMicrophonePermissionProvider(),
        sessionConfigurator: any AudioSessionConfiguring = SystemAudioSessionConfigurator(),
        captureMaker: any RecordingCaptureMaking = SystemRecordingCaptureMaker()
    ) {
        self.permissionProvider = permissionProvider
        self.sessionConfigurator = sessionConfigurator
        self.captureMaker = captureMaker
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

    func startRecording(to url: URL) throws {
        guard isPrepared else {
            throw RecordingError.notPrepared
        }

        guard permissionProvider.recordPermission == .granted else {
            state = .permissionDenied
            throw RecordingError.permissionDenied
        }

        clearErrorState()

        do {
            try sessionConfigurator.deactivateSession()
            try sessionConfigurator.configureForRecording()
        } catch {
            state = .error("오디오 세션을 설정할 수 없습니다.")
            throw error
        }

        do {
            recorder = try captureMaker.makeRecorder(url: url, settings: Self.recordingSettings)
        } catch {
            state = .error("녹음 장치를 초기화할 수 없습니다.")
            throw error
        }

        recorder?.isMeteringEnabled = false
        recorder?.prepareToRecord()

        guard recorder?.record() == true else {
            recorder = nil
            state = .error(RecordingError.failedToStart.errorDescription ?? "녹음을 시작할 수 없습니다.")
            throw RecordingError.failedToStart
        }

        elapsedTime = 0
        state = .recording
        startElapsedTimer()
    }

    func stopRecording() -> TimeInterval? {
        guard isRecording else { return nil }

        stopElapsedTimer()

        // AVAudioRecorder.currentTime resets to 0 after stop(), so capture first.
        let duration = max(recorder?.currentTime ?? 0, elapsedTime)
        recorder?.stop()
        recorder = nil

        try? sessionConfigurator.deactivateSession()
        state = .idle

        return duration > 0 ? duration : nil
    }

    private func startElapsedTimer() {
        stopElapsedTimer()
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, self.isRecording else { break }
                self.elapsedTime = self.recorder?.currentTime ?? self.elapsedTime
            }
        }
    }

    private func stopElapsedTimer() {
        tickTask?.cancel()
        tickTask = nil
    }

    func clearErrorState() {
        if case .error = state {
            state = .idle
        }
    }
}