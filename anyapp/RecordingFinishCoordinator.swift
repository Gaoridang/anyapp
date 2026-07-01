//
//  RecordingFinishCoordinator.swift
//  anyapp
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
enum RecordingFinishCoordinator {
    struct FinishResult {
        let savedURL: URL?
        let errorMessage: String?
    }

    /// Stops an active recording and persists audio metadata on the item.
    static func finish(
        recorder: AudioRecorder,
        item: some RecordingFinishItem,
        pendingFileName: String?
    ) -> FinishResult {
        guard recorder.isRecording else {
            return FinishResult(savedURL: nil, errorMessage: nil)
        }

        let duration = recorder.stopRecording()
        if let duration, duration > 0, let pendingFileName {
            item.audioFileName = pendingFileName
            item.audioDuration = duration
            return FinishResult(savedURL: item.audioFileURL, errorMessage: nil)
        }

        if let fileName = pendingFileName {
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