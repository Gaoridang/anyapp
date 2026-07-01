//
//  AudioRecorder.swift
//  anyapp
//

import AVFoundation
import Observation

@Observable
@MainActor
final class AudioRecorder {
    enum State: Equatable {
        case idle
        case recording
        case permissionDenied
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var elapsedTime: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var canRecord: Bool {
        switch state {
        case .permissionDenied, .error:
            return false
        default:
            return true
        }
    }

    func prepare() async {
        let granted = await requestPermission()
        state = granted ? .idle : .permissionDenied
    }

    func startRecording(to url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = false
        recorder?.prepareToRecord()

        guard recorder?.record() == true else {
            state = .error("녹음을 시작할 수 없습니다.")
            throw RecordingError.failedToStart
        }

        elapsedTime = 0
        state = .recording
        startTimer()
    }

    func stopRecording() -> TimeInterval? {
        guard isRecording else { return nil }

        timer?.invalidate()
        timer = nil

        recorder?.stop()
        let duration = recorder?.currentTime ?? elapsedTime
        recorder = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        state = .idle

        return duration > 0 ? duration : nil
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedTime = self.recorder?.currentTime ?? self.elapsedTime
            }
        }
    }

    enum RecordingError: Error {
        case failedToStart
    }
}
