//
//  RecordingIntegrationTests.swift
//  anyappTests
//

import AVFoundation
import Foundation
import Testing
@testable import anyapp

@MainActor
struct RecordingIntegrationTests {
    /// Exercises the real AVAudioRecorder start/stop path — the historical crash
    /// area. Skips gracefully when the test host has no microphone permission.
    @Test func liveRecorderStartStopProducesNonEmptyFile() async throws {
        let recorder = AudioRecorder()
        await recorder.prepare()

        guard recorder.canRecord else {
            Issue.record("Microphone permission not granted — skipping live capture")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).m4a")

        try recorder.startRecording(to: url)
        #expect(recorder.state == .recording)

        try await Task.sleep(for: .milliseconds(500))

        let duration = recorder.stopRecording()
        #expect(recorder.state == .idle)
        #expect(duration != nil)
        #expect((duration ?? 0) > 0)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
        #expect(size > 0)

        try? FileManager.default.removeItem(at: url)
    }
}
