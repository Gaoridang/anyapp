//
//  AudioRecorderSmokeHarness.swift
//  anyapp
//
//  Scratch-only integrated smoke (`swiftc -DSMOKE_RUNNER`). Not linked in normal app builds.
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
    var lastCapture: SmokeCapture?

    func makeRecorder(url: URL, settings: [String: Any]) throws -> any RecordingCapturing {
        let capture = SmokeCapture()
        lastCapture = capture
        return capture
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
        let fileName = "\(UUID().uuidString).m4a"
        let url = AudioFileStore.documentsDirectory.appendingPathComponent(fileName)

        do {
            try recorder.startRecording(to: url)
        } catch {
            lines.append("FAIL: mock start \(error)")
            return lines.joined(separator: "\n")
        }

        try? await Task.sleep(for: .milliseconds(150))

        let result = RecordingFinishCoordinator.finish(
            recorder: recorder,
            item: item,
            pendingFileName: fileName
        )

        lines.append("mock-finish: savedURL=\(result.savedURL?.lastPathComponent ?? "nil") fileName=\(item.audioFileName ?? "nil") duration=\(item.audioDuration.map(String.init(describing:)) ?? "nil") error=\(result.errorMessage ?? "nil")")

        if result.savedURL != nil,
           item.audioFileName == fileName,
           let duration = item.audioDuration, duration > 0 {
            lines.append("INTEGRATED_PASS")
        } else {
            lines.append("FAIL: mock integrated finish")
        }

        return lines.joined(separator: "\n")
    }

    @MainActor
    static func runLiveIntegrated() async -> String {
        var lines: [String] = []
        let item = SmokeFinishItem()
        let recorder = AudioRecorder()

        await recorder.prepare()
        lines.append("live-prepare: canRecord=\(recorder.canRecord)")

        guard recorder.canRecord else {
            lines.append("INTEGRATED_SKIP: microphone permission not granted for standalone runner")
            return lines.joined(separator: "\n")
        }

        let fileName = "live-integrated-\(UUID().uuidString).m4a"
        let url = AudioFileStore.documentsDirectory.appendingPathComponent(fileName)

        do {
            try recorder.startRecording(to: url)
        } catch {
            lines.append("FAIL: live start \(error)")
            return lines.joined(separator: "\n")
        }

        try? await Task.sleep(for: .milliseconds(500))

        let result = RecordingFinishCoordinator.finish(
            recorder: recorder,
            item: item,
            pendingFileName: fileName
        )

        let exists = FileManager.default.fileExists(atPath: url.path)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
        lines.append("live-finish: savedURL=\(result.savedURL?.lastPathComponent ?? "nil") fileName=\(item.audioFileName ?? "nil") duration=\(item.audioDuration.map(String.init(describing:)) ?? "nil") exists=\(exists) size=\(size)")

        if result.savedURL != nil,
           item.audioFileName == fileName,
           let duration = item.audioDuration, duration > 0,
           exists, size > 0 {
            lines.append("INTEGRATED_PASS")
        } else {
            lines.append("FAIL: live integrated finish")
        }

        return lines.joined(separator: "\n")
    }
}

@main
struct SmokeRunner {
    static func main() async {
        let mode = CommandLine.arguments.contains("live") ? "live" : "mock"
        let output: String
        if mode == "live" {
            output = await IntegratedSmokeHarness.runLiveIntegrated()
        } else {
            output = await IntegratedSmokeHarness.runMockIntegrated()
        }
        print(output)
        fputs(output + "\n", stderr)
        let ok = output.contains("INTEGRATED_PASS") || output.contains("INTEGRATED_SKIP")
        exit(ok ? 0 : 1)
    }
}
#endif