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
    @Test func liveRecorderStartStopProducesNonEmptyFile() async throws {
        let recorder = AudioRecorder()
        await recorder.prepare()

        guard recorder.canRecord else {
            Issue.record("Microphone permission not granted in test environment — skipping live capture")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).m4a")

        try recorder.startRecording(to: url)
        #expect(recorder.state == .recording)

        try await Task.sleep(for: .milliseconds(500))
        #expect(recorder.elapsedTime >= 0)

        let duration = recorder.stopRecording()
        #expect(duration != nil)
        #expect(duration! > 0)

        let fileExists = FileManager.default.fileExists(atPath: url.path)
        #expect(fileExists)

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        #expect(fileSize > 0)

        try? FileManager.default.removeItem(at: url)
    }
}