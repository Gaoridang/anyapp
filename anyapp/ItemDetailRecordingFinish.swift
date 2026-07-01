//
//  ItemDetailRecordingFinish.swift
//  anyapp
//
//  Shipped stop→persist path invoked by ItemDetailView.finishRecordingIfNeeded().
//

import Foundation

protocol RecordingFinishItem: AnyObject {
    var audioFileName: String? { get set }
    var audioDuration: TimeInterval? { get set }
}

extension RecordingFinishItem {
    var audioFileURL: URL? {
        guard let audioFileName else { return nil }
        return AudioFileStore.documentsDirectory.appendingPathComponent(audioFileName)
    }
}

@MainActor
enum ItemDetailRecordingFinish {
    struct FinishResult {
        let savedURL: URL?
        let errorMessage: String?
    }

    /// Shipped implementation backing `ItemDetailView.finishRecordingIfNeeded()`.
    static func finishRecordingIfNeeded(
        recorder: AudioRecorder,
        item: some RecordingFinishItem,
        pendingFileName: inout String?
    ) -> FinishResult {
        guard recorder.isRecording else {
            return FinishResult(savedURL: nil, errorMessage: nil)
        }

        let pending = pendingFileName
        pendingFileName = nil

        let duration = recorder.stopRecording()
        if let duration, duration > 0, let pending {
            item.audioFileName = pending
            item.audioDuration = duration
            return FinishResult(savedURL: item.audioFileURL, errorMessage: nil)
        }

        if let fileName = pending {
            let url = AudioFileStore.documentsDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
            return FinishResult(
                savedURL: nil,
                errorMessage: "녹음된 오디오가 없습니다. 다시 시도해 주세요."
            )
        }

        return FinishResult(savedURL: nil, errorMessage: nil)
    }
}