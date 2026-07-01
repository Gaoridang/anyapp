//
//  AudioRecorderSmokeHarness.swift
//  anyapp
//
//  Scratch-only smoke (`swiftc -DSMOKE_RUNNER`). Exercises ItemDetailRecordingFinish.finishRecordingIfNeeded.
//

import AVFoundation
import Foundation

#if SMOKE_RUNNER
private final class SmokeFinishItem: RecordingFinishItem, @unchecked Sendable {
    var audioFileName: String?
    var audioDuration: TimeInterval?
}

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
    var currentTime: TimeInterval = 0
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

enum IntegratedSmokeHarness {
    @MainActor
    static func runMockIntegrated() async -> String {
        var lines: [String] = []
        let item = SmokeFinishItem()
        let recorder = AudioRecorder(
            permissionProvider: SmokePermissionProvider(),
            sessionConfigurator: SmokeSessionConfigurator(),
            captureMaker: SmokeCaptureMaker()
        )

        await recorder.prepare()
        var pendingFileName: String? = "\(UUID().uuidString).m4a"
        let url = AudioFileStore.documentsDirectory.appendingPathComponent(pendingFileName!)

        do {
            try recorder.startRecording(to: url)
        } catch {
            lines.append("FAIL: startRecording \(error)")
            return lines.joined(separator: "\n")
        }

        lines.append("start: state=\(recorder.state) isRecording=\(recorder.isRecording)")
        guard recorder.isRecording else {
            lines.append("FAIL: expected .recording after start")
            return lines.joined(separator: "\n")
        }

        try? await Task.sleep(for: .milliseconds(150))

        let result = ItemDetailRecordingFinish.finishRecordingIfNeeded(
            recorder: recorder,
            item: item,
            pendingFileName: &pendingFileName
        )

        lines.append("finishRecordingIfNeeded: savedURL=\(result.savedURL?.lastPathComponent ?? "nil") fileName=\(item.audioFileName ?? "nil") duration=\(item.audioDuration.map(String.init(describing:)) ?? "nil") pendingCleared=\(pendingFileName == nil)")

        if result.savedURL != nil,
           item.audioFileName != nil,
           let duration = item.audioDuration, duration > 0,
           pendingFileName == nil {
            lines.append("INTEGRATED_PASS")
        } else {
            lines.append("FAIL: finishRecordingIfNeeded persist")
        }

        return lines.joined(separator: "\n")
    }
}

@main
struct SmokeRunner {
    static func main() async {
        let output = await IntegratedSmokeHarness.runMockIntegrated()
        print(output)
        fputs(output + "\n", stderr)
        exit(output.contains("INTEGRATED_PASS") ? 0 : 1)
    }
}
#endif