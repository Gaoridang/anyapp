//
//  AudioRecorderSmokeHarness.swift
//  anyapp
//
//  Lightweight in-process smoke exercise for shipped AudioRecorder APIs.
//  Invoked from scratch build scripts — not from the Xcode test runner.
//

import AVFoundation
import Foundation

#if SMOKE_RUNNER
private final class SmokePermissionProvider: MicrophonePermissionProviding, @unchecked Sendable {
    var recordPermission: AVAudioApplication.recordPermission = .granted

    func requestRecordPermission() async -> Bool {
        recordPermission = .granted
        return true
    }
}

private final class SmokeSessionConfigurator: AudioSessionConfiguring, @unchecked Sendable {
    var configureCallCount = 0
    var deactivateCallCount = 0

    func deactivateSession() throws {
        deactivateCallCount += 1
    }

    func configureForRecording() throws {
        configureCallCount += 1
    }

    func configureForPlayback() throws {}
}

private final class SmokeCapture: RecordingCapturing, @unchecked Sendable {
    var currentTime: TimeInterval = 1.25
    var isMeteringEnabled = false
    private(set) var didPrepare = false
    private(set) var didRecord = false

    func prepareToRecord() -> Bool {
        didPrepare = true
        return true
    }

    func record() -> Bool {
        didRecord = true
        return true
    }

    func stop() {}
}

private final class SmokeCaptureMaker: RecordingCaptureMaking, @unchecked Sendable {
    var lastCapture: SmokeCapture?

    func makeRecorder(url: URL, settings: [String: Any]) throws -> any RecordingCapturing {
        let capture = SmokeCapture()
        lastCapture = capture
        return capture
    }
}

enum AudioRecorderSmokeHarness {
    @MainActor
    static func run() async -> String {
        var lines: [String] = []

        let permission = SmokePermissionProvider()
        let session = SmokeSessionConfigurator()
        let captureMaker = SmokeCaptureMaker()
        let recorder = AudioRecorder(
            permissionProvider: permission,
            sessionConfigurator: session,
            captureMaker: captureMaker
        )

        await recorder.prepare()
        lines.append("prepare: isPrepared=\(recorder.isPrepared) canRecord=\(recorder.canRecord) state=\(recorder.state)")

        guard recorder.canRecord else {
            lines.append("FAIL: canRecord false after prepare")
            return lines.joined(separator: "\n")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).m4a")

        do {
            try recorder.startRecording(to: url)
        } catch {
            lines.append("FAIL: startRecording threw \(error)")
            return lines.joined(separator: "\n")
        }

        lines.append("start: state=\(recorder.state) isRecording=\(recorder.isRecording)")
        guard recorder.isRecording else {
            lines.append("FAIL: not recording after start")
            return lines.joined(separator: "\n")
        }

        let duration = recorder.stopRecording()
        lines.append("stop: duration=\(duration.map(String.init(describing:)) ?? "nil") state=\(recorder.state)")
        lines.append("session: configure=\(session.configureCallCount) deactivate=\(session.deactivateCallCount)")
        lines.append("capture: prepare=\(captureMaker.lastCapture?.didPrepare == true) record=\(captureMaker.lastCapture?.didRecord == true)")

        if let duration, duration > 0,
           captureMaker.lastCapture?.didPrepare == true,
           captureMaker.lastCapture?.didRecord == true,
           session.configureCallCount >= 1 {
            lines.append("PASS")
        } else {
            lines.append("FAIL: unexpected stop result")
        }

        return lines.joined(separator: "\n")
    }
}

@main
struct SmokeRunner {
    static func main() async {
        let output = await AudioRecorderSmokeHarness.run()
        print(output)
        fputs(output + "\n", stderr)
        if output.contains("PASS") {
            exit(0)
        }
        exit(1)
    }
}
#endif