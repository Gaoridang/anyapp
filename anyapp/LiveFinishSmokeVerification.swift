//
//  LiveFinishSmokeVerification.swift
//  anyapp
//
//  DEBUG-only live verification: real AVAudioRecorder + ItemDetailRecordingFinish.finishRecordingIfNeeded on Item.
//

import AVFoundation
import Foundation
import SwiftData

#if DEBUG
enum LiveFinishSmokeVerification {
    @MainActor
    static func run() async -> String {
        var lines: [String] = []
        let recorder = AudioRecorder()

        await recorder.prepare()
        lines.append("live-prepare: canRecord=\(recorder.canRecord) permission=\(AVAudioApplication.shared.recordPermission.rawValue)")

        guard recorder.canRecord else {
            lines.append("LIVE_SKIP: microphone permission not granted")
            return lines.joined(separator: "\n")
        }

        let container = try! ModelContainer(
            for: Item.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let item = Item(timestamp: .now)
        container.mainContext.insert(item)

        var pendingFileName: String? = "live-finish-\(UUID().uuidString).m4a"
        let url = AudioFileStore.documentsDirectory.appendingPathComponent(pendingFileName!)

        do {
            try recorder.startRecording(to: url)
        } catch {
            lines.append("FAIL: live startRecording \(error)")
            return lines.joined(separator: "\n")
        }

        lines.append("start: state=\(recorder.state) isRecording=\(recorder.isRecording)")
        guard recorder.isRecording else {
            lines.append("FAIL: expected .recording after live start")
            return lines.joined(separator: "\n")
        }

        try? await Task.sleep(for: .milliseconds(500))

        let result = ItemDetailRecordingFinish.finishRecordingIfNeeded(
            recorder: recorder,
            item: item,
            pendingFileName: &pendingFileName
        )

        let exists = FileManager.default.fileExists(atPath: url.path)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
        lines.append("finishRecordingIfNeeded: savedURL=\(result.savedURL?.lastPathComponent ?? "nil") fileName=\(item.audioFileName ?? "nil") duration=\(item.audioDuration.map(String.init(describing:)) ?? "nil") exists=\(exists) size=\(size) pendingCleared=\(pendingFileName == nil)")

        if result.savedURL != nil,
           item.audioFileName != nil,
           let duration = item.audioDuration, duration > 0,
           exists, size > 0,
           pendingFileName == nil {
            lines.append("LIVE_INTEGRATED_PASS")
        } else {
            lines.append("FAIL: live finishRecordingIfNeeded")
        }

        return lines.joined(separator: "\n")
    }
}
#endif