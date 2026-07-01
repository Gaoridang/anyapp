//
//  AudioRecorderSmokeHarness.swift
//  anyapp
//
//  Scratch-only AudioRecorder API smoke (`swiftc -DSMOKE_RUNNER`). No View/persist path.
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
    func deactivateSession() throws {}
    func configureForRecording() throws {}
}

private final class SmokeCapture: RecordingCapturing, @unchecked Sendable {
    var currentTime: TimeInterval = 1.25
    var isMeteringEnabled = false

    func prepareToRecord() -> Bool { true }
    func record() -> Bool { true }
    func stop() {}
}

private final class SmokeCaptureMaker: RecordingCaptureMaking, @unchecked Sendable {
    func makeRecorder(url: URL, settings: [String: Any]) throws -> any RecordingCapturing {
        SmokeCapture()
    }
}

enum RecorderAPISmokeHarness {
    @MainActor
    static func run() async -> String {
        var lines: [String] = []
        let recorder = AudioRecorder(
            permissionProvider: SmokePermissionProvider(),
            sessionConfigurator: SmokeSessionConfigurator(),
            captureMaker: SmokeCaptureMaker()
        )

        await recorder.prepare()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).m4a")

        do {
            try recorder.startRecording(to: url)
        } catch {
            lines.append("FAIL: startRecording \(error)")
            return lines.joined(separator: "\n")
        }

        lines.append("start: state=\(recorder.state) isRecording=\(recorder.isRecording)")
        guard recorder.isRecording else {
            lines.append("FAIL: expected .recording")
            return lines.joined(separator: "\n")
        }

        let duration = recorder.stopRecording()
        lines.append("stop: duration=\(duration.map(String.init(describing:)) ?? "nil") state=\(recorder.state)")

        if let duration, duration > 0, recorder.state == .idle {
            lines.append("RECORDER_API_PASS")
        } else {
            lines.append("FAIL: recorder stop")
        }

        return lines.joined(separator: "\n")
    }
}

@main
struct SmokeRunner {
    static func main() async {
        let output = await RecorderAPISmokeHarness.run()
        print(output)
        fputs(output + "\n", stderr)
        exit(output.contains("RECORDER_API_PASS") ? 0 : 1)
    }
}
#endif