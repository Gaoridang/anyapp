//
//  RecordingSmokeHarness.swift
//  anyapp
//
//  In-app smoke entry points for scratch scripts (not the Xcode test runner).
//

import AVFoundation
import Foundation
import SwiftData

#if DEBUG
enum RecordingSmokeHarness {
    enum Mode: String {
        case mockRecorder
        case mockPersistence
        case liveRecorder
    }

    @MainActor
    static func run(_ mode: Mode) async -> String {
        switch mode {
        case .mockRecorder:
            return await runMockRecorderSmoke()
        case .mockPersistence:
            return await runMockPersistenceSmoke()
        case .liveRecorder:
            return await runLiveRecorderSmoke()
        }
    }

    @MainActor
    private static func runMockRecorderSmoke() async -> String {
        var lines: [String] = []

        let permission = SmokeHarnessPermissionProvider()
        let session = SmokeHarnessSessionConfigurator()
        let captureMaker = SmokeHarnessCaptureMaker()
        let recorder = AudioRecorder(
            permissionProvider: permission,
            sessionConfigurator: session,
            captureMaker: captureMaker
        )

        await recorder.prepare()
        lines.append("mock-prepare: isPrepared=\(recorder.isPrepared) canRecord=\(recorder.canRecord)")

        guard recorder.canRecord else {
            lines.append("FAIL: canRecord false")
            return lines.joined(separator: "\n")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).m4a")

        do {
            try recorder.startRecording(to: url)
        } catch {
            lines.append("FAIL: startRecording \(error)")
            return lines.joined(separator: "\n")
        }

        let duration = recorder.stopRecording()
        lines.append("mock-stop: duration=\(duration.map(String.init(describing:)) ?? "nil") state=\(recorder.state)")

        if let duration, duration > 0, recorder.state == .idle {
            lines.append("MOCK_RECORDER_PASS")
        } else {
            lines.append("FAIL: mock recorder stop")
        }

        return lines.joined(separator: "\n")
    }

    @MainActor
    private static func runMockPersistenceSmoke() async -> String {
        var lines: [String] = []

        let permission = SmokeHarnessPermissionProvider()
        let captureMaker = SmokeHarnessCaptureMaker()
        let recorder = AudioRecorder(
            permissionProvider: permission,
            sessionConfigurator: SmokeHarnessSessionConfigurator(),
            captureMaker: captureMaker
        )

        let container = try! ModelContainer(
            for: Item.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let item = Item(timestamp: .now)
        container.mainContext.insert(item)

        await recorder.prepare()
        let fileName = "\(UUID().uuidString).m4a"
        let url = AudioFileStore.documentsDirectory.appendingPathComponent(fileName)

        do {
            try recorder.startRecording(to: url)
        } catch {
            lines.append("FAIL: persistence start \(error)")
            return lines.joined(separator: "\n")
        }

        captureMaker.lastCapture?.currentTime = 2.0
        let duration = recorder.stopRecording()

        let savedURL = RecordingPersistence.persistStoppedRecording(
            on: item,
            pendingFileName: fileName,
            duration: duration
        )

        lines.append("persist: fileName=\(item.audioFileName ?? "nil") duration=\(item.audioDuration.map(String.init(describing:)) ?? "nil") url=\(savedURL?.lastPathComponent ?? "nil")")

        if item.audioFileName == fileName,
           let persistedDuration = item.audioDuration, persistedDuration > 0,
           savedURL?.lastPathComponent == fileName {
            lines.append("MOCK_PERSIST_PASS")
        } else {
            lines.append("FAIL: persistence metadata")
        }

        return lines.joined(separator: "\n")
    }

    @MainActor
    private static func runLiveRecorderSmoke() async -> String {
        var lines: [String] = []
        let recorder = AudioRecorder()

        await recorder.prepare()
        lines.append("live-prepare: canRecord=\(recorder.canRecord) permission=\(AVAudioApplication.shared.recordPermission.rawValue)")

        guard recorder.canRecord else {
            lines.append("LIVE_SKIP: microphone permission not granted")
            return lines.joined(separator: "\n")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("live-smoke-\(UUID().uuidString).m4a")

        do {
            try recorder.startRecording(to: url)
        } catch {
            lines.append("FAIL: live start \(error)")
            return lines.joined(separator: "\n")
        }

        lines.append("live-start: isRecording=\(recorder.isRecording)")
        try? await Task.sleep(for: .milliseconds(500))

        let duration = recorder.stopRecording()
        let exists = FileManager.default.fileExists(atPath: url.path)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
        lines.append("live-stop: duration=\(duration.map(String.init(describing:)) ?? "nil") exists=\(exists) size=\(size)")

        try? FileManager.default.removeItem(at: url)

        if exists, size > 0, let duration, duration > 0 {
            lines.append("LIVE_RECORDER_PASS")
        } else if exists, size > 0 {
            lines.append("LIVE_RECORDER_PASS: file_bytes=\(size) duration_unavailable")
        } else {
            lines.append("FAIL: live capture empty")
        }

        return lines.joined(separator: "\n")
    }
}

private final class SmokeHarnessPermissionProvider: MicrophonePermissionProviding, @unchecked Sendable {
    var recordPermission: AVAudioApplication.recordPermission = .granted

    func requestRecordPermission() async -> Bool {
        recordPermission = .granted
        return true
    }
}

private final class SmokeHarnessSessionConfigurator: AudioSessionConfiguring, @unchecked Sendable {
    func deactivateSession() throws {}
    func configureForRecording() throws {}
}

private final class SmokeHarnessCapture: RecordingCapturing, @unchecked Sendable {
    var currentTime: TimeInterval = 1.25
    var isMeteringEnabled = false

    func prepareToRecord() -> Bool { true }
    func record() -> Bool { true }
    func stop() {}
}

private final class SmokeHarnessCaptureMaker: RecordingCaptureMaking, @unchecked Sendable {
    var lastCapture: SmokeHarnessCapture?

    func makeRecorder(url: URL, settings: [String: Any]) throws -> any RecordingCapturing {
        let capture = SmokeHarnessCapture()
        lastCapture = capture
        return capture
    }
}
#endif